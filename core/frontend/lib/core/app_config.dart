/// 应用启动配置。
///
/// 后端地址支持两级覆盖，优先级从高到低：
/// 1. 编译期 `--dart-define=TAPMC_SERVER_HOST=192.168.1.10`（真机联调时用）；
/// 2. 平台默认值（见 [endpoint]）。
///
/// Web 端另支持 URL 查询参数 `?server=ws://host:port`，便于静态部署后改后端地址。
library;

import '../data/transport/web_socket_transport.dart';
import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  /// 服务端主机。空串表示按平台自动判断。
  static const String serverHost =
      String.fromEnvironment('TAPMC_SERVER_HOST', defaultValue: '');

  /// 服务端端口。与后端 `Main.DEFAULT_PORT` 保持一致。
  static const int serverPort = 8777;

  /// Web 端 `?server=ws://host:port`。
  static String? get webServer {
    if (!kIsWeb) return null;
    return Uri.base.queryParameters['server'];
  }

  /// 后端地址。
  static Uri get endpoint {
    final override = webServer;
    if (override != null && override.isNotEmpty) {
      final parsed = Uri.tryParse(override);
      if (parsed != null &&
          (parsed.scheme == 'ws' || parsed.scheme == 'wss') &&
          parsed.host.isNotEmpty) {
        return parsed;
      }
      throw FormatException('--server 必须是 ws:// 或 wss:// 开头的合法地址');
    }
    return defaultEndpointFor(host: serverHost, port: serverPort);
  }

  /// 应用名。
  static const String appName = 'TapMC';
}
