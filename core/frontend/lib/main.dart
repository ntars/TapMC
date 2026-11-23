import 'dart:io';
import 'package:flutter/material.dart';

import 'data/game_repository.dart';
import 'data/rpc/rpc_client.dart';
import 'data/transport/web_socket_transport.dart';
import 'domain/java_runtime.dart';
import 'presentation/game_session.dart';
import 'presentation/pages/instance_page.dart';

void main() {
  runApp(const TapMCApp());
}

class TapMCApp extends StatelessWidget {
  const TapMCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapMC 启动器',
      theme: ThemeData.dark(),
      home: const _SetupPage(),
    );
  }
}

/// 启动页面：探测 Java 并启动后端服务
class _SetupPage extends StatefulWidget {
  const _SetupPage();

  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  GameSession? session;
  String statusMessage = '正在探测 Java 运行时...';
  bool isJavaDetected = false;
  String? javaPath;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      // 自动探测 Java 运行时
      final runtime = await JavaRuntimeDetector.detect();
      
      if (runtime == null) {
        setState(() {
          statusMessage = '未找到 Java 运行时，请安装 JDK 8-25';
          isJavaDetected = false;
        });
        return;
      }
      
      setState(() {
        javaPath = runtime.path;
        statusMessage = '已找到 Java ${runtime.version}，启动服务器...';
        isJavaDetected = true;
      });
      
      // 使用探测到的 Java 启动服务器
      await _startJavaServer(runtime.path);
      
      // 等待服务器启动
      await Future.delayed(const Duration(seconds: 2));
      
      // 创建 RPC 客户端和仓储
      final transport = WebSocketTransport(Uri.parse('ws://127.0.0.1:8777'));
      final rpc = RpcClient(transport);
      final repository = GameRepository(rpc);
      session = GameSession(repository, rpc);
      
      setState(() {
        statusMessage = '已启动，正在连接...';
      });
      
      // 尝试连接
      await session!.connect();
      
      setState(() {
        statusMessage = '连接成功！';
      });
      
      // 跳转到实例页面
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const InstancePage(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        statusMessage = '启动失败: $e';
      });
    }
  }

  Future<void> _startJavaServer(String javaPath) async {
    try {
      final jarFile = File('../backend/server/build/libs/server-0.1.0-all.jar');
      final absoluteJarPath = jarFile.absolute.path;
      
      if (!jarFile.existsSync()) {
        throw Exception('JAR 文件不存在: $absoluteJarPath');
      }
      
      final cmd = [
        javaPath,
        '-jar',
        absoluteJarPath,
        '--port', '8777'
      ];
      
      final process = await Process.start(
        cmd[0],
        cmd.sublist(1),
      );
      
      process.stdout.listen((data) {
        debugPrint('[Java Server] ${String.fromCharCodes(data)}');
      });
      
      process.stderr.listen((data) {
        debugPrint('[Java Server Error] ${String.fromCharCodes(data)}');
      });
    } catch (e) {
      debugPrint('Failed to start Java server: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TapMC 启动器'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isJavaDetected)
              Icon(Icons.check_circle, size: 64, color: Colors.green),
            if (!isJavaDetected)
              Icon(Icons.hourglass_empty, size: 64),
            const SizedBox(height: 20),
            Text(statusMessage),
            if (javaPath != null) ...[
              const SizedBox(height: 10),
              Text('Java 路径: $javaPath'),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
