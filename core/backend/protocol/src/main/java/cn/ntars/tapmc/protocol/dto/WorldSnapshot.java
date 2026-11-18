package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * {@code world.snapshot} 的返回：整张地图。
 *
 * <p>{@code blocks} 用一维数组按行优先排列，长度必须等于 {@code width * height}，
 * 索引 {@code y * width + x}。选一维而非二维数组，是因为 JSON 里二维数组体积更大，
 * 而且前端反序列化后直接当 {@code List} 用更省事。
 */
public final class WorldSnapshot {

    @SerializedName("width")
    private final int width;

    @SerializedName("height")
    private final int height;

    @SerializedName("blocks")
    private final java.util.List<String> blocks;

    public WorldSnapshot(int width, int height, java.util.List<String> blocks) {
        this.width = width;
        this.height = height;
        this.blocks = blocks;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public java.util.List<String> getBlocks() {
        return blocks;
    }
}
