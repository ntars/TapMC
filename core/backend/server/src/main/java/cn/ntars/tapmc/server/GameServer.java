package cn.ntars.tapmc.server;

import cn.ntars.tapmc.core.GameEngine;
import cn.ntars.tapmc.core.ModLoader;
import cn.ntars.tapmc.core.ReloadableModContext;
import cn.ntars.tapmc.core.WorldGenerator;
import cn.ntars.tapmc.core.WorldGrid;
import cn.ntars.tapmc.core.storage.StorageException;
import cn.ntars.tapmc.core.storage.WorldStore;
import cn.ntars.tapmc.mod.ModContext;
import cn.ntars.tapmc.mod.TapMcMod;
import cn.ntars.tapmc.protocol.dto.WorldChange;

import java.util.List;
import java.util.Optional;
import java.nio.file.Path;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * 服务端装配：把世界、引擎、模组、分发器串起来。
 *
 * <p>与网络层分开的意义：测试可以不起端口，直接 new 一个 {@code GameServer} 调
 * {@link #handleStateless} 就能跑完整链路。
 *
 * <p><b>连接与玩家</b>：每个客户端连接有自己的 {@link RpcDispatcher}，玩家身份
 * 存在分发器里，因此连接之间互不干扰。
 *
 * <p><b>广播</b>：世界一变化就推给所有连接。骨架阶段不做增量压缩、不做视野裁剪，
 * 24×16 的地图上直接推单格变化已经足够省。
 *
 * <p><b>存档</b>：构造时若给了 {@link WorldStore}，启动即尝试读档；读不到就照常
 * 生成新地形。写档由 {@link #save()} 显式触发（服务端在退出钩子里调）。
 * 存档失败不会让服务起不来——宁可这一次丢档，也不能让人打不开游戏。
 */
public final class GameServer {

    /** 协议版本。前端与之不一致即拒绝通信。 */
    public static final String PROTOCOL_VERSION = "1.0";

    public static final String SERVER_NAME = "TapMC";
    public static final String SERVER_VERSION = "0.1.0";

    private static final int DEFAULT_WIDTH = 24;
    private static final int DEFAULT_HEIGHT = 16;

    private final GameEngine engine;
    private final ModLoader modLoader;
    private final ReloadableModContext dynamicContext;
    private DirectoryModLoader dynamicModLoader;
    private final int width;
    private final int height;

    /** 可选存档。为 null 表示纯内存世界（测试与一次性运行）。 */
    private final WorldStore store;

    /** 本次启动是否成功读了档。用于日志与诊断，不参与游戏逻辑。 */
    private final boolean loadedFromStore;

    /** 已连接的会话。用写时复制列表，因为广播时会被遍历、连接增删是低频操作。 */
    private final List<ClientSession> sessions = new CopyOnWriteArrayList<>();

    private final Consumer<WorldChange> broadcastListener;

    /**
     * 世界变化计数。每次改动自增，供定时存档判断「有没有必要写盘」——
     * 没人操作时每分钟重写一次同样的文件纯属浪费磁盘寿命。
     * 用 {@code volatile}：写入发生在网络线程（持引擎锁），读取发生在存档线程。
     */
    private volatile long revision;

    public GameServer() {
        this(DEFAULT_WIDTH, DEFAULT_HEIGHT, List.of(), null);
    }

    public GameServer(int width, int height, List<TapMcMod> mods) {
        this(width, height, mods, null);
    }

    /**
     * @param store 存档实现；传 {@code null} 表示不持久化。读档失败（无档／坏档／
     *              尺寸不符）时自动回退到新生成的地形，不会抛异常终止启动
     */
    public GameServer(int width, int height, List<TapMcMod> mods, WorldStore store) {
        this.width = width;
        this.height = height;
        this.store = store;

        Optional<WorldGrid> loaded = Optional.empty();
        if (store != null) {
            try {
                loaded = store.load(width, height);
            } catch (StorageException e) {
                // 读盘出错不该让服务起不来：本次以新世界运行，并把原因写清楚。
                System.err.println("[TapMC] 读档失败，改用新世界：" + e.getMessage());
            }
        }
        this.loadedFromStore = loaded.isPresent();
        this.engine = new GameEngine(loaded.orElseGet(() -> WorldGenerator.generate(width, height)));

        this.modLoader = new ModLoader(engine);
        this.dynamicContext = new ReloadableModContext(engine);
        this.modLoader.loadAll(mods);
        this.dynamicModLoader = new DirectoryModLoader(Path.of("mods"), dynamicContext);
        // 广播与「改动计数」共用同一个出口：任何进到引擎的改动都会走 changeBroadcaster，
        // 因此在这里自增计数不会漏记，也不必往 GameEngine 里塞存档相关代码。
        Consumer<WorldChange> broadcast = EventBroadcaster.worldChange(sessions);
        this.broadcastListener = change -> {
            revision++;
            broadcast.accept(change);
        };
        this.engine.onWorldChanged(broadcastListener);
    }

    /**
     * 为一条新连接创建分发器。调用方负责把该连接的收发接到返回对象上。
     */
    public RpcDispatcher newDispatcher() {
        return new RpcDispatcher(engine, this::combinedModReport, width, height);
    }

    private List<cn.ntars.tapmc.protocol.dto.ModInfo> combinedModReport() {
        List<cn.ntars.tapmc.protocol.dto.ModInfo> result =
                new java.util.ArrayList<>(modLoader.report());
        result.addAll(dynamicModLoader.report());
        return List.copyOf(result);
    }

    /**
     * 从 {@code mods/} 目录重新扫描 jar。成功加载的模组替换上一批；
     * 代码内注册的模组不受影响。返回完整报告（内置 + 动态）。
     */
    public List<cn.ntars.tapmc.protocol.dto.ModInfo> reloadMods() {
        engine.setModContext(dynamicContext);
        dynamicModLoader.loadAll();
        return combinedModReport();
    }

    /** 指定模组目录并立即加载。入口在启动时调用一次。 */
    public List<cn.ntars.tapmc.protocol.dto.ModInfo> reloadModsFrom(Path dir) {
        this.dynamicModLoader = new DirectoryModLoader(dir, dynamicContext);
        return reloadMods();
    }

    /** 登记连接，开始接收广播。 */
    public void attach(ClientSession session) {
        sessions.add(session);
    }

    /** 注销连接。断连时必须调用，否则广播会一直往死连接写。 */
    public void detach(ClientSession session) {
        sessions.remove(session);
    }

    /**
     * 用<b>一次性</b>分发器处理一条请求。每次调用都是全新身份，因此
     * 「先 join 再 move」这类有状态的序列<b>不会</b>生效——那是真实连接的行为，
     * 必须走 {@link #newDispatcher()}。
     *
     * <p>存在意义：无状态方法（hello、snapshot、getBlock）的诊断与快速验证。
     * 名字里带 {@code Stateless} 是为了让误用当场可见。
     *
     * @return 响应文本；通知类请求返回 {@code null}
     */
    public String handleStateless(String rawJson) {
        return newDispatcher().handle(rawJson);
    }

    public GameEngine engine() {
        return engine;
    }

    public int width() {
        return width;
    }

    public int height() {
        return height;
    }

    /** 给模组用的上下文。 */
    public ModContext modContext() {
        return engine;
    }

    /** 模组加载报告。 */
    public List<cn.ntars.tapmc.protocol.dto.ModInfo> modReport() {
        return combinedModReport();
    }

    /* ---------------- 存档 ---------------- */

    /** 是否有存档实现。没有时 {@link #save()} 是空操作。 */
    public boolean persistent() {
        return store != null;
    }

    /** 本次启动是否从存档恢复。 */
    public boolean loadedFromStore() {
        return loadedFromStore;
    }

    /** 自上次存档以来的改动计数。存档线程据此决定要不要写盘。 */
    public long revision() {
        return revision;
    }

    /**
     * 把当前世界写入存档。
     *
     * <p>失败时打日志并返回 {@code false}，<b>不抛异常</b>：调用点在 JVM 退出钩子里，
     * 那里抛异常只会打印一串栈，还会让「已经存了一半」的状态更难判断。
     *
     * @return 是否成功写入（未配置存档时返回 {@code true}，因为「没要求存」不算失败）
     */
    public boolean save() {
        if (store == null) {
            return true;
        }
        try {
            store.save(engine.world());
            return true;
        } catch (StorageException e) {
            System.err.println("[TapMC] 存档失败：" + e.getMessage());
            return false;
        }
    }

    /** 世界尺寸的默认值，供入口与测试共用一处真源。 */
    public static int defaultWidth() {
        return DEFAULT_WIDTH;
    }

    /** 世界尺寸的默认值，供入口与测试共用一处真源。 */
    public static int defaultHeight() {
        return DEFAULT_HEIGHT;
    }
}
