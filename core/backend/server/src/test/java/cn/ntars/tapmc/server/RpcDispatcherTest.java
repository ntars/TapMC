package cn.ntars.tapmc.server;

import cn.ntars.tapmc.protocol.JsonRpc;
import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.dto.BlockType;
import cn.ntars.tapmc.protocol.dto.HelloResult;
import cn.ntars.tapmc.protocol.dto.PlayerState;
import cn.ntars.tapmc.protocol.dto.WorldChange;
import cn.ntars.tapmc.protocol.dto.WorldSnapshot;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 端到端测试：从一段 JSON 文本进去，到一段 JSON 文本出来，中间不碰网络。
 *
 * <p>这些用例的作用是「锁住线上格式」——前端 Dart 侧依赖的就是这里断言的字段名。
 * 改坏任何一个字段，这里就会红。
 */
@DisplayName("RPC 全链路")
class RpcDispatcherTest {

    private static final Gson GSON = new Gson();

    private GameServer server;
    private RpcDispatcher dispatcher;

    @BeforeEach
    void setUp() {
        server = new GameServer(12, 8, List.of());
        dispatcher = server.newDispatcher();
    }

    /** 发一条请求并解析响应。 */
    private JsonObject call(String method, String paramsJson) {
        String raw = paramsJson == null
                ? "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"" + method + "\"}"
                : "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"" + method + "\",\"params\":" + paramsJson + "}";
        String response = dispatcher.handle(raw);
        assertNotNull(response, "请求必须有响应");
        return JsonParser.parseString(response).getAsJsonObject();
    }

    /* ---------------- 协议骨架 ---------------- */

    @Test
    @DisplayName("响应都带 jsonrpc 版本与回显 id")
    void responseEchoesIdAndVersion() {
        JsonObject response = call(Methods.SYSTEM_HELLO, null);
        assertEquals("2.0", response.get("jsonrpc").getAsString());
        assertEquals("1", response.get("id").getAsString());
        assertTrue(response.has("result"));
        assertTrue(!response.has("error"));
    }

    @Test
    @DisplayName("通知（无 id）不产生响应")
    void notificationGetsNoResponse() {
        String raw = "{\"jsonrpc\":\"2.0\",\"method\":\"" + Methods.SYSTEM_HELLO + "\"}";
        assertNull(dispatcher.handle(raw));
    }

    @Test
    @DisplayName("非法 JSON 返回解析错误")
    void invalidJsonGivesParseError() {
        JsonObject response = JsonParser.parseString(dispatcher.handle("这不是 JSON")).getAsJsonObject();
        assertEquals(JsonRpc.PARSE_ERROR, response.getAsJsonObject("error").get("code").getAsInt());
    }

    @Test
    @DisplayName("未知方法返回方法未找到")
    void unknownMethodGivesMethodNotFound() {
        JsonObject response = call("nope.nothing", null);
        assertEquals(JsonRpc.METHOD_NOT_FOUND, response.getAsJsonObject("error").get("code").getAsInt());
        // 错误文案应指出去哪里找可用方法，而不是只说「错误」。
        assertTrue(response.getAsJsonObject("error").get("message").getAsString()
                .contains("docs/protocol.md"));
    }

    @Test
    @DisplayName("缺 method 字段返回无效请求")
    void missingMethodGivesInvalidRequest() {
        String raw = "{\"jsonrpc\":\"2.0\",\"id\":\"9\"}";
        JsonObject response = JsonParser.parseString(dispatcher.handle(raw)).getAsJsonObject();
        assertEquals(JsonRpc.INVALID_REQUEST, response.getAsJsonObject("error").get("code").getAsInt());
    }

    /* ---------------- system.hello ---------------- */

    @Test
    @DisplayName("hello 返回服务信息与世界尺寸")
    void helloReturnsServerInfo() {
        JsonObject result = call(Methods.SYSTEM_HELLO, null).getAsJsonObject("result");
        assertEquals("TapMC", result.get("serverName").getAsString());
        assertEquals(GameServer.PROTOCOL_VERSION, result.get("protocolVersion").getAsString());
        assertEquals(12, result.get("worldWidth").getAsInt());
        assertEquals(8, result.get("worldHeight").getAsInt());
    }

