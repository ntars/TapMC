/// 协议常量：与 Java 侧 `cn.ntars.tapmc.protocol.JsonRpc` / `Methods` 逐条对齐。
///
/// **改动这里必须同步修改后端**，否则会出现「请求发出去没有对应实现」或
/// 「错误码对不上导致提示语错位」。两端各有一份常量是刻意为之：
/// 前端不依赖后端产物，后端也不依赖前端产物。
library;

/// JSON-RPC 2.0 的固定部分。
abstract final class JsonRpc {
  static const String version = '2.0';

  // 标准错误码
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  // TapMC 自有错误码，落在 -32000 ~ -32099
  static const int notJoined = -32001;
  static const int outOfBounds = -32002;
  static const int blockRejected = -32003;
  static const int cancelledByMod = -32004;
}

/// RPC 方法名。命名规则：领域.动作。
abstract final class Methods {
  // system
  static const String systemHello = 'system.hello';
  static const String systemMods = 'system.mods';

  // 系统扩展（P2 新增）
  static const String systemHealth = 'system.health';
  static const String systemRestart = 'system.restart';

  // world
  static const String worldSnapshot = 'world.snapshot';
  static const String worldGetBlock = 'world.getBlock';
  static const String worldPlaceBlock = 'world.placeBlock';
  static const String worldBreakBlock = 'world.breakBlock';

  // player
  static const String playerJoin = 'player.join';
  static const String playerLoginOffline = 'player.loginOffline';
  static const String playerMove = 'player.move';

  // 实例与整合包管理（P2 新增）
  static const String instanceList = 'instance.list';
  static const String instanceCreate = 'instance.create';
  static const String instanceDelete = 'instance.delete';
  static const String instanceRename = 'instance.rename';
  static const String instanceImport = 'instance.import';

  // 模组管理（P2 新增）
  static const String modList = 'mod.list';
  static const String modEnable = 'mod.enable';
  static const String modDisable = 'mod.disable';
  static const String modDetectLoader = 'mod.detectLoader';

  // 下载与更新（P2 新增）
  static const String downloadStart = 'download.start';
  static const String downloadPause = 'download.pause';
  static const String downloadDelete = 'download.delete';

  // 日志与诊断（P2 新增）
  static const String logGet = 'log.get';
  static const String logExportCrash = 'log.exportCrash';
  static const String logClear = 'log.clear';

  // 服务端主动推的事件
  static const String eventWorldChanged = 'event.worldChanged';
  static const String eventPlayerChanged = 'event.playerChanged';
}
