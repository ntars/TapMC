package cn.ntars.tapmc.protocol;

import com.google.gson.annotations.SerializedName;

import java.util.Map;

/**
 * 一条 JSON-RPC 2.0 报文。
 *
 * <p>同一个类要能表示三种东西，靠「哪些字段非空」区分：
 *
 * <ul>
 *   <li><b>请求</b>：有 {@code id} 与 {@code method}，{@code result / error} 为空；
 *   <li><b>成功响应</b>：有 {@code id} 与 {@code result}，{@code error} 为空；
 *   <li><b>失败响应</b>：有 {@code id} 与 {@code error}，{@code result} 为空；
 *   <li><b>通知</b>（服务端主动推的事件）：没有 {@code id}，也没有 {@code result / error}。
 * </ul>
 *
 * <p>字段名带 {@code @SerializedName}，因为线上必须是小驼峰 {@code method} 这类名字，
 * 而 Java 侧习惯用 {@code getMethod()}；显式命名避免序列化器版本差异带来字段改名。
 *
 * <p>{@code id} 用 {@code String} 而非数字：JSON-RPC 允许字符串或数字，
 * 统一成字符串后两端不必为「数字精度」做特殊处理。
 */
public final class RpcEnvelope {

    @SerializedName("jsonrpc")
    private final String jsonrpc = JsonRpc.VERSION;

    @SerializedName("id")
    private final String id;

    @SerializedName("method")
    private final String method;

    @SerializedName("params")
    private final Map<String, Object> params;

    @SerializedName("result")
    private final Object result;

    @SerializedName("error")
    private final RpcError error;

    private RpcEnvelope(String id, String method, Map<String, Object> params, Object result, RpcError error) {
        this.id = id;
        this.method = method;
        this.params = params;
        this.result = result;
        this.error = error;
    }

    /** 构造请求或通知。{@code id} 传 null 即为通知。 */
    public static RpcEnvelope request(String id, String method, Map<String, Object> params) {
        return new RpcEnvelope(id, method, params, null, null);
    }

    /** 构造成功响应。 */
    public static RpcEnvelope success(String id, Object result) {
        return new RpcEnvelope(id, null, null, result, null);
    }

    /** 构造失败响应。 */
    public static RpcEnvelope failure(String id, int code, String message) {
        return new RpcEnvelope(id, null, null, null, new RpcError(code, message));
    }

    /** 构造服务端主动推送的事件通知。 */
    public static RpcEnvelope event(String method, Map<String, Object> params) {
        return new RpcEnvelope(null, method, params, null, null);
    }

    public String getJsonrpc() {
        return jsonrpc;
    }

    public String getId() {
        return id;
    }

    public String getMethod() {
        return method;
    }

    public Map<String, Object> getParams() {
        return params;
    }

    public Object getResult() {
        return result;
    }

    public RpcError getError() {
        return error;
    }

    /** 是否是一条请求（要回落响应）。通知不回落。 */
    public boolean isRequest() {
        return method != null && id != null;
    }

    /** 是否是服务端推送的事件通知。 */
    public boolean isEvent() {
        return method != null && id == null;
    }

    /** 是否带了错误。 */
    public boolean isFailure() {
        return error != null;
    }
}
