package cn.ntars.tapmc.protocol;

import com.google.gson.annotations.SerializedName;

/**
 * 错误对象。JSON-RPC 2.0 规定 {@code error} 必须含 {@code code} 与 {@code message}。
 *
 * <p>{@code data} 留给具体场景补充结构化信息（例如越界时返回允许的范围），
 * 前端要展示给人看时只读 {@code message}，需要程序化处理时读 {@code code}。
 */
public final class RpcError {

    @SerializedName("code")
    private final int code;

    @SerializedName("message")
    private final String message;

    @SerializedName("data")
    private final Object data;

    public RpcError(int code, String message) {
        this(code, message, null);
    }

    public RpcError(int code, String message, Object data) {
        this.code = code;
        this.message = message;
        this.data = data;
    }

    public int getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }

    public Object getData() {
        return data;
    }
}
