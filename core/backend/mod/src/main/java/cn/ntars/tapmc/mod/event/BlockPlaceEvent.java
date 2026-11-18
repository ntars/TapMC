package cn.ntars.tapmc.mod.event;

/**
 * 「即将放置方块」事件。模组可以在服务端真正写入前拦下它。
 *
 * <p>此时世界还没变，读 {@code ctx.getBlock} 拿到的是旧值。
 */
public final class BlockPlaceEvent extends ModEvent {

    private final int x;
    private final int y;
    private final String block;
    private final String actor;

    public BlockPlaceEvent(int x, int y, String block, String actor) {
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

    /** 要放的方块类型名。 */
    public String getBlock() {
        return block;
    }

    /** 发起者（玩家 id 或 {@code "system"}）。 */
    public String getActor() {
        return actor;
    }
}
