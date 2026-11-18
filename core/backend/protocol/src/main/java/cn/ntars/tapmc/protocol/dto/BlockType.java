package cn.ntars.tapmc.protocol.dto;

/**
 * 方块类型。骨架阶段只有五种，够画出「地、草、石、水、木」，且每种都有明确的
 * 是否可通行语义，前端据此决定能不能走过去。
 *
 * <p>枚举的 {@code name()} 直接上线（Gson 默认序列化为枚举名），
 * 因此改名等于改协议，必须同步 docs/protocol.md 与前端。
 */
public enum BlockType {

    /** 空气。可通行。 */
    AIR(true),

    /** 泥土。可通行，可挖。 */
    DIRT(true),

    /** 石头。可通行，可挖。 */
    STONE(true),

    /** 水。不可通行。 */
    WATER(false),

    /** 树干。不可通行，可挖。 */
    WOOD(false);

    private final boolean walkable;

    BlockType(boolean walkable) {
        this.walkable = walkable;
    }

    /** 玩家能否站在这一格上。 */
    public boolean isWalkable() {
        return walkable;
    }
}
