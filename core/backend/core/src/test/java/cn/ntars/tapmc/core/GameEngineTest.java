package cn.ntars.tapmc.core;

import cn.ntars.tapmc.protocol.dto.BlockPos;
import cn.ntars.tapmc.protocol.dto.BlockType;
import cn.ntars.tapmc.protocol.dto.MoveDirection;
import cn.ntars.tapmc.protocol.dto.PlayerState;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

@DisplayName("游戏引擎")
class GameEngineTest {

    private WorldGrid world;
    private GameEngine engine;
    private final List<String> broadcasts = new ArrayList<>();

    @BeforeEach
    void setUp() {
        // 用一张手工铺好的 5x5 世界，避免依赖生成器的具体地形。
        // 全图铺泥土，再把右下 2x2 清成空气，给「放置方块」留出合法目标。
        world = new WorldGrid(5, 5);
        for (int y = 0; y < 5; y++) {
            for (int x = 0; x < 5; x++) {
                world.set(x, y, BlockType.DIRT);
            }
        }
        for (int y = 3; y < 5; y++) {
            for (int x = 3; x < 5; x++) {
                world.set(x, y, BlockType.AIR);
            }
        }
        engine = new GameEngine(world);
        engine.onWorldChanged(change -> broadcasts.add(change.getPos() + "=" + change.getBlock()));
    }

    /* ---------------- 玩家 ---------------- */

    @Test
    @DisplayName("正常加入返回出生点")
    void joinAtWalkableSpot() {
        var state = engine.join("p1", new BlockPos(2, 2));
        assertTrue(state.isPresent());
        assertEquals(new BlockPos(2, 2), state.get().getPos());
        assertEquals(1, engine.players().size());
    }

    @Test
    @DisplayName("重复加入是幂等的，不重置已移动的位置")
    void rejoiningKeepsCurrentPosition() {
        engine.join("p1", new BlockPos(2, 2));
        engine.move("p1", MoveDirection.EAST);

        var again = engine.join("p1", new BlockPos(2, 2));

        assertTrue(again.isPresent());
        assertEquals(new BlockPos(3, 2), again.get().getPos());
        assertEquals(1, engine.players().size());
    }

    @Test
    @DisplayName("出生点不可通行时自动找第一个可站立格")
    void joinFallsBackWhenSpawnBlocked() {
        world.set(2, 2, BlockType.WATER);
        var state = engine.join("p1", new BlockPos(2, 2));
        assertTrue(state.isPresent());
        // 第一个可通行格是 (0,0)，因为整张图除 (2,2) 外都铺了泥土。
        assertEquals(new BlockPos(0, 0), state.get().getPos());
    }

    @Test
    @DisplayName("整张图都不可通行时无法加入")
    void joinFailsWhenNoWalkableSpot() {
        for (int y = 0; y < 5; y++) {
            for (int x = 0; x < 5; x++) {
                world.set(x, y, BlockType.WATER);
            }
        }
        assertTrue(engine.join("p1", new BlockPos(0, 0)).isEmpty());
        assertEquals(0, engine.players().size());
    }

    @Test
    @DisplayName("移动一格后位置更新")
    void moveUpdatesPosition() {
        engine.join("p1", new BlockPos(2, 2));
        var outcome = engine.move("p1", MoveDirection.EAST);
        assertTrue(outcome.isOk());
        assertEquals(new BlockPos(3, 2), engine.players().getFirst().getPos());
    }

    @Test
    @DisplayName("四个方向的偏移正确（原点左上）")
    void directionsMatchCoordinateSystem() {
        engine.join("p1", new BlockPos(2, 2));

        engine.move("p1", MoveDirection.NORTH);
        assertEquals(new BlockPos(2, 1), engine.players().getFirst().getPos(), "北 = y-1");

        engine.move("p1", MoveDirection.SOUTH);
        assertEquals(new BlockPos(2, 2), engine.players().getFirst().getPos(), "南 = y+1");

        engine.move("p1", MoveDirection.WEST);
        assertEquals(new BlockPos(1, 2), engine.players().getFirst().getPos(), "西 = x-1");

        engine.move("p1", MoveDirection.EAST);
        assertEquals(new BlockPos(2, 2), engine.players().getFirst().getPos(), "东 = x+1");
    }

    @Test
    @DisplayName("撞到不可通行方块时移动被拒且位置不变")
    void moveBlockedByUnwalkable() {
        world.set(3, 2, BlockType.WATER);
        engine.join("p1", new BlockPos(2, 2));

        var outcome = engine.move("p1", MoveDirection.EAST);
        assertFalse(outcome.isOk());
        assertEquals(new BlockPos(2, 2), engine.players().getFirst().getPos());
    }

    @Test
    @DisplayName("不存在的玩家无法移动")
    void moveUnknownPlayerRejected() {
        var outcome = engine.move("ghost", MoveDirection.EAST);
        assertFalse(outcome.isOk());
    }

    /* ---------------- 方块 ---------------- */

    @Test
    @DisplayName("在空气格上放置方块会改世界并广播")
    void placeOnAirWorks() {
        var outcome = engine.placeBlock("p1", 3, 3, BlockType.STONE);
        assertTrue(outcome.isOk());
        assertEquals(BlockType.STONE, world.get(3, 3));
        assertEquals(List.of("(3,3)=STONE"), broadcasts);
    }

