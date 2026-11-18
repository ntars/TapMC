package cn.ntars.tapmc.core;

import cn.ntars.tapmc.protocol.dto.BlockType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@DisplayName("世界网格")
class WorldGridTest {

    @Test
    @DisplayName("新建的世界全是空气")
    void newWorldIsAllAir() {
        WorldGrid world = new WorldGrid(4, 3);
        for (int y = 0; y < 3; y++) {
            for (int x = 0; x < 4; x++) {
                assertEquals(BlockType.AIR, world.get(x, y), "(" + x + "," + y + ") 应为空气");
            }
        }
    }

    @Test
    @DisplayName("读写同一格能取回写入的值")
    void writeThenRead() {
        WorldGrid world = new WorldGrid(4, 4);
        assertTrue(world.set(1, 2, BlockType.STONE));
        assertEquals(BlockType.STONE, world.get(1, 2));
    }

    @Test
    @DisplayName("读越界返回空气，而不是抛异常")
    void readOutOfBoundsReturnsAir() {
        WorldGrid world = new WorldGrid(4, 4);
        assertEquals(BlockType.AIR, world.get(-1, 0));
        assertEquals(BlockType.AIR, world.get(0, -1));
        assertEquals(BlockType.AIR, world.get(4, 0));
        assertEquals(BlockType.AIR, world.get(0, 4));
    }

    @Test
    @DisplayName("写越界返回 false 且世界不变")
    void writeOutOfBoundsIsRejected() {
        WorldGrid world = new WorldGrid(4, 4);
        assertFalse(world.set(-1, 0, BlockType.STONE));
        assertFalse(world.set(4, 4, BlockType.STONE));
        // 越界写不该在内存里留下痕迹，也不能污染边界格。
        assertEquals(BlockType.AIR, world.get(0, 0));
        assertEquals(BlockType.AIR, world.get(3, 3));
    }

    @Test
    @DisplayName("尺寸非正时构造失败")
    void rejectsNonPositiveSize() {
        assertThrows(IllegalArgumentException.class, () -> new WorldGrid(0, 5));
        assertThrows(IllegalArgumentException.class, () -> new WorldGrid(5, 0));
        assertThrows(IllegalArgumentException.class, () -> new WorldGrid(-1, -1));
    }

    @Test
    @DisplayName("导出顺序为行优先，长度等于格数")
    void exportIsRowMajor() {
        WorldGrid world = new WorldGrid(3, 2);
        world.set(0, 0, BlockType.DIRT);
        world.set(1, 0, BlockType.STONE);
        world.set(2, 0, BlockType.WATER);
        world.set(0, 1, BlockType.WOOD);

        var names = world.toBlockNames();
        assertEquals(6, names.size());
        assertEquals(
                java.util.List.of("DIRT", "STONE", "WATER", "WOOD", "AIR", "AIR"),
                names);
    }

    @Test
    @DisplayName("导出的列表是副本，改它不影响世界")
    void exportIsCopy() {
        WorldGrid world = new WorldGrid(2, 1);
        var names = world.toBlockNames();
        assertThrows(UnsupportedOperationException.class, () -> names.set(0, "STONE"));
        assertEquals(BlockType.AIR, world.get(0, 0));
    }
}
