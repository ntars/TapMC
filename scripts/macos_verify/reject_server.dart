// 失败路径探针：证明「后端没起」时桌面应用不崩、并明确报错。
//
// 为什么要单独验这条：连不上是用户最常见的第一现场。如果这时应用直接闪退或
// 白屏不出声，用户会以为程序坏了。T03 的判定不只看「能连上」，也看「连不上时
// 是否还能站住」。
//
// 做法：在 8777 上起一个只接受 WebSocket 握手、但立刻用 1011 关掉的假服务端，
// 观察桌面应用是否仍在运行、且日志里出现连接失败的痕迹。
//
// 用法：
//   dart scripts/macos_verify/reject_server.dart --port 8777 --seconds 20
//
// 退出码：0 假服务端正常跑完 / 1 端口被占。

import 'dart:async';
import 'dart:io';

Future<void> main(List<String> argv) async {
  var port = 8777;
  var seconds = 20;
  for (var i = 0; i < argv.length - 1; i++) {
    switch (argv[i]) {
      case '--port':
        port = int.parse(argv[++i]);
      case '--seconds':
        seconds = int.parse(argv[++i]);
    }
  }

  final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException catch (e) {
    stderr.writeln('端口 $port 无法监听：${e.osError?.message ?? e.message}');
    exit(1);
  }

  stdout.writeln('REJECT_READY port=$port');
  var rejected = 0;

  server.listen((request) async {
    // 不是 WebSocket 升级就直接 400，模拟「服务在但说不上话」的情形。
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    rejected++;
    stdout.writeln('REJECT_CONNECTION n=$rejected');
    // 握手成功后立刻断开：前端应把它当作连接失败 / 断线，而不是当成成功。
    await socket.close(1011, 'by design: backend unavailable');
  });

  await Future<void>.delayed(Duration(seconds: seconds));
  stdout.writeln('REJECT_DONE total=$rejected');
  await server.close(force: true);
}
