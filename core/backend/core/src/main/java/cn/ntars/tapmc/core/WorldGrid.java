package cn.ntars.tapmc.core;

import cn.ntars.tapmc.protocol.dto.BlockType;

/**
 * 世界网格。这是游戏本体的核心状态：一个 {@code width × height} 的方块矩阵。
 *
 * <p><b>刻意不做线程安全</b>。世界只在服务端的事件循环线程内被读写，
 * 加锁会掩盖「某处代码跨线程了」这个问题，反而更难查。需要并发时由调用方
 * 把操作排进同一线程（见 {@code server} 模块的单线程调度）。
 *
 * <p>越界处理：读越界返回 {@link BlockType#AIR}，写越界返回 {@code false}
 * 且不改动。选择「读不抛、写不静默成功」，是因为读越界在渲染边缘格时很常见，
 * 抛异常会让前端每帧都要判边界；而写越界通常是逻辑错误，必须能被调用方发现。
 */
public final class WorldGrid {

    private final int width;
    private final int height;

    /** 行优先存储，索引 {@code y * width + x}。 */
    private final BlockType[] blocks;

    public WorldGrid(int width, int height) {
        if (width <= 0 || height <= 0) {
            throw new IllegalArgumentException("世界尺寸必须为正：" + width + "x" + height);
        }
        this.width = width;
        this.height = height;
        this.blocks = new BlockType[width * height];
        java.util.Arrays.fill(this.blocks, BlockType.AIR);
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    /** 坐标是否落在世界内。 */
    public boolean contains(int x, int y) {
        return x >= 0 && y >= 0 && x < width && y < height;
    }

    /** 读一格。越界返回 {@link BlockType#AIR}。 */
    public BlockType get(int x, int y) {
        if (!contains(x, y)) {
            return BlockType.AIR;
        }
        return blocks[y * width + x];
    }

    /**
     * 写一格。
     *
     * @return 是否写入成功。越界返回 {@code false} 且世界不变
     */
    public boolean set(int x, int y, BlockType type) {
        if (!contains(x, y)) {
            return false;
        }
        blocks[y * width + x] = type;
        return true;
    }

    /**
     * 导出为按行优先排列的名字列表，供协议层序列化。
     *
     * <p>返回的列表是不可变副本，调用方改它不会影响世界。
     */
    public java.util.List<String> toBlockNames() {
        java.util.List<String> names = new java.util.ArrayList<>(blocks.length);
        for (BlockType block : blocks) {
            names.add(block.name());
        }
        return java.util.List.copyOf(names);
    }

    /** 归档一张「全空气」世界。 */
    public static WorldGrid empty(int width, int height) {
        return new WorldGrid(width, height);
    }
}
