import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/theme.dart';
import 'data/game_repository.dart';
import 'data/rpc/rpc_client.dart';
import 'data/transport/web_socket_transport.dart';
import 'presentation/game_session.dart';
import 'presentation/pages/home_page.dart';

void main() {
  runApp(const TapMcApp());
}

/// 应用根。负责装配依赖：传输 → RPC 客户端 → 仓储 → 会话。
///
/// 装配放在 [State] 里而不是全局单例，是为了让 widget 销毁时能一并释放
/// 网络连接；全局单例在热重载时会留下多个连接。
class TapMcApp extends StatefulWidget {
  const TapMcApp({super.key});

  @override
  State<TapMcApp> createState() => _TapMcAppState();
}

class _TapMcAppState extends State<TapMcApp> {
  late final RpcClient _rpc;
  late final GameSession _session;

  @override
  void initState() {
    super.initState();
    _rpc = RpcClient(WebSocketTransport(AppConfig.endpoint));
    _session = GameSession(GameRepository(_rpc), _rpc);
  }

  @override
  void dispose() {
    _session.dispose();
    _rpc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: TapMcTheme.light(),
      darkTheme: TapMcTheme.dark(),
      // 跟随系统。桌面端 macOS / Windows 会自动用系统的浅深设置。
      themeMode: ThemeMode.system,
      home: HomePage(session: _session),
    );
  }
}
