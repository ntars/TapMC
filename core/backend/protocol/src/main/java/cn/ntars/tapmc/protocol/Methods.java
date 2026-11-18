package cn.ntars.tapmc.protocol;

/**
 * RPC 方法名的唯一来源。前端 Dart 侧 {@code RpcMethods} 必须与本类逐条对齐。
 *
 * <p>命名规则：{@code 领域.动作}，全部小写，用点分隔。领域共四个：
 * {@code system}（连接与能力）、{@code world}（世界读写）、{@code player}（玩家）、
 * {@code mod}（模组）。新增方法时先加在这里，再补 docs/protocol.md，最后才写实现。
 *
 * <p>服务端主动推送的事件以 {@code event.} 前缀区分，不占用方法位。
 */
public final class Methods {

    /* ---- system：连接建立后的握手 ---- */

    /** 取服务端信息：版本、协议版本、世界尺寸。前端启动第一件事。 */
    public static final String SYSTEM_HELLO = "system.hello";

    /** 列出生效的模组。前端「模组」页用。 */
    public static final String SYSTEM_MODS = "system.mods";

    /* ---- world：世界读写 ---- */

    /** 取整张地图快照。首屏加载用。 */
    public static final String WORLD_SNAPSHOT = "world.snapshot";

    /** 读单个方块。 */
    public static final String WORLD_GET_BLOCK = "world.getBlock";

    /** 放一个方块。 */
    public static final String WORLD_PLACE_BLOCK = "world.placeBlock";

    /** 挖掉一个方块。 */
    public static final String WORLD_BREAK_BLOCK = "world.breakBlock";

    /* ---- player：玩家 ---- */

    /** 加入世界，占一个玩家位。返回玩家 id 与出生点。 */
    public static final String PLAYER_JOIN = "player.join";

    /** 按方向移动一格。 */
    public static final String PLAYER_MOVE = "player.move";

    /* ---- event：服务端主动推 ---- */

    /** 世界有格子变了。载荷含坐标、新方块类型、触发者。 */
    public static final String EVENT_WORLD_CHANGED = "event.worldChanged";

    /** 有玩家进出了。 */
    public static final String EVENT_PLAYER_CHANGED = "event.playerChanged";

    private Methods() {
    }
}
