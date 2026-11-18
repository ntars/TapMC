package cn.ntars.tapmc.mod.event;

/** 「破坏方块之前」的监听器。 */
@FunctionalInterface
public interface BlockBreakListener {

    void onBlockBreak(BlockBreakEvent event);
}
