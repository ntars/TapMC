package cn.ntars.tapmc.server;

import cn.ntars.tapmc.mod.ModContext;
import cn.ntars.tapmc.mod.ModMetadata;
import cn.ntars.tapmc.mod.SimpleMetadata;
import cn.ntars.tapmc.mod.TapMcMod;
import cn.ntars.tapmc.protocol.JsonRpc;
import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.dto.ModInfo;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 模组生态验收：用真实模组走完整链路，证明「能拦、能改、能被看见」。
 *
 * <p>这里的 {@code SampleMod} 同时是 {@code ModContext} 的用法示范，
 * 第三方开发者照着它写就能上手。
 */
@DisplayName("模组生态")
class ModLifecycleTest {

    /** 示例模组：禁止放置树干（模拟「保护原生植被」这类玩法模组）。 */
    private static final class SampleMod implements TapMcMod {

        @Override
        public ModMetadata metadata() {
            return new SimpleMetadata("cn.ntars.tapmc.sample", "示例模组", "1.0.0");
        }

        @Override
        public void onLoad(ModContext ctx) {
            ctx.onBlockPlace(event -> {
                if ("WOOD".equals(event.getBlock())) {
                    event.cancel("此服务器禁止放置树干");
                }
            });
        }
    }

    @Test
    @DisplayName("加载后的模组出现在 system.mods 中")
    void loadedModAppearsInList() {
        GameServer server = new GameServer(12, 8, List.of(new SampleMod()));
        var report = server.modReport();

        assertEquals(1, report.size());
        assertEquals("cn.ntars.tapmc.sample", report.getFirst().getId());
        assertEquals("示例模组", report.getFirst().getName());
        assertEquals(ModInfo.State.ACTIVE, report.getFirst().getState());
    }

    @Test
    @DisplayName("模组的拦截生效，错误码为「被模组取消」")
    void modCancellationSurfacesAsError() {
        GameServer server = new GameServer(12, 8, List.of(new SampleMod()));

        // 先挖出一格空气作为合法放置目标。
        server.handleStateless(request(Methods.WORLD_BREAK_BLOCK, "{\"x\":1,\"y\":1}"));

        JsonObject error = JsonParser.parseString(
                        server.handleStateless(request(Methods.WORLD_PLACE_BLOCK,
                                "{\"x\":1,\"y\":1,\"block\":\"WOOD\"}")))
                .getAsJsonObject().getAsJsonObject("error");

        assertEquals(JsonRpc.CANCELLED_BY_MOD, error.get("code").getAsInt());
        assertTrue(error.get("message").getAsString().contains("禁止放置树干"));
        assertEquals("AIR", server.engine().getBlock(1, 1), "被拦下后世界不该变");
    }

    @Test
    @DisplayName("同一模组放行其他方块")
    void modOnlyBlocksItsOwnTarget() {
        GameServer server = new GameServer(12, 8, List.of(new SampleMod()));
        server.handleStateless(request(Methods.WORLD_BREAK_BLOCK, "{\"x\":1,\"y\":1}"));

        String response = server.handleStateless(request(Methods.WORLD_PLACE_BLOCK,
                "{\"x\":1,\"y\":1,\"block\":\"STONE\"}"));

        assertTrue(JsonParser.parseString(response).getAsJsonObject().has("result"));
        assertEquals("STONE", server.engine().getBlock(1, 1));
    }

    @Test
    @DisplayName("加载抛异常的模组被标为 FAILED，且不拖垮其他模组")
    void brokenModIsIsolated() {
        TapMcMod broken = new TapMcMod() {
            @Override
            public ModMetadata metadata() {
                return new SimpleMetadata("cn.ntars.tapmc.broken", "坏模组", "1.0.0");
            }

            @Override
            public void onLoad(ModContext ctx) {
                throw new IllegalStateException("故意失败");
            }
        };

        GameServer server = new GameServer(12, 8, List.of(broken, new SampleMod()));
        var report = server.modReport();

        assertEquals(2, report.size());
        assertEquals(ModInfo.State.FAILED, report.get(0).getState());
        assertTrue(report.get(0).getReason().contains("故意失败"),
                "失败原因应可见，而不是只标红");
        assertEquals(ModInfo.State.ACTIVE, report.get(1).getState());
    }

