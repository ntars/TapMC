package cn.ntars.tapmc.mod.event;

/**
 * 「即将破坏方块」事件。取消后该格保持原样。
 */
public final class BlockBreakEvent extends ModEvent {

    private final int x;
    private final int y;
    private final String block;
    private final String actor;

    public BlockBreakEvent(int x, int y, String block, String actor) {
        this.x = x;
        this.y = y;
        this.block = block;
        this.actor = actor;
    }

    public int getX() {
        return x;
    }

    public int getY() {
        return y;
    }

    /** 被破坏的方块类型名。 */
    public String getBlock() {
        return block;
    }

    /** 发起者（玩家 id 或 {@code "system"}）。 */
    public String getActor() {
        return actor;
    }
}
