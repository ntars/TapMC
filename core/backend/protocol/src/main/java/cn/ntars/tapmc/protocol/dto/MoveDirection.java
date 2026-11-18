package cn.ntars.tapmc.protocol.dto;

/**
 * 四方向移动。骨架阶段只做正交四向，不做斜向与连续移动。
 *
 * <p>坐标原点左上，因此 {@code NORTH} 是 y 减一、{@code SOUTH} 是 y 加一。
 * 与前端约定的方向名必须一致，写错不会报错，只会让操作反着来。
 */
public enum MoveDirection {

    NORTH(0, -1),
    SOUTH(0, 1),
    WEST(-1, 0),
    EAST(1, 0);

    private final int dx;
    private final int dy;

    MoveDirection(int dx, int dy) {
        this.dx = dx;
        this.dy = dy;
    }

    public int getDx() {
        return dx;
    }

    public int getDy() {
        return dy;
    }
}