    @Test
    @DisplayName("不允许覆盖已有方块")
    void placeOnOccupiedRejected() {
        // (1,1) 是泥土，非空气。
        var outcome = engine.placeBlock("p1", 1, 1, BlockType.STONE);
        assertFalse(outcome.isOk());
        assertEquals(BlockType.DIRT, world.get(1, 1), "原方块应保持不动");
    }

    @Test
    @DisplayName("不允许显式放置空气")
    void placeAirRejected() {
        var outcome = engine.placeBlock("p1", 3, 3, BlockType.AIR);
        assertFalse(outcome.isOk());
        assertEquals(BlockType.AIR, world.get(3, 3));
    }

    @Test
    @DisplayName("放置越界被拒")
    void placeOutOfBoundsRejected() {
        assertFalse(engine.placeBlock("p1", -1, 0, BlockType.STONE).isOk());
        assertFalse(engine.placeBlock("p1", 0, 5, BlockType.STONE).isOk());
        assertTrue(broadcasts.isEmpty(), "被拒的操作不该广播");
    }

    @Test
    @DisplayName("破坏方块后变空气并广播")
    void breakWorks() {
        var outcome = engine.breakBlock("p1", 2, 2);
        assertTrue(outcome.isOk());
        assertEquals(BlockType.AIR, world.get(2, 2));
        assertEquals(1, broadcasts.size());
    }

    @Test
    @DisplayName("破坏空气被拒")
    void breakAirRejected() {
        world.set(2, 2, BlockType.AIR);
        assertFalse(engine.breakBlock("p1", 2, 2).isOk());
    }

    /* ---------------- 模组 ---------------- */

    @Test
    @DisplayName("模组能拦下放置，且世界不变")
    void modCanCancelPlace() {
        engine.onBlockPlace(event -> event.cancel("测试拦截"));
        var outcome = engine.placeBlock("p1", 3, 3, BlockType.STONE);

        assertFalse(outcome.isOk());
        assertTrue(outcome instanceof GameEngine.Outcome.Rejected<?> rejected
                && rejected.message().contains("测试拦截"));
        assertEquals(BlockType.AIR, world.get(3, 3));
        assertTrue(broadcasts.isEmpty());
    }

    @Test
    @DisplayName("模组能拦下破坏")
    void modCanCancelBreak() {
        engine.onBlockBreak(event -> event.cancel("保护区域"));
        var outcome = engine.breakBlock("p1", 0, 0);
        assertFalse(outcome.isOk());
        assertEquals(BlockType.DIRT, world.get(0, 0));
    }

    @Test
    @DisplayName("模组能拦下移动")
    void modCanCancelMove() {
        engine.join("p1", new BlockPos(2, 2));
        engine.onPlayerMove(event -> event.cancel("禁止移动"));
        var outcome = engine.move("p1", MoveDirection.EAST);
        assertFalse(outcome.isOk());
        assertEquals(new BlockPos(2, 2), engine.players().getFirst().getPos());
    }

    @Test
    @DisplayName("多个模组拦截时保留第一个理由")
    void firstCancelReasonWins() {
        engine.onBlockPlace(event -> event.cancel("第一个"));
        engine.onBlockPlace(event -> event.cancel("第二个"));
        var outcome = engine.placeBlock("p1", 3, 3, BlockType.STONE);

        assertTrue(outcome instanceof GameEngine.Outcome.Rejected<?> rejected
                && rejected.message().contains("第一个"));
    }

    @Test
    @DisplayName("模组通过 ModContext 改方块会广播且标记 system")
    void modSetBlockBroadcasts() {
        List<String> actors = new ArrayList<>();
        engine.onWorldChanged(change -> actors.add(change.getActor()));

        assertTrue(engine.setBlock(4, 4, "STONE"));
        assertEquals(BlockType.STONE, world.get(4, 4));
        assertEquals(List.of("system"), actors);
    }

    @Test
    @DisplayName("模组改方块时非法方块名被静默忽略")
    void modSetBlockWithBadNameIgnored() {
        assertFalse(engine.setBlock(0, 0, "NOT_A_BLOCK"));
        assertEquals(BlockType.DIRT, world.get(0, 0));
    }

    @Test
    @DisplayName("模组读越界返回空气")
    void modGetBlockOutOfBounds() {
        assertEquals("AIR", engine.getBlock(-5, 99));
    }

    @Test
    @DisplayName("离开世界后无法移动")
    void leaveThenMoveRejected() {
        engine.join("p1", new BlockPos(2, 2));
        assertTrue(engine.leave("p1"));
        assertFalse(engine.move("p1", MoveDirection.EAST).isOk());
    }

    @Test
    @DisplayName("玩家快照不暴露内部对象")
    void playersSnapshotIsIndependent() {
        engine.join("p1", new BlockPos(1, 1));
        List<PlayerState> snapshot = engine.players();
        engine.join("p2", new BlockPos(2, 2));
        assertEquals(1, snapshot.size(), "旧快照不应随新玩家加入而变化");
        assertEquals(2, engine.players().size());
    }
}
