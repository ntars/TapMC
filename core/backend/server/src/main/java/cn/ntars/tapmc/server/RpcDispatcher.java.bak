package cn.ntars.tapmc.server;

import cn.ntars.tapmc.core.GameEngine;
import cn.ntars.tapmc.core.ModLoader;
import cn.ntars.tapmc.protocol.JsonRpc;
import cn.ntars.tapmc.protocol.Methods;
import cn.ntars.tapmc.protocol.RpcEnvelope;
import cn.ntars.tapmc.protocol.dto.BlockPos;
import cn.ntars.tapmc.protocol.dto.BlockType;
import cn.ntars.tapmc.protocol.dto.HelloResult;
import cn.ntars.tapmc.protocol.dto.MoveDirection;
import cn.ntars.tapmc.protocol.dto.PlayerState;
import cn.ntars.tapmc.protocol.dto.RpcParams;
import cn.ntars.tapmc.protocol.dto.WorldSnapshot;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonSyntaxException;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

/**
 * JSON-RPC 2.0 分发器。输入一段 JSON，输出一段 JSON。
 *
 * <p>这是「传输层」与「游戏逻辑」之间的唯一接缝：它只做三件事——
 * 解析报文、按方法名转调 {@link GameEngine}、把结果或错误包回响应。
 * 任何游戏规则都不写在这里，任何 JSON 处理也不写进 {@code core}。
 *
 * <p><b>玩家身份</b>：方法参数里不传玩家 id，而是由服务端按连接分配并存在
 * 本对象里。前端无法冒充别人——它根本没有那个字段可传。
 */
public final class RpcDispatcher {

    /**
     * 序列化器刻意<b>不</b>输出 null 字段：JSON-RPC 2.0 要求「成功响应不含 error、
     * 失败响应不含 result、通知不含 id」，若把 null 也写出去，对端就得靠判空区分
     * 「这是成功还是失败」，容易写错。省略 null 后，字段存在即有意义。
     */
    private static final Gson GSON = new GsonBuilder().create();

    private final GameEngine engine;
    private final java.util.function.Supplier<List<cn.ntars.tapmc.protocol.dto.ModInfo>> modReport;
    private final int width;
    private final int height;

    /** 本连接对应的玩家 id。谓词：每个连接一个分发器实例。 */
    private String playerId;

    /** 请求 id 生成计数，仅用于服务端主动推事件的兜底 id（正常事件不带 id）。 */
    private final AtomicLong sequence = new AtomicLong();

    public RpcDispatcher(GameEngine engine, ModLoader modLoader, int width, int height) {
        this(engine, modLoader::report, width, height);
    }

    public RpcDispatcher(GameEngine engine,
                         java.util.function.Supplier<List<cn.ntars.tapmc.protocol.dto.ModInfo>> modReport,
                         int width, int height) {
        this.engine = engine;
        this.modReport = modReport;
        this.width = width;
        this.height = height;
    }

    /**
     * 处理一条请求。
     *
     * @return 要回给对端的文本；通知类请求返回 {@code null}
     */
    public String handle(String rawJson) {
        RpcEnvelope request;
        try {
            request = GSON.fromJson(rawJson, RpcEnvelope.class);
        } catch (JsonSyntaxException e) {
            return encode(RpcEnvelope.failure(null, JsonRpc.PARSE_ERROR, "报文不是合法 JSON"));
        }

        if (request == null) {
            return encode(RpcEnvelope.failure(null, JsonRpc.INVALID_REQUEST, "报文为空"));
        }

        String id = request.getId();
        String method = request.getMethod();

        if (method == null || method.isBlank()) {
            return encode(RpcEnvelope.failure(id, JsonRpc.INVALID_REQUEST, "缺少 method 字段"));
        }

        RpcParams params = parseParams(request.getParams());

        try {
            Object result = dispatch(method, params);
            // 通知（无 id）不回落响应。
            if (id == null) {
                return null;
            }
            return encode(RpcEnvelope.success(id, result));
        } catch (MethodNotFound e) {
            return encode(RpcEnvelope.failure(id, JsonRpc.METHOD_NOT_FOUND,
                    "未知方法 " + method + "；可用方法见 docs/protocol.md"));
        } catch (RpcFailure e) {
            return encode(RpcEnvelope.failure(id, e.code, e.getMessage()));
        } catch (RuntimeException e) {
            return encode(RpcEnvelope.failure(id, JsonRpc.INTERNAL_ERROR,
                    "服务端内部错误：" + e.getClass().getSimpleName()
                            + (e.getMessage() == null ? "" : "：" + e.getMessage())));
        }
    }

    /** 业务分发。返回的对象会被序列化成 {@code result}。 */
    private Object dispatch(String method, RpcParams p) {
        return switch (method) {
            case Methods.SYSTEM_HELLO -> hello();
            case Methods.SYSTEM_MODS -> modReport.get();
            case Methods.WORLD_SNAPSHOT -> snapshot();
            case Methods.WORLD_GET_BLOCK -> getBlock(p);
            case Methods.WORLD_PLACE_BLOCK -> placeBlock(p);
            case Methods.WORLD_BREAK_BLOCK -> breakBlock(p);
            case Methods.PLAYER_JOIN -> join();
            case Methods.PLAYER_MOVE -> move(p);
            default -> throw new MethodNotFound();
        };
    }

    /* ---------------- 各方法实现 ---------------- */

