package cn.ntars.tapmc.core;

import cn.ntars.tapmc.mod.ModContext;
import cn.ntars.tapmc.mod.event.BlockBreakEvent;
import cn.ntars.tapmc.mod.event.BlockBreakListener;
import cn.ntars.tapmc.mod.event.BlockPlaceEvent;
import cn.ntars.tapmc.mod.event.BlockPlaceListener;
import cn.ntars.tapmc.mod.event.PlayerMoveEvent;
import cn.ntars.tapmc.mod.event.PlayerMoveListener;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * 可热替换的模组上下文。
 *
 * <p>世界操作直接转给 {@link GameEngine}，但事件监听器不是注册到引擎上，而是先存到本地。
 * 这样卸载模组时只要清空本地列表即可撤掉全部监听，不必重建世界或玩家状态。
 * 引擎仍然只看到一组稳定的代理回调，无需知道模组什么时候被换掉。
 */
public final class ReloadableModContext implements ModContext {

    private final GameEngine delegate;
    private final List<BlockPlaceListener> placeListeners = new CopyOnWriteArrayList<>();
    private final List<BlockBreakListener> breakListeners = new CopyOnWriteArrayList<>();
    private final List<PlayerMoveListener> moveListeners = new CopyOnWriteArrayList<>();

    public ReloadableModContext(GameEngine delegate) {
        this.delegate = delegate;
    }

    /** 丢弃当前所有模组监听器。重载前调用，旧模组随即失去对游戏的影响。 */
    public void reset() {
        placeListeners.clear();
        breakListeners.clear();
        moveListeners.clear();
    }

    /** 把放置事件交给当前一批模组。 */
    public void dispatchPlace(BlockPlaceEvent event) {
        for (BlockPlaceListener listener : placeListeners) {
            listener.onBlockPlace(event);
        }
    }

    /** 把破坏事件交给当前一批模组。 */
    public void dispatchBreak(BlockBreakEvent event) {
        for (BlockBreakListener listener : breakListeners) {
            listener.onBlockBreak(event);
        }
    }

    /** 把移动事件交给当前一批模组。 */
    public void dispatchMove(PlayerMoveEvent event) {
        for (PlayerMoveListener listener : moveListeners) {
            listener.onPlayerMove(event);
        }
    }

    @Override
    public int worldWidth() {
        return delegate.worldWidth();
    }

    @Override
    public int worldHeight() {
        return delegate.worldHeight();
    }

    @Override
    public String getBlock(int x, int y) {
        return delegate.getBlock(x, y);
    }

    @Override
    public boolean setBlock(int x, int y, String block) {
        return delegate.setBlock(x, y, block);
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
}
