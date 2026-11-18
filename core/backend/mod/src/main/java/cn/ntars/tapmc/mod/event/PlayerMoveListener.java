package cn.ntars.tapmc.mod.event;

/** 「玩家移动之前」的监听器。 */
@FunctionalInterface
public interface PlayerMoveListener {

    void onPlayerMove(PlayerMoveEvent event);
}
