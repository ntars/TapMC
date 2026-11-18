package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * 一份模组信息，{@code system.mods} 返回。
 *
 * <p>{@code state} 只有三种取值，前端据此决定是正常显示、标灰还是标红：
 * {@code ACTIVE} 已生效、{@code DISABLED} 被配置关闭、{@code FAILED} 加载失败。
 */
public final class ModInfo {

    public enum State {
        /** 已加载并生效。 */
        ACTIVE,
        /** 被配置关闭，未加载。 */
        DISABLED,
        /** 加载时抛异常，已隔离。 */
        FAILED
    }

    @SerializedName("id")
    private final String id;

    @SerializedName("name")
    private final String name;

    @SerializedName("version")
    private final String version;

    @SerializedName("state")
    private final State state;

    /** 加载失败的原因。成功时为空串而非 null，前端不必判空。 */
    @SerializedName("reason")
    private final String reason;

    public ModInfo(String id, String name, String version, State state, String reason) {
        this.id = id;
        this.name = name;
        this.version = version;
        this.state = state;
        this.reason = reason == null ? "" : reason;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getVersion() {
        return version;
    }

    public State getState() {
        return state;
    }

    public String getReason() {
        return reason;
    }
}
