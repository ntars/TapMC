package cn.ntars.tapmc.protocol.dto;

import com.google.gson.annotations.SerializedName;

/**
 * 一次请求的通用参数载体。
 *
 * <p>JSON-RPC 的 {@code params} 是自由对象，但把所有方法的参数写成一个类会让
 * 语义混在一起。这里按「大多数方法只需要这些字段」的取舍，给出一个扁平结构，
 * 附带的便利是服务端解析代码只有一份。
 *
 * <p>字段全部可空，由具体方法的校验逻辑决定哪些必填：
 * <ul>
 *   <li>{@code world.getBlock / placeBlock / breakBlock} 用 {@code x / y / block}；
 *   <li>{@code player.move} 用 {@code direction}；
 *   <li>{@code system.hello} 不需要任何字段。
 * </ul>
 */
public final class RpcParams {

    @SerializedName("x")
    private final Integer x;

    @SerializedName("y")
    private final Integer y;

    /** 要放的方块类型名。仅 placeBlock 使用。 */
    @SerializedName("block")
    private final String block;

    /** 移动方向名。仅 move 使用。 */
    @SerializedName("direction")
    private final String direction;

    /** 玩家 id。服务端从连接上下文取，此字段留给「以某玩家身份操作」的调试场景。 */
    @SerializedName("playerId")
    private final String playerId;

    public RpcParams(Integer x, Integer y, String block, String direction, String playerId) {
        this.x = x;
        this.y = y;
        this.block = block;
        this.direction = direction;
        this.playerId = playerId;
    }

    public Integer getX() {
        return x;
    }

    public Integer getY() {
        return y;
    }

    public String getBlock() {
        return block;
    }

    public String getDirection() {
        return direction;
    }

    public String getPlayerId() {
        return playerId;
    }
}
