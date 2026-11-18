package cn.ntars.tapmc.mod.event;

/** 「放置方块之前」的监听器。 */
@FunctionalInterface
public interface BlockPlaceListener {

    void onBlockPlace(BlockPlaceEvent event);
}