    private HelloResult hello() {
        List<String> types = Arrays.stream(BlockType.values()).map(Enum::name).toList();
        return new HelloResult(GameServer.SERVER_NAME, GameServer.SERVER_VERSION,
                GameServer.PROTOCOL_VERSION, width, height, types);
    }

    private WorldSnapshot snapshot() {
        return new WorldSnapshot(width, height, engine.world().toBlockNames());
    }

    private BlockType getBlock(RpcParams p) {
        int x = requireInt(p.getX(), "x");
        int y = requireInt(p.getY(), "y");
        return engine.blockAt(x, y);
    }

    private Object placeBlock(RpcParams p) {
        int x = requireInt(p.getX(), "x");
        int y = requireInt(p.getY(), "y");
        String blockName = p.getBlock();
        if (blockName == null || blockName.isBlank()) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 block 参数");
        }
        BlockType block = GameEngine.parseBlock(blockName);
        if (block == null) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS,
                    "未知方块类型 " + blockName + "；可用：" + blockTypeNames());
        }

        return unwrap(engine.placeBlock(actorId(), x, y, block));
    }

    private Object breakBlock(RpcParams p) {
        int x = requireInt(p.getX(), "x");
        int y = requireInt(p.getY(), "y");
        return unwrap(engine.breakBlock(actorId(), x, y));
    }

    private PlayerState join() {
        if (playerId == null) {
            playerId = "player-" + sequence.incrementAndGet() + "-" + System.nanoTime() % 100000;
        }
        BlockPos spawn = new BlockPos(width / 2, height / 2);
        Optional<PlayerState> state = engine.join(playerId, spawn);
        if (state.isEmpty()) {
            // 没进成世界就不保留 id：下次 join 才可能找到已经腾出的可站立格。
            playerId = null;
            throw new RpcFailure(JsonRpc.INTERNAL_ERROR, "世界中没有可站立的位置，无法加入");
        }
        return state.get();
    }

    /** 连接关闭时释放玩家位。重复关闭安全。 */
    public void onClose() {
        if (playerId != null) {
            engine.leave(playerId);
            playerId = null;
        }
    }

    private PlayerState move(RpcParams p) {
        if (playerId == null) {
            throw new RpcFailure(JsonRpc.NOT_JOINED, "尚未加入世界，请先调用 " + Methods.PLAYER_JOIN);
        }
        String dirName = p.getDirection();
        if (dirName == null || dirName.isBlank()) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 direction 参数");
        }
        MoveDirection direction;
        try {
            direction = MoveDirection.valueOf(dirName);
        } catch (IllegalArgumentException e) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS,
                    "未知方向 " + dirName + "；可用：NORTH / SOUTH / WEST / EAST");
        }

        return unwrap(engine.move(playerId, direction));
    }

    /* ---------------- 辅助 ---------------- */

    /** 把引擎的 Outcome 翻成「有值就返回、被拒就抛 RPC 错误」。 */
    private <T> T unwrap(GameEngine.Outcome<T> outcome) {
        return switch (outcome) {
            case GameEngine.Outcome.Ok<T> ok -> ok.value();
            case GameEngine.Outcome.Rejected<T> rejected ->
                    throw new RpcFailure(classify(rejected.message()), rejected.message());
        };
    }

    /**
     * 按文案把拒绝原因归到错误码。骨架阶段用关键字匹配，
     * 后续若引擎改为返回枚举原因，这里换成 switch 即可。
     */
    private static int classify(String message) {
        if (message.contains("被模组拦下")) {
            return JsonRpc.CANCELLED_BY_MOD;
        }
        if (message.contains("超出世界范围")) {
            return JsonRpc.OUT_OF_BOUNDS;
        }
        if (message.contains("不在世界中")) {
            return JsonRpc.NOT_JOINED;
        }
        return JsonRpc.BLOCK_REJECTED;
    }

    private String actorId() {
        return playerId == null ? "system" : playerId;
    }

    private static int requireInt(Integer value, String name) {
        if (value == null) {
            throw new RpcFailure(JsonRpc.INVALID_PARAMS, "缺少 " + name + " 参数");
        }
        return value;
    }

    private static String blockTypeNames() {
        return String.join(" / ", Arrays.stream(BlockType.values()).map(Enum::name).toList());
    }

    /** 把 {@code params} 自由对象映射成扁平结构。缺字段即 null，由各方法自行校验。 */
    private static RpcParams parseParams(Map<String, Object> raw) {
        if (raw == null) {
            return new RpcParams(null, null, null, null, null);
        }
        return new RpcParams(
                asInt(raw.get("x")),
                asInt(raw.get("y")),
                asString(raw.get("block")),
                asString(raw.get("direction")),
                asString(raw.get("playerId")));
    }

    private static Integer asInt(Object value) {
        return value instanceof Number n ? n.intValue() : null;
    }

    private static String asString(Object value) {
        return value instanceof String s ? s : null;
    }

    private static String encode(RpcEnvelope envelope) {
        return GSON.toJson(envelope);
    }

    /** 内部信号：方法名未注册。 */
    private static final class MethodNotFound extends RuntimeException {
        MethodNotFound() {
            super(null, null, false, false);
        }
    }

    /** 内部信号：需要按指定错误码回给对端。 */
    private static final class RpcFailure extends RuntimeException {
        private final int code;

        RpcFailure(int code, String message) {
            super(message, null, false, false);
            this.code = code;
        }
    }
}
