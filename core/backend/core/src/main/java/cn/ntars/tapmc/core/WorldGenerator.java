package cn.ntars.tapmc.core;

import cn.ntars.tapmc.protocol.dto.BlockType;

/**
 * 世界生成器。骨架阶段只生成一张固定地形，用于验证渲染与移动，
 * 不做噪声地形、不读种子。参数化（种子、地形类型）留到有实际需求时再加。
 *
 * <p>地形构成：四周一圈 {@link BlockType#WOOD} 当围栏，内圈散布一块水塘，
 * 其余铺 {@link BlockType#DIRT}。这样一眼能看出「哪些格子走不过去」，
 * 边界的不可通行也能立刻验证。
 */
public final class WorldGenerator {

    private static final int WATER_POND_SIZE = 3;

    private WorldGenerator() {
    }

    /**
     * 生成初始世界。
     *
     * <p>尺寸过小时（小于 8×8）只铺地面，不画围栏与水塘——围栏会把整个地图占满，
     * 没有可活动空间。
     */
    public static WorldGrid generate(int width, int height) {
        WorldGrid world = new WorldGrid(width, height);

        // 先铺满地面。
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                world.set(x, y, BlockType.DIRT);
            }
        }

        if (width < 8 || height < 8) {
            return world;
        }

        // 外围一圈树干做围栏。
        for (int x = 0; x < width; x++) {
            world.set(x, 0, BlockType.WOOD);
            world.set(x, height - 1, BlockType.WOOD);
        }
        for (int y = 0; y < height; y++) {
            world.set(0, y, BlockType.WOOD);
            world.set(width - 1, y, BlockType.WOOD);
        }

        // 地图中央偏左挖一个 3x3 水塘，作为不可通行区域的示例。
        int pondX = Math.max(2, width / 2 - WATER_POND_SIZE - 1);
        int pondY = Math.max(2, height / 2 - 1);
        for (int dy = 0; dy < WATER_POND_SIZE; dy++) {
            for (int dx = 0; dx < WATER_POND_SIZE; dx++) {
                world.set(pondX + dx, pondY + dy, BlockType.WATER);
            }
        }

        // 地图中央偏右放几块石头，作为可挖的示例。
        int stoneX = Math.min(width - 3, width / 2 + 2);
        int stoneY = height / 2;
        world.set(stoneX, stoneY, BlockType.STONE);
        world.set(stoneX, stoneY + 1, BlockType.STONE);

        return world;
    }
}
