package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * 一次世界变化。既是 {@code event.worldChanged} 的载荷，也是
 * {@code world.placeBlock / breakBlock} 的返回，这样前端可以用同一段代码处理
 * 「自己改的」与「别人改的」。
 */
public final class WorldChange {

    @SerializedName("pos")
    private final BlockPos pos;

    @SerializedName("block")
    private final BlockType block;

    /** 触发者 id。模组或系统改动时为 {@code "system"}。 */
    @SerializedName("actor")
    private final String actor;

    public WorldChange(BlockPos pos, BlockType block, String actor) {
        this.pos = pos;
        this.block = block;
        this.actor = actor;
    }

    public BlockPos getPos() {
        return pos;
    }

    public BlockType getBlock() {
        return block;
    }

    public String getActor() {
        return actor;
    }
}