    @Test
    @DisplayName("元信息读取失败时记录为未知模组")
    void modWithBrokenMetadataIsReported() {
        TapMcMod noMeta = new TapMcMod() {
            @Override
            public ModMetadata metadata() {
                throw new IllegalStateException("元信息坏了");
            }

            @Override
            public void onLoad(ModContext ctx) {
                // 不会被调用
            }
        };

        var report = new GameServer(8, 8, List.of(noMeta)).modReport();
        assertEquals(1, report.size());
        assertEquals(ModInfo.State.FAILED, report.getFirst().getState());
        assertTrue(report.getFirst().getReason().contains("元信息坏了"));
    }

    @Test
    @DisplayName("同 id 模组只加载第一个，第二个标为 DISABLED")
    void duplicateIdIsDisabled() {
        var report = new GameServer(12, 8, List.of(new SampleMod(), new SampleMod())).modReport();

        assertEquals(2, report.size());
        assertEquals(ModInfo.State.ACTIVE, report.get(0).getState());
        assertEquals(ModInfo.State.DISABLED, report.get(1).getState());
        assertTrue(report.get(1).getReason().contains("同 id"));
    }

    @Test
    @DisplayName("模组可通过上下文直接改世界")
    void modCanWriteWorld() {
        TapMcMod painter = new TapMcMod() {
            @Override
            public ModMetadata metadata() {
                return new SimpleMetadata("cn.ntars.tapmc.painter", "画家", "1.0.0");
            }

            @Override
            public void onLoad(ModContext ctx) {
                ctx.setBlock(1, 1, "STONE");
            }
        };

        var server = new GameServer(12, 8, List.of(painter));
        assertEquals("STONE", server.engine().getBlock(1, 1));
    }

    @Test
    @DisplayName("模组读到的世界尺寸与实际一致")
    void modSeesWorldSize() {
        int[] seen = new int[2];
        TapMcMod probe = new TapMcMod() {
            @Override
            public ModMetadata metadata() {
                return new SimpleMetadata("cn.ntars.tapmc.probe", "探针", "1.0.0");
            }

            @Override
            public void onLoad(ModContext ctx) {
                seen[0] = ctx.worldWidth();
                seen[1] = ctx.worldHeight();
            }
        };

        new GameServer(10, 6, List.of(probe));
        assertEquals(10, seen[0]);
        assertEquals(6, seen[1]);
    }

    @Test
    @DisplayName("模组能拦下玩家移动")
    void modCanBlockMove() {
        TapMcMod jailer = new TapMcMod() {
            @Override
            public ModMetadata metadata() {
                return new SimpleMetadata("cn.ntars.tapmc.jailer", "看守", "1.0.0");
            }

            @Override
            public void onLoad(ModContext ctx) {
                ctx.onPlayerMove(event -> event.cancel("牢笼已锁"));
            }
        };

        var server = new GameServer(12, 8, List.of(jailer));
        // 玩家身份存在分发器里，所以 join 与 move 必须走同一个分发器——
        // 这正是真实连接的行为（一个连接一个分发器）。
        var connection = server.newDispatcher();
        connection.handle(request(Methods.PLAYER_JOIN, null));
        String response = connection.handle(request(Methods.PLAYER_MOVE, "{\"direction\":\"EAST\"}"));

        JsonObject error = JsonParser.parseString(response).getAsJsonObject().getAsJsonObject("error");
        assertEquals(JsonRpc.CANCELLED_BY_MOD, error.get("code").getAsInt());
        assertTrue(error.get("message").getAsString().contains("牢笼已锁"));
    }

    @Test
    @DisplayName("模组能读世界方块")
    void modCanReadWorld() {
        String[] seen = new String[1];
        TapMcMod reader = new TapMcMod() {
            @Override
            public ModMetadata metadata() {
                return new SimpleMetadata("cn.ntars.tapmc.reader", "读者", "1.0.0");
            }

            @Override
            public void onLoad(ModContext ctx) {
                // (0,0) 是生成器铺的围栏。
                seen[0] = ctx.getBlock(0, 0);
            }
        };

        new GameServer(12, 8, List.of(reader));
        assertEquals("WOOD", seen[0]);
    }

    /** 拼一条请求文本。 */
    private static String request(String method, String paramsJson) {
        return paramsJson == null
                ? "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"" + method + "\"}"
                : "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"" + method
                + "\",\"params\":" + paramsJson + "}";
    }
}
