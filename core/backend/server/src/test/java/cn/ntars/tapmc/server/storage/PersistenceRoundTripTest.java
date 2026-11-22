package cn.ntars.tapmc.server.storage;

import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.dto.WorldSnapshot;
import cn.ntars.tapmc.server.GameServer;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 存档的「验收测试」：模拟真实使用路径——起服务、改世界、退出、再起服务，
 * 断言第二轮的 {@code world.snapshot} 与第一轮逐格一致。
 *
 * <p>为什么不用单元测试代替：单元测试只证明「写入的字节能读回」。这条链路真正
 * 容易断的地方在装配层——{@code GameServer} 有没有真的把存档接进构造流程、
 * 读到的世界有没有被生成器覆盖掉。所以这里从 {@link GameServer} 这一层进，
 * 走与 {@code Main} 相同的构造签名。
 */
@DisplayName("重启后世界一致")
class PersistenceRoundTripTest {

    private static final Gson GSON = new Gson();

    /** 取一份快照的方块名列表，走的是与前端完全相同的 RPC 路径。 */
    private static List<String> snapshotBlocks(GameServer server) {
        String response = server.handleStateless(
                "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"" + Methods.WORLD_SNAPSHOT + "\"}");
        JsonObject result = JsonParser.parseString(response).getAsJsonObject().getAsJsonObject("result");
        return GSON.fromJson(result, WorldSnapshot.class).getBlocks();
    }

    @Test
    @DisplayName("改过的方块在重启后仍在原位")
    void editedWorldSurvivesRestart(@TempDir Path dir) {
        JsonWorldStore store = new JsonWorldStore(dir.resolve("world.json"));

        // ---- 第一轮：改三格后存档 ----
        GameServer first = new GameServer(12, 8, List.of(), store);
        assertFalse(first.loadedFromStore(), "首次启动不该有档可读");

        String base = "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"";
        // (0,0) 原本是围栏树干，先破再放石头；(5,5) 挖空。
        assertFalse(first.handleStateless(base + Methods.WORLD_BREAK_BLOCK + "\",\"params\":{\"x\":0,\"y\":0}}")
                .contains("error"), "破坏围栏应成功");
        assertFalse(first.handleStateless(base + Methods.WORLD_PLACE_BLOCK
                + "\",\"params\":{\"x\":0,\"y\":0,\"block\":\"STONE\"}}").contains("error"), "放置石头应成功");
        assertFalse(first.handleStateless(base + Methods.WORLD_BREAK_BLOCK + "\",\"params\":{\"x\":5,\"y\":5}}")
                .contains("error"), "挖空中心附近应成功");

        List<String> before = snapshotBlocks(first);
        assertEquals("STONE", before.get(0), "测试自身前提：左上角已换成石头");
        assertEquals("AIR", before.get(5 * 12 + 5), "测试自身前提：(5,5) 已挖空");

        assertTrue(first.save(), "存档应成功");
        assertTrue(store.file().toFile().exists(), "存档文件应落盘");

        // ---- 第二轮：同一路径重新起服务 ----
        GameServer second = new GameServer(12, 8, List.of(), new JsonWorldStore(dir.resolve("world.json")));
        assertTrue(second.loadedFromStore(), "第二轮应报告「已从存档恢复」");

        assertEquals(before, snapshotBlocks(second), "重启后世界快照必须逐格一致");
    }

    @Test
    @DisplayName("重启后确实读的是存档，而不是重新生成的地形")
    void restartDoesNotFallBackToGeneratedWorld(@TempDir Path dir) {
        JsonWorldStore store = new JsonWorldStore(dir.resolve("world.json"));

        GameServer first = new GameServer(12, 8, List.of(), store);
        // 把整行地表都挖空，新生成的地形不可能长这样。
        for (int x = 0; x < 12; x++) {
            first.handleStateless("{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\""
                    + Methods.WORLD_BREAK_BLOCK + "\",\"params\":{\"x\":" + x + ",\"y\":4}}");
        }
        List<String> modified = snapshotBlocks(first);
        first.save();

        GameServer regenerated = new GameServer(12, 8, List.of());  // 不接存档，作对照
        List<String> fresh = snapshotBlocks(regenerated);

        assertNotEquals(fresh, modified, "测试自身前提：改过的地图应与新生成的不同");

        GameServer second = new GameServer(12, 8, List.of(), new JsonWorldStore(dir.resolve("world.json")));
        assertEquals(modified, snapshotBlocks(second));
    }

    @Test
    @DisplayName("存档尺寸变更后不误载入旧档")
    void sizeChangeIgnoresOldSave(@TempDir Path dir) {
        Path file = dir.resolve("world.json");
        new GameServer(8, 6, List.of(), new JsonWorldStore(file)).save();

        // 换尺寸启动：旧档 8x6 装不进 12x8，应回退到新地形而不是崩掉。
        GameServer bigger = new GameServer(12, 8, List.of(), new JsonWorldStore(file));
        assertFalse(bigger.loadedFromStore(), "尺寸不符应视为没有存档");
        assertEquals(12 * 8, snapshotBlocks(bigger).size());
    }

    @Test
    @DisplayName("未配置存档时 save() 是空操作且不建文件")
    void noStoreMeansNoFile(@TempDir Path dir) {
        GameServer server = new GameServer(8, 6, List.of());
        assertFalse(server.persistent());
        assertTrue(server.save(), "「没要求存档」不算失败");

        try (var stream = java.nio.file.Files.list(dir)) {
            assertEquals(0, stream.count(), "不该在目录里凭空留下文件");
        } catch (java.io.IOException e) {
            throw new AssertionError(e);
        }
    }

    @Test
    @DisplayName("世界改动会让 revision 增长，连续观察可判定「要不要写盘」")
    void revisionTracksChanges(@TempDir Path dir) {
        GameServer server = new GameServer(12, 8, List.of(), new JsonWorldStore(dir.resolve("world.json")));
        long initial = server.revision();

        server.handleStateless("{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\""
                + Methods.WORLD_BREAK_BLOCK + "\",\"params\":{\"x\":0,\"y\":0}}");

        assertEquals(initial + 1, server.revision(), "一次改动应让 revision 加一");
    }
}
