package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * {@code system.hello} 的返回。
 *
 * <p>前端拿到这份数据后应该：① 校验 {@code protocolVersion} 是否与自己支持的一致，
 * 不一致就提示「版本不匹配」而不是硬连；② 用 {@code worldWidth / worldHeight}
 * 决定画布比例。
 */
public final class HelloResult {

    @SerializedName("serverName")
    private final String serverName;

    @SerializedName("serverVersion")
    private final String serverVersion;

    /** 协议版本。与前端不同则拒绝通信，避免字段错位导致的诡异 bug。 */
    @SerializedName("protocolVersion")
    private final String protocolVersion;

    @SerializedName("worldWidth")
    private final int worldWidth;

    @SerializedName("worldHeight")
    private final int worldHeight;

    /** 当前已有的方块类型名，前端据此配色。 */
    @SerializedName("blockTypes")
    private final java.util.List<String> blockTypes;

    public HelloResult(String serverName, String serverVersion, String protocolVersion,
                       int worldWidth, int worldHeight, java.util.List<String> blockTypes) {
        this.serverName = serverName;
        this.serverVersion = serverVersion;
        this.protocolVersion = protocolVersion;
        this.worldWidth = worldWidth;
        this.worldHeight = worldHeight;
        this.blockTypes = blockTypes;
    }

    public String getServerName() {
        return serverName;
    }

    public String getServerVersion() {
        return serverVersion;
    }

    public String getProtocolVersion() {
        return protocolVersion;
    }

    public int getWorldWidth() {
        return worldWidth;
    }

    public int getWorldHeight() {
        return worldHeight;
    }

    public java.util.List<String> getBlockTypes() {
        return blockTypes;
    }
}
