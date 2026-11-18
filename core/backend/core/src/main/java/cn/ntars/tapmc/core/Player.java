package cn.ntars.tapmc.core;

import cn.ntars.tapmc.protocol.dto.BlockPos;
import cn.ntars.tapmc.protocol.dto.PlayerState;

/**
 * 一个玩家。骨架阶段只有位置，没有生命值、背包、朝向。
 *
 * 不可变：移动时返回新实例，而不是就地改坐标。这样「谁在什么位置」在事件
 * 回调里读到的值不会在回调返回前被别人改掉。
 */
public final class Player {

    private final String id;
    private final BlockPos pos;

    public Player(String id, BlockPos pos) {
        this.id = id;
        this.pos = pos;
    }

    public String getId() {
        return id;
    }

    public BlockPos getPos() {
        return pos;
    }

    /** 移动到新位置，返回新实例。 */
    public Player movedTo(BlockPos newPos) {
        return new Player(id, newPos);
    }

    /** 转成协议层对象。 */
    public PlayerState toState() {
        return new PlayerState(id, pos);
    }
}