    @Test
    @DisplayName("hello 的方块类型列表与枚举一致")
    void helloListsAllBlockTypes() {
        HelloResult hello = GSON.fromJson(call(Methods.SYSTEM_HELLO, null).getAsJsonObject("result"),
                HelloResult.class);
        assertEquals(BlockType.values().length, hello.getBlockTypes().size());
    }

    /* ---------------- world 读取 ---------------- */

    @Test
    @DisplayName("snapshot 的格子数与尺寸匹配")
    void snapshotMatchesDimensions() {
        WorldSnapshot snapshot = GSON.fromJson(call(Methods.WORLD_SNAPSHOT, null)
                .getAsJsonObject("result"), WorldSnapshot.class);
        assertEquals(12, snapshot.getWidth());
        assertEquals(8, snapshot.getHeight());
        assertEquals(12 * 8, snapshot.getBlocks().size());
    }

    @Test
    @DisplayName("生成的世界上边界是树干，中心可站立")
    void generatedWorldHasBorder() {
        WorldSnapshot snapshot = GSON.fromJson(call(Methods.WORLD_SNAPSHOT, null)
                .getAsJsonObject("result"), WorldSnapshot.class);

        // 左上角与右上角都是围栏。
        assertEquals("WOOD", snapshot.getBlocks().get(0));
        assertEquals("WOOD", snapshot.getBlocks().get(11));
        // 中心格是泥土（水塘偏左、石头偏右，都不会占正中心）。
        int centerIndex = 4 * 12 + 6;
        assertEquals("DIRT", snapshot.getBlocks().get(centerIndex));
    }

    @Test
    @DisplayName("getBlock 读越界返回 AIR")
    void getBlockOutOfBoundsReturnsAir() {
        String result = call(Methods.WORLD_GET_BLOCK, "{\"x\":-1,\"y\":0}").get("result").getAsString();
        assertEquals("AIR", result);
    }

    @Test
    @DisplayName("getBlock 缺参数返回参数错误")
    void getBlockWithoutParamsFails() {
        JsonObject error = call(Methods.WORLD_GET_BLOCK, "{\"y\":0}").getAsJsonObject("error");
        assertEquals(JsonRpc.INVALID_PARAMS, error.get("code").getAsInt());
        assertTrue(error.get("message").getAsString().contains("x"));
    }

    /* ---------------- 方块操作 ---------------- */

    @Test
    @DisplayName("破坏围栏后可以放新方块")
    void breakThenPlace() {
        // placeBlock / breakBlock 的 result 直接就是变化本身（WorldChange），不再套一层。
        call(Methods.PLAYER_JOIN, null);

        JsonObject broken = call(Methods.WORLD_BREAK_BLOCK, "{\"x\":0,\"y\":0}").getAsJsonObject("result");
        assertEquals("AIR", broken.get("block").getAsString());
        assertEquals(0, broken.getAsJsonObject("pos").get("x").getAsInt());
        assertEquals(0, broken.getAsJsonObject("pos").get("y").getAsInt());

        JsonObject placed = call(Methods.WORLD_PLACE_BLOCK,
                "{\"x\":0,\"y\":0,\"block\":\"STONE\"}").getAsJsonObject("result");
        assertEquals("STONE", placed.get("block").getAsString());
    }

    @Test
    @DisplayName("放置到已占用格返回方块被拒")
    void placeOnOccupiedGivesBlockRejected() {
        JsonObject error = call(Methods.WORLD_PLACE_BLOCK,
                "{\"x\":6,\"y\":4,\"block\":\"STONE\"}").getAsJsonObject("error");
        assertEquals(JsonRpc.BLOCK_REJECTED, error.get("code").getAsInt());
    }

    @Test
    @DisplayName("放置越界返回越界错误")
    void placeOutOfBoundsGivesOutOfBounds() {
        JsonObject error = call(Methods.WORLD_PLACE_BLOCK,
                "{\"x\":99,\"y\":99,\"block\":\"STONE\"}").getAsJsonObject("error");
        assertEquals(JsonRpc.OUT_OF_BOUNDS, error.get("code").getAsInt());
    }

    @Test
    @DisplayName("未知方块名返回参数错误并列出可用值")
    void placeUnknownBlockListsValidNames() {
        JsonObject error = call(Methods.WORLD_PLACE_BLOCK,
                "{\"x\":6,\"y\":4,\"block\":\"DIAMOND\"}").getAsJsonObject("error");
        assertEquals(JsonRpc.INVALID_PARAMS, error.get("code").getAsInt());
        assertTrue(error.get("message").getAsString().contains("STONE"));
    }

