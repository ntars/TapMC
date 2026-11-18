package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * 方块坐标。世界是二维网格（骨架阶段不做高度），因此只有 x / y。
 *
 * <p>坐标原点在左上角，x 向右、y 向下。这一点必须与前端渲染一致，
 * 否则地图会上下颠倒。
 */
public final class BlockPos {

    @SerializedName("x")
    private final int x;

    @SerializedName("y")
    private final int y;

    public BlockPos(int x, int y) {
        this.x = x;
        this.y = y;
    }

    public int getX() {
        return x;
    }

    public int getY() {
        return y;
    }

    /** 四个方向的相邻格。方向名与 {@link MoveDirection} 对应。 */
    public BlockPos offset(MoveDirection direction) {
        return new BlockPos(x + direction.getDx(), y + direction.getDy());
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof BlockPos other)) {
            return false;
        }
        return x == other.x && y == other.y;
    }

    @Override
    public int hashCode() {
        return 31 * x + y;
    }

    @Override
    public String toString() {
        return "(" + x + "," + y + ")";
    }
}
