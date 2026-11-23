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

    /* ---- system extensions：系统扩展（P2 新增）---- */

    /** 检查系统健康状态。 */
    public static final String SYSTEM_HEALTH = "system.health";

    /** 重启服务端。 */
    public static final String SYSTEM_RESTART = "system.restart";

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

    /** 离线模式登录。参数：name（玩家名）。返回玩家身份与出生点。 */
    public static final String PLAYER_LOGIN_OFFLINE = "player.loginOffline";

    /** 按方向移动一格。 */
    public static final String PLAYER_MOVE = "player.move";

    /* ---- instance：实例与整合包管理（P2 新增）---- */

    /** 列出所有实例。 */
    public static final String INSTANCE_LIST = "instance.list";

    /** 创建新实例。参数：name（实例名）、templateId（模板ID，可选）。 */
    public static final String INSTANCE_CREATE = "instance.create";

    /** 删除实例。参数：id（实例ID）。 */
    public static final String INSTANCE_DELETE = "instance.delete";

    /** 重命名实例。参数：id（实例ID）、name（新名称）。 */
    public static final String INSTANCE_RENAME = "instance.rename";

    /** 导入整合包。参数：path（zip/mrpack 文件路径）。 */
    public static final String INSTANCE_IMPORT = "instance.import";

    /* ---- mod：模组管理（P2 新增）---- */

    /** 列出实例的模组。参数：instanceId（实例ID）。 */
    public static final String MOD_LIST = "mod.list";

    /** 启用模组。参数：instanceId（实例ID）、modId（模组ID）。 */
    public static final String MOD_ENABLE = "mod.enable";

    /** 禁用模组。参数：instanceId（实例ID）、modId（模组ID）。 */
    public static final String MOD_DISABLE = "mod.disable";

    /** 识别加载器类型。参数：instanceId（实例ID）。 */
    public static final String MOD_DETECT_LOADER = "mod.detectLoader";

    /* ---- download：下载与更新（P2 新增）---- */

    /** 开始下载。参数：url（下载地址）、path（保存路径）。 */
    public static final String DOWNLOAD_START = "download.start";

    /** 暂停下载。参数：taskId（任务ID）。 */
    public static final String DOWNLOAD_PAUSE = "download.pause";

    /** 删除下载任务。参数：taskId（任务ID）。 */
    public static final String DOWNLOAD_DELETE = "download.delete";

    /* ---- log：日志与诊断（P2 新增）---- */

    /** 获取最近的日志。参数：limit（日志条数）。 */
    public static final String LOG_GET = "log.get";

    /** 导出崩溃报告。参数：instanceId（实例ID）。 */
    public static final String LOG_EXPORT_CRASH = "log.exportCrash";

    /** 清空日志。参数：instanceId（实例ID）。 */
    public static final String LOG_CLEAR = "log.clear";

    /* ---- event：服务端主动推 ---- */

    /** 世界有格子变了。载荷含坐标、新方块类型、触发者。 */
    public static final String EVENT_WORLD_CHANGED = "event.worldChanged";

    /** 有玩家进出了。 */
    public static final String EVENT_PLAYER_CHANGED = "event.playerChanged";

    private Methods() {
    }
}
