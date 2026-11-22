package cn.ntars.tapmc.server;

import cn.ntars.tapmc.core.GameEngine;
import cn.ntars.tapmc.core.ReloadableModContext;
import cn.ntars.tapmc.core.WorldGenerator;
import cn.ntars.tapmc.protocol.JsonRpc;
import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.dto.ModInfo;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** 动态加载验收：jar 放入目录即生效，移走即卸载。 */
@DisplayName("模组动态加载")
class DirectoryModLoaderTest {

    @Test
    @DisplayName("放入 jar 后拦截生效，移除 jar 后拦截消失")
    void jarCanBeLoadedAndUnloaded(@TempDir Path temp) throws Exception {
        Path jar = fixtureJar(temp);
        // 先用带内置模组的实例验证：动态加载不得吞掉已注册的内置模组。
        GameServer server = new GameServer(12, 8, java.util.List.of(new BuiltinGuard()));
        assertEquals(1, server.modReport().size());

        server.reloadModsFrom(temp);
        var report = server.modReport();
        assertEquals(2, report.size(), () -> "report=" + report);
        assertEquals("cn.ntars.tapmc.builtin", report.get(0).getId());
        assertEquals("test.guard", report.get(1).getId());
        assertEquals(ModInfo.State.ACTIVE, report.get(1).getState());

        server.handleStateless(request(Methods.WORLD_BREAK_BLOCK, "{\"x\":1,\"y\":1}"));
        JsonObject error = JsonParser.parseString(
                        server.handleStateless(request(Methods.WORLD_PLACE_BLOCK,
                                "{\"x\":1,\"y\":1,\"block\":\"WOOD\"}")))
                .getAsJsonObject().getAsJsonObject("error");
        assertEquals(JsonRpc.CANCELLED_BY_MOD, error.get("code").getAsInt());

        // 模拟「移除 jar」：扫描空目录，旧监听器必须撤销。
        Files.delete(jar);
        server.reloadModsFrom(temp);
        assertEquals(1, server.modReport().size(), "动态模组应已移除，内置模组保留");
        assertEquals("cn.ntars.tapmc.builtin", server.modReport().getFirst().getId());
        server.handleStateless(request(Methods.WORLD_BREAK_BLOCK, "{\"x\":1,\"y\":1}"));
        JsonObject after = JsonParser.parseString(
                        server.handleStateless(request(Methods.WORLD_PLACE_BLOCK,
                                "{\"x\":1,\"y\":1,\"block\":\"WOOD\"}")))
                .getAsJsonObject();
        assertTrue(after.has("result"), "卸载后不该再拦截");
        assertEquals("WOOD", server.engine().getBlock(1, 1));
    }

    /** 内置模组：放在引擎自己的监听器列表里，切换动态上下文时不应丢失。 */
    private static final class BuiltinGuard implements cn.ntars.tapmc.mod.TapMcMod {
        @Override
        public cn.ntars.tapmc.mod.ModMetadata metadata() {
            return new cn.ntars.tapmc.mod.SimpleMetadata(
                    "cn.ntars.tapmc.builtin", "内置守卫", "1.0.0");
        }

        @Override
        public void onLoad(cn.ntars.tapmc.mod.ModContext ctx) {
            // 不注册监听，仅验证报告与事件分发路径互不干扰。
        }
    }

    @Test
    @DisplayName("坏 jar 只记为 FAILED，不影响其他 jar")
    void brokenJarIsIsolated(@TempDir Path temp) throws Exception {
        Files.writeString(temp.resolve("00-broken.jar"), "not a jar");
        Files.copy(fixtureSource(), temp.resolve("01-guard.jar"));

        GameEngine engine = new GameEngine(WorldGenerator.generate(8, 8));
        ReloadableModContext context = new ReloadableModContext(engine);
        var report = new DirectoryModLoader(temp, context).loadAll();

        assertEquals(2, report.size());
        assertEquals(ModInfo.State.FAILED, report.get(0).getState());
        assertEquals(ModInfo.State.ACTIVE, report.get(1).getState());
    }

    private static Path fixtureJar(Path dir) throws IOException, URISyntaxException {
        Path target = dir.resolve("guard-mod.jar");
        Files.copy(fixtureSource(), target);
        return target;
    }

    private static Path fixtureSource() throws URISyntaxException {
        return Path.of(DirectoryModLoaderTest.class
                .getResource("/guard-mod.jar").toURI());
    }

    private static String request(String method, String params) {
        return "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"" + method
                + "\",\"params\":" + params + "}";
    }
}