    /* ---------------- 玩家 ---------------- */

    @Test
    @DisplayName("未加入世界就移动返回未加入错误")
    void moveBeforeJoinFails() {
        JsonObject error = call(Methods.PLAYER_MOVE, "{\"direction\":\"EAST\"}").getAsJsonObject("error");
        assertEquals(JsonRpc.NOT_JOINED, error.get("code").getAsInt());
    }

    @Test
    @DisplayName("加入后能移动，位置按方向变化")
    void joinThenMove() {
        PlayerState joined = GSON.fromJson(call(Methods.PLAYER_JOIN, null)
                .getAsJsonObject("result"), PlayerState.class);
        assertEquals(6, joined.getPos().getX());
        assertEquals(4, joined.getPos().getY());

        PlayerState moved = GSON.fromJson(call(Methods.PLAYER_MOVE, "{\"direction\":\"NORTH\"}")
                .getAsJsonObject("result"), PlayerState.class);
        assertEquals(3, moved.getPos().getY(), "北 = y-1，出生点 y=4 应变成 3");
        assertEquals(joined.getId(), moved.getId(), "移动不该换 id");
    }

    @Test
    @DisplayName("非法方向返回参数错误")
    void unknownDirectionFails() {
        call(Methods.PLAYER_JOIN, null);
        JsonObject error = call(Methods.PLAYER_MOVE, "{\"direction\":\"UP\"}").getAsJsonObject("error");
        assertEquals(JsonRpc.INVALID_PARAMS, error.get("code").getAsInt());
    }

    /* ---------------- 广播 ---------------- */

    @Test
    @DisplayName("世界变化会推送给已连接会话")
    void worldChangeIsBroadcast() {
        RecordingSession session = new RecordingSession("s1");
        server.attach(session);

        call(Methods.WORLD_BREAK_BLOCK, "{\"x\":0,\"y\":0}");

        assertEquals(1, session.messages.size(), "应收到一条事件");
        JsonObject event = JsonParser.parseString(session.messages.getFirst()).getAsJsonObject();
        assertEquals(Methods.EVENT_WORLD_CHANGED, event.get("method").getAsString());
        assertTrue(!event.has("id"), "事件不带 id，前端不该回响应");
        assertEquals("AIR", event.getAsJsonObject("params").getAsJsonObject("change")
                .get("block").getAsString());
    }

    @Test
    @DisplayName("断开的会话不再收到广播")
    void detachedSessionStopsReceiving() {
        RecordingSession session = new RecordingSession("s1");
        server.attach(session);
        call(Methods.WORLD_BREAK_BLOCK, "{\"x\":0,\"y\":0}");
        assertEquals(1, session.messages.size());

        server.detach(session);
        call(Methods.WORLD_BREAK_BLOCK, "{\"x\":1,\"y\":0}");
        assertEquals(1, session.messages.size(), "已摘除的会话不该再收到");
    }

    @Test
    @DisplayName("多个会话都收到同一批广播")
    void broadcastReachesAllSessions() {
        RecordingSession a = new RecordingSession("a");
        RecordingSession b = new RecordingSession("b");
        server.attach(a);
        server.attach(b);

        call(Methods.WORLD_BREAK_BLOCK, "{\"x\":2,\"y\":0}");

        assertEquals(1, a.messages.size());
        assertEquals(1, b.messages.size());
    }

    /* ---------------- 模组 ---------------- */

    @Test
    @DisplayName("无模组时列表为空")
    void modListEmptyByDefault() {
        var result = call(Methods.SYSTEM_MODS, null).getAsJsonArray("result");
        assertEquals(0, result.size());
    }

    /** 记录收到的所有文本，用来断言广播。 */
    private static final class RecordingSession implements ClientSession {
        private final String id;
        private final List<String> messages = new java.util.ArrayList<>();

        RecordingSession(String id) {
            this.id = id;
        }

        @Override
        public String id() {
            return id;
        }

        @Override
        public void send(String text) {
            messages.add(text);
        }
    }

    /** 让 WorldChange 的导入不被判为未使用（用于类型提示）。 */
    @SuppressWarnings("unused")
    private static void typeCheck(WorldChange change) {
        assertNotNull(change);
    }
}
