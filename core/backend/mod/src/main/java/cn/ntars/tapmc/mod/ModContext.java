package cn.ntars.tapmc.mod;

import cn.ntars.tapmc.mod.event.BlockBreakListener;
import cn.ntars.tapmc.mod.event.BlockPlaceListener;
import cn.ntars.tapmc.mod.event.BlockBreakEvent;
import cn.ntars.tapmc.mod.event.BlockPlaceEvent;
import cn.ntars.tapmc.mod.event.PlayerMoveEvent;
import cn.ntars.tapmc.mod.event.PlayerMoveListener;

/**
 * 模组能用的全部能力。由服务端在加载模组时注入。
 *
 * <p>这是模组与游戏本体之间<b>唯一</b>的通道：模组拿不到世界对象的引用，
 * 想读方块就调 {@link #getBlock(int, int)}，想改世界只能通过事件取消或
 * {@link #setBlock(int, int, String)}。这样服务端的并发与边界校验只需守这一处。
 *
 * <p>所有方法都在服务端事件循环线程内调用，实现方不要在其中起线程或做阻塞 IO。
 */
public interface ModContext {

    /** 世界宽度（格）。 */
    int worldWidth();

    /** 世界高度（格）。 */
    int worldHeight();

    /**
     * 读一格方块。
     *
     * @return 方块类型名，例如 {@code "STONE"}；越界时返回 {@code "AIR"}
     */
    String getBlock(int x, int y);

    /**
     * 改一格方块。会触发 {@code event.worldChanged} 广播给所有前端。
     *
     * @param block 方块类型名；无法识别时不改动并静默忽略
     * @return 是否真的改动了（坐标越界或方块名非法都返回 false）
     */
    boolean setBlock(int x, int y, String block);

    /** 注册「放置方块之前」的监听。 */
    void onBlockPlace(BlockPlaceListener listener);

    /** 注册「破坏方块之前」的监听。 */
    void onBlockBreak(BlockBreakListener listener);

    /** 注册「玩家移动之后」的监听。 */
    void onPlayerMove(PlayerMoveListener listener);

    /** 内部：把放置事件交给已注册的监听。引擎调用，模组实现者无需关心。 */
    default void dispatchPlace(BlockPlaceEvent event) {
    }

    /** 内部：把破坏事件交给已注册的监听。引擎调用，模组实现者无需关心。 */
    default void dispatchBreak(BlockBreakEvent event) {
    }

    /** 内部：把移动事件交给已注册的监听。引擎调用，模组实现者无需关心。 */
    default void dispatchMove(PlayerMoveEvent event) {
    }
}
