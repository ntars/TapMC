package cn.ntars.tapmc.core;

import cn.ntars.tapmc.mod.ModContext;
import cn.ntars.tapmc.mod.event.BlockBreakEvent;
import cn.ntars.tapmc.mod.event.BlockBreakListener;
import cn.ntars.tapmc.mod.event.BlockPlaceEvent;
import cn.ntars.tapmc.mod.event.BlockPlaceListener;
import cn.ntars.tapmc.mod.event.PlayerMoveEvent;
import cn.ntars.tapmc.mod.event.PlayerMoveListener;
import cn.ntars.tapmc.protocol.dto.BlockPos;
import cn.ntars.tapmc.protocol.dto.BlockType;
import cn.ntars.tapmc.protocol.dto.MoveDirection;
import cn.ntars.tapmc.protocol.dto.PlayerState;
import cn.ntars.tapmc.protocol.dto.WorldChange;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Consumer;

/**
 * 游戏规则引擎。所有「玩家能不能这么做」的判断集中在这里，服务端只做
 * 「把 RPC 翻译成这里的方法调用」和「把结果翻译成 RPC 响应」。
 *
 * <p><b>线程模型</b>：非线程安全，必须在单一事件循环线程内调用。
 * 服务端为此保证「一个连接的所有请求按到达顺序在同一个线程处理」。
 *
 * <p><b>模组介入点</b>：每个会改状态的动作都先发事件，模组可取消。
 * 取消后动作不执行，调用方拿到「被模组拦下」的理由，而不是静默失败。
 */
public final class GameEngine implements ModContext {

    /** 未知操作结果的统一表达：要么给出结果，要么给出「为什么不行」。 */
    public sealed interface Outcome<T> permits Outcome.Ok, Outcome.Rejected {

        record Ok<T>(T value) implements Outcome<T> {
        }

        record Rejected<T>(String message) implements Outcome<T> {
        }

        static <T> Outcome<T> ok(T value) {
            return new Ok<>(value);
        }

        static <T> Outcome<T> rejected(String message) {
            return new Rejected<>(message);
        }

        default boolean isOk() {
            return this instanceof Ok;
        }
    }

    private final WorldGrid world;
    private final Map<String, Player> players = new LinkedHashMap<>();

    private final List<BlockPlaceListener> placeListeners = new ArrayList<>();
    private final List<BlockBreakListener> breakListeners = new ArrayList<>();
    private final List<PlayerMoveListener> moveListeners = new ArrayList<>();

    /** 世界变化后通知外部（服务端据此广播给所有前端）。 */
    private Consumer<WorldChange> changeBroadcaster = change -> {
    };

    public GameEngine(WorldGrid world) {
        this.world = world;
    }

    public WorldGrid world() {
        return world;
    }

    /** 设置世界变化的外部通知口。服务端启动时注入广播实现。 */
    public void onWorldChanged(Consumer<WorldChange> broadcaster) {
        this.changeBroadcaster = broadcaster == null ? change -> {
        } : broadcaster;
    }

    /* ---------------- 玩家 ---------------- */

    /**
     * 加入世界。出生点取地图中心；若中心不可通行，则向右扫描第一个可通行格。
     *
     * @param playerId 服务端分配的 id
     * @return 玩家初始状态；地图里没有任何可通行格时返回空
     */
    public Optional<PlayerState> join(String playerId, BlockPos spawn) {
        if (!world.contains(spawn.getX(), spawn.getY()) || !world.get(spawn.getX(), spawn.getY()).isWalkable()) {
            BlockPos fallback = findFirstWalkable();
            if (fallback == null) {
                return Optional.empty();
            }
            spawn = fallback;
        }
        Player player = new Player(playerId, spawn);
        players.put(playerId, player);
        return Optional.of(player.toState());
    }

    /** 移除玩家。返回是否真的移除了。 */
    public boolean leave(String playerId) {
        return players.remove(playerId) != null;
    }

    /** 当前在线玩家快照。 */
    public List<PlayerState> players() {
        return players.values().stream().map(Player::toState).toList();
    }

    /**
     * 按方向移动一格。
     *
     * <p>拦在三处：玩家不存在、目标格不可通行、模组取消。
     * 三者的错误文案不同，因为用户能采取的动作不同（重连 / 换方向 / 找模组作者）。
     */
    public Outcome<PlayerState> move(String playerId, MoveDirection direction) {
        Player player = players.get(playerId);
        if (player == null) {
            return Outcome.rejected("玩家 " + playerId + " 不在世界中");
        }

        BlockPos from = player.getPos();
        BlockPos to = from.offset(direction);
        BlockType target = world.get(to.getX(), to.getY());

        if (!target.isWalkable()) {
            return Outcome.rejected("目标位置 " + to + " 是 " + target.name() + "，不可通行");
        }

        PlayerMoveEvent event = new PlayerMoveEvent(playerId,
                from.getX(), from.getY(), to.getX(), to.getY(), direction.name());
        for (PlayerMoveListener listener : List.copyOf(moveListeners)) {
            listener.onPlayerMove(event);
        }
        if (event.isCancelled()) {
            return Outcome.rejected("移动被模组拦下：" + event.getReason());
        }

        Player moved = player.movedTo(to);
        players.put(playerId, moved);
        return Outcome.ok(moved.toState());
    }

