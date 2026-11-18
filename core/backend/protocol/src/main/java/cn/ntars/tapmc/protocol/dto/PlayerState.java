package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * 玩家状态。{@code player.join} 与 {@code event.playerChanged} 共用。
 *
 * <p>骨架阶段玩家没有名字与皮肤，只有一个服务端分配的 {@code id} 与坐标，
 * 够前端把「我」和「别人」画成不同颜色。
 */
public final class PlayerState {

    @SerializedName("id")
    private final String id;

    @SerializedName("pos")
    private final BlockPos pos;

    public PlayerState(String id, BlockPos pos) {
        this.id = id;
        this.pos = pos;
    }

    public String getId() {
        return id;
    }

    public BlockPos getPos() {
        return pos;
    }
}
