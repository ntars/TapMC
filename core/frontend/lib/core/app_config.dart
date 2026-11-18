/// 应用启动配置。
///
/// 后端地址支持两级覆盖，优先级从高到低：
/// 1. 编译期 `--dart-define=TAPMC_SERVER_HOST=192.168.1.10`（真机联调时用）；
/// 2. 平台默认值（见 [endpoints]）。
///
/// 之所以用编译期常量而不是运行时配置界面：骨架阶段先让「能连上」这件事成立，
/// 配置界面属于后续功能，提前做会多一层没人用的 UI。
library;

import '../data/transport/web_socket_transport.dart';

abstract final class AppConfig {
  /// 服务端主机。空串表示按平台自动判断。
  static const String serverHost =
      String.fromEnvironment('TAPMC_SERVER_HOST', defaultValue: '');

  /// 服务端端口。与后端 `Main.DEFAULT_PORT` 保持一致。
  static const int serverPort = 8777;

  /// 后端地址。
  static Uri get endpoint =>
      defaultEndpointFor(host: serverHost, port: serverPort);

  /// 应用名。
  static const String appName = 'TapMC';
}