    /* ---------------- 方块 ---------------- */

    /** 读一格。越界返回 {@code AIR}，与 {@link WorldGrid#get} 保持一致。 */
    public BlockType blockAt(int x, int y) {
        return world.get(x, y);
    }

    /**
     * 放置方块。规则：
     * <ol>
     *   <li>坐标必须在世界内；
     *   <li>{@code AIR} 不是「方块」，不允许显式放置（要清空请用 {@link #breakBlock}）；
     *   <li>目标格必须已经是 {@code AIR}——不允许直接覆盖已有方块，
     *       否则「放错一格」就没有撤销余地。
     * </ol>
     */
    public Outcome<WorldChange> placeBlock(String actor, int x, int y, BlockType block) {
        if (!world.contains(x, y)) {
            return Outcome.rejected("坐标 (" + x + "," + y + ") 超出世界范围");
        }
        if (block == BlockType.AIR) {
            return Outcome.rejected("不能放置空气；清空请用破坏");
        }
        if (world.get(x, y) != BlockType.AIR) {
            return Outcome.rejected("(" + x + "," + y + ") 已有方块 " + world.get(x, y).name() + "，请先破坏");
        }

        BlockPlaceEvent event = new BlockPlaceEvent(x, y, block.name(), actor);
        for (BlockPlaceListener listener : List.copyOf(placeListeners)) {
            listener.onBlockPlace(event);
        }
        if (event.isCancelled()) {
            return Outcome.rejected("放置被模组拦下：" + event.getReason());
        }

        world.set(x, y, block);
        WorldChange change = new WorldChange(new BlockPos(x, y), block, actor);
        changeBroadcaster.accept(change);
        return Outcome.ok(change);
    }

    /**
     * 破坏方块。规则：坐标须在世界内，且该格不是 {@code AIR}（空气没得破）。
     * 破坏后该格变为 {@code AIR}。
     */
    public Outcome<WorldChange> breakBlock(String actor, int x, int y) {
        if (!world.contains(x, y)) {
            return Outcome.rejected("坐标 (" + x + "," + y + ") 超出世界范围");
        }
        BlockType current = world.get(x, y);
        if (current == BlockType.AIR) {
            return Outcome.rejected("(" + x + "," + y + ") 已经是空气");
        }

        BlockBreakEvent event = new BlockBreakEvent(x, y, current.name(), actor);
        for (BlockBreakListener listener : List.copyOf(breakListeners)) {
            listener.onBlockBreak(event);
        }
        if (event.isCancelled()) {
            return Outcome.rejected("破坏被模组拦下：" + event.getReason());
        }

        world.set(x, y, BlockType.AIR);
        WorldChange change = new WorldChange(new BlockPos(x, y), BlockType.AIR, actor);
        changeBroadcaster.accept(change);
        return Outcome.ok(change);
    }

    /* ---------------- ModContext 实现 ---------------- */

    @Override
    public int worldWidth() {
        return world.getWidth();
    }

    @Override
    public int worldHeight() {
        return world.getHeight();
    }

    @Override
    public String getBlock(int x, int y) {
        return world.get(x, y).name();
    }

    @Override
    public boolean setBlock(int x, int y, String block) {
        BlockType type = parseBlock(block);
        if (type == null) {
            return false;
        }
        if (!world.set(x, y, type)) {
            return false;
        }
        changeBroadcaster.accept(new WorldChange(new BlockPos(x, y), type, "system"));
        return true;
    }

    @Override
    public void onBlockPlace(BlockPlaceListener listener) {
        placeListeners.add(listener);
    }

    @Override
    public void onBlockBreak(BlockBreakListener listener) {
        breakListeners.add(listener);
    }

    @Override
    public void onPlayerMove(PlayerMoveListener listener) {
        moveListeners.add(listener);
    }

    /** 解析方块名。非法返回 null，由调用方决定怎么处理。 */
    public static BlockType parseBlock(String name) {
        if (name == null) {
            return null;
        }
        try {
            return BlockType.valueOf(name);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private BlockPos findFirstWalkable() {
        for (int y = 0; y < world.getHeight(); y++) {
            for (int x = 0; x < world.getWidth(); x++) {
                if (world.get(x, y).isWalkable()) {
                    return new BlockPos(x, y);
                }
            }
        }
        return null;
    }
}
