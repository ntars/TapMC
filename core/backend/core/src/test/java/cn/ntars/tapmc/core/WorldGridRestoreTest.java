package cn.ntars.tapmc.core;

import cn.ntars.tapmc.protocol.dto.BlockType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * 读档路径的单元测试。这类代码最容易出的错是「顺序错位」——把行优先写成一维后
 * 再按列优先读回来，地图会整体倾斜，但每个格子都是合法方块名，肉眼查不出来。
 * 所以这里用「每格值都不同」的 3×2 地图来锁顺序。
 */
@DisplayName("世界网格读档")
class WorldGridRestoreTest {

    @Test
    @DisplayName("名字列表还原后逐格与原世界一致")
    void restoreRoundTrip() {
        WorldGrid original = new WorldGrid(3, 2);
        original.set(0, 0, BlockType.DIRT);
        original.set(1, 0, BlockType.STONE);
        original.set(2, 0, BlockType.WATER);
        original.set(0, 1, BlockType.WOOD);
        original.set(1, 1, BlockType.STONE);
        // (2,1) 留空为 AIR，顺带验证 AIR 也能正确往返。

        WorldGrid restored = WorldGrid.fromBlockNames(3, 2, original.toBlockNames());

        for (int y = 0; y < 2; y++) {
            for (int x = 0; x < 3; x++) {
                assertEquals(original.get(x, y), restored.get(x, y), "(" + x + "," + y + ") 应一致");
            }
        }
    }

    @Test
    @DisplayName("数量与尺寸不符时拒绝还原")
    void restoreRejectsWrongLength() {
        assertThrows(IllegalArgumentException.class,
                () -> WorldGrid.fromBlockNames(3, 2, List.of("DIRT", "DIRT", "DIRT")));
        assertThrows(IllegalArgumentException.class,
                () -> WorldGrid.fromBlockNames(3, 2, null));
    }

    @Test
    @DisplayName("未知方块名时拒绝还原，且错误信息指明第几格")
    void restoreRejectsUnknownBlock() {
        IllegalArgumentException e = assertThrows(IllegalArgumentException.class,
                () -> WorldGrid.fromBlockNames(2, 1, List.of("DIRT", "DIAMOND")));
        assertEquals(true, e.getMessage().contains("第 1 格"), "应指出出错位置：" + e.getMessage());
        assertEquals(true, e.getMessage().contains("DIAMOND"), "应回显非法值：" + e.getMessage());
    }

    @Test
    @DisplayName("还原出的世界可独立修改，不影响入参列表")
    void restoredWorldIsIndependent() {
        List<String> names = List.of("DIRT", "DIRT", "DIRT", "DIRT");
        WorldGrid world = WorldGrid.fromBlockNames(2, 2, names);
        world.set(0, 0, BlockType.STONE);

        assertEquals(BlockType.STONE, world.get(0, 0));
        assertEquals("DIRT", names.get(0), "入参列表不该被改动");
    }
}
