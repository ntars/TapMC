package cn.ntars.tapmc.server;

import cn.ntars.tapmc.core.GameEngine;
import cn.ntars.tapmc.core.ModLoader;
import cn.ntars.tapmc.core.WorldGenerator;
import cn.ntars.tapmc.mod.ModContext;
import cn.ntars.tapmc.mod.TapMcMod;
import cn.ntars.tapmc.protocol.dto.WorldChange;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * 服务端装配：把世界、引擎、模组、分发器串起来。
 *
 * <p>与网络层分开的意义：测试可以不起端口，直接 new 一个 {@code GameServer} 调
 * {@link #handle} 就能跑完整链路。
 *
 * <p><b>连接与玩家</b>：每个客户端连接有自己的 {@link RpcDispatcher}，玩家身份
 * 存在分发器里，因此连接之间互不干扰。
 *
 * <p><b>广播</b>：世界一变化就推给所有连接。骨架阶段不做增量压缩、不做视野裁剪，
 * 24×16 的地图上直接推单格变化已经足够省。
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
    private final int width;
    private final int height;

    /** 已连接的会话。用写时复制列表，因为广播时会被遍历、连接增删是低频操作。 */
    private final List<ClientSession> sessions = new CopyOnWriteArrayList<>();

    private final Consumer<WorldChange> broadcastListener;

    public GameServer() {
        this(DEFAULT_WIDTH, DEFAULT_HEIGHT, List.of());
    }

    public GameServer(int width, int height, List<TapMcMod> mods) {
        this.width = width;
        this.height = height;
        this.engine = new GameEngine(WorldGenerator.generate(width, height));
        this.modLoader = new ModLoader(engine);
        this.modLoader.loadAll(mods);
        this.broadcastListener = EventBroadcaster.worldChange(sessions);
        this.engine.onWorldChanged(broadcastListener);
    }

    /**
     * 为一条新连接创建分发器。调用方负责把该连接的收发接到返回对象上。
     */
    public RpcDispatcher newDispatcher() {
        return new RpcDispatcher(engine, modLoader, width, height);
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
        return modLoader.report();
    }
}
