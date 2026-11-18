package cn.ntars.tapmc.protocol;

/**
 * JSON-RPC 2.0 的固定部分：版本号与错误码。
 *
 * <p>协议本身是 JSON-RPC 2.0 的严格子集，只用到 {@code method / params / result / error}
 * 四个字段。前端（Dart）与后端（Java）各自实现编解码，但错误码与方法名以本包为唯一来源。
 *
 * <p>为什么不用 gRPC 或自定义二进制：前端要跑 Web，浏览器只能稳定用 WebSocket +
 * 文本帧；JSON 也便于在日志里直接读。
 */
public final class JsonRpc {

    /** 协议版本，固定 "2.0"。 */
    public static final String VERSION = "2.0";

    /* ---- JSON-RPC 2.0 标准错误码 ---- */

    /** 收到的不是合法 JSON。 */
    public static final int PARSE_ERROR = -32700;
    /** JSON 合法但不符合请求对象的形状。 */
    public static final int INVALID_REQUEST = -32600;
    /** 方法名未注册。 */
    public static final int METHOD_NOT_FOUND = -32601;
    /** 参数类型或字段不合法。 */
    public static final int INVALID_PARAMS = -32602;
    /** 服务端内部异常。 */
    public static final int INTERNAL_ERROR = -32603;

    /* ---- TapMC 自有错误码，落在 -32000 ~ -32099 这段自定义区间 ---- */

    /** 尚未加入游戏就调用了需要玩家身份的方法。 */
    public static final int NOT_JOINED = -32001;
    /** 目标坐标超出世界边界。 */
    public static final int OUT_OF_BOUNDS = -32002;
    /** 目标位置不允许放置或破坏方块。 */
    public static final int BLOCK_REJECTED = -32003;
    /** 事件被某个模组取消。 */
    public static final int CANCELLED_BY_MOD = -32004;

    private JsonRpc() {
    }
}
