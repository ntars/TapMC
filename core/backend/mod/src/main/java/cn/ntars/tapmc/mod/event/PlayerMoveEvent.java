package cn.ntars.tapmc.mod.event;

/**
 * 「玩家移动之前」事件。取消后玩家停在原地。
 *
 * <p>命名上监听器叫 {@code onPlayerMove}，事件叫 {@code BeforeMove}，
 * 是因为从模组视角看是「移动发生了」，从服务端视角看是「移动还没提交」。
 * 两边都保持各自的自然说法，比强行统一更好读。
 */
public final class PlayerMoveEvent extends ModEvent {

    private final String playerId;
    private final int fromX;
    private final int fromY;
    private final int toX;
    private final int toY;
    private final String direction;

    public PlayerMoveEvent(String playerId, int fromX, int fromY, int toX, int toY, String direction) {
        this.playerId = playerId;
        this.fromX = fromX;
        this.fromY = fromY;
        this.toX = toX;
        this.toY = toY;
        this.direction = direction;
    }

    public String getPlayerId() {
        return playerId;
    }

    public int getFromX() {
        return fromX;
    }

    public int getFromY() {
        return fromY;
    }

    public int getToX() {
        return toX;
    }

    public int getToY() {
        return toY;
    }

    /** 方向名：{@code NORTH / SOUTH / WEST / EAST}。 */
    public String getDirection() {
        return direction;
    }
}
