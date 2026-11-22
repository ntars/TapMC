// 桌面端联调用的「透明中转探针」。
//
// 作用：桌面应用把后端地址编译死成 127.0.0.1:8777（见 core/frontend/lib/core/app_config.dart），
// 而后端为了不撞端口会另挑一个空闲端口。本探针坐在 8777 上，把字节原样转给真后端，
// 顺便把每条 JSON 报文记进日志——这样「应用到底有没有真的完成 player.join」
// 就有了可复查的证据，而不是靠肉眼看着窗口说「好像连上了」。
//
// 为什么不用现成 websocket 库：项目红线是不引入新依赖。dart:io 自带
// HttpServer + WebSocketTransformer + WebSocket，零依赖即可完成双向转发。
//
// 用法：
//   dart scripts/macos_verify/relay.dart --listen 8777 --target 8788 --log tmp/macos_verify/relay.log
//
// 退出码：0 正常结束（收到信号或空闲超时）/ 1 端口被占。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 解析 `--key value` 形式的参数，缺省值兜底。
Map<String, String> _parseArgs(List<String> argv, Map<String, String> defaults) {
  final result = Map<String, String>.from(defaults);
  for (var i = 0; i < argv.length - 1; i++) {
    final key = argv[i];
    if (!key.startsWith('--')) continue;
    result[key.substring(2)] = argv[i + 1];
    i++; // 跳过已消费的值
  }
  return result;
}

Future<void> main(List<String> argv) async {
  final args = _parseArgs(argv, {
    'listen': '8777',
    'target': '8788',
    'log': 'tmp/macos_verify/relay.log',
    'idle': '120',
  });

  final listenPort = int.parse(args['listen']!);
  final targetPort = int.parse(args['target']!);
  final idleSeconds = int.parse(args['idle']!);

  final logFile = File(args['log']!);
  await logFile.parent.create(recursive: true);
  final log = await logFile.open(mode: FileMode.write);
  var logClosed = false;

  void write(String line) {
    if (logClosed) return;
    final stamp = DateTime.now().toIso8601String().substring(11, 23);
    log.writeStringSync('$stamp $line\n');
    stdout.writeln('$stamp $line');
  }

  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, listenPort);
  } on SocketException catch (e) {
    stderr.writeln('端口 $listenPort 无法监听：${e.osError?.message ?? e.message}');
    await log.close();
    exit(1);
  }

  write('RELAY_READY listen=$listenPort target=$targetPort');

  // 服务关闭时唤醒 main，避免进程挂死。
  final stopped = Completer<void>();

  server.listen(
    (request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      final client = await WebSocketTransformer.upgrade(request);
      write('CLIENT_CONNECTED from=${request.connectionInfo?.remoteAddress.address}');

      final WebSocket backend;
      try {
        backend = await WebSocket.connect('ws://127.0.0.1:$targetPort');
      } on Object catch (e) {
        write('BACKEND_UNREACHABLE port=$targetPort error=$e');
        await client.close(1011, 'backend unreachable');
        return;
      }
      write('BACKEND_CONNECTED port=$targetPort');

      var sawJoin = false;

      // 上行：客户端 → 后端。
      client.listen(
        (data) {
          write('C>S ${_summarize(data)}');
          backend.add(data);
        },
        onDone: () {
          write('CLIENT_CLOSED');
          backend.close();
        },
        onError: (Object e) {
          write('CLIENT_ERROR $e');
          backend.close();
        },
        cancelOnError: false,
      );

      // 下行：后端 → 客户端。join 的响应在这个方向才能看到。
      backend.listen(
        (data) {
          final summary = _summarize(data);
          write('S>C $summary');
          if (!sawJoin && summary.contains('JOIN_RESULT')) {
            sawJoin = true;
            // 单独一行 JOIN_OK：shell 侧只 grep 这一个标记，不受其它报文影响。
            write('JOIN_OK $summary');
          }
          client.add(data);
        },
        onDone: () {
          write('BACKEND_CLOSED');
          client.close();
        },
        onError: (Object e) {
          write('BACKEND_ERROR $e');
          client.close();
        },
        cancelOnError: false,
      );
    },
    onDone: () {
      if (!stopped.isCompleted) stopped.complete();
    },
    onError: (Object e) {
      write('SERVER_ERROR $e');
      if (!stopped.isCompleted) stopped.complete();
    },
    cancelOnError: false,
  );

  // 空闲兜底：没人连或连接早已断开时，不能让脚本挂死。
  final idleTimer = Timer(Duration(seconds: idleSeconds), () {
    write('IDLE_TIMEOUT ${idleSeconds}s');
    server.close(force: true);
  });

  // 收到终止信号时收尾，供 shell 的 kill 调用。
  final signals = <StreamSubscription<ProcessSignal>>[];
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signals.add(signal.watch().listen((_) {
      write('SIGNAL $signal');
      server.close(force: true);
    }));
  }

  await stopped.future;
  idleTimer.cancel();
  for (final sub in signals) {
    await sub.cancel();
  }
  write('RELAY_STOPPED');
  logClosed = true;
  await log.close();
}

/// 把一帧报文压成一行，太长就截断——日志是给人查的，不该被 384 格快照刷屏。
String _summarize(dynamic data) {
  if (data is! String) return 'binary len=${(data as List).length}';

  final Object? decoded;
  try {
    decoded = jsonDecode(data);
  } on FormatException {
    return 'non-json len=${data.length}';
  }
  if (decoded is! Map<String, dynamic>) return 'non-object len=${data.length}';
  final json = decoded;

  final method = json['method'];
  if (method is String) {
    return 'req id=${json['id']} method=$method';
  }

  final error = json['error'];
  if (error is Map) {
    return 'error id=${json['id']} code=${error['code']} msg=${error['message']}';
  }

  final result = json['result'];
  if (result is Map) {
    // join 的结果含 id 与出生点，靠这个判定「真的进了世界」。
    if (result.containsKey('pos') && result.containsKey('id')) {
      return 'JOIN_RESULT id=${result['id']} pos=${result['pos']}';
    }
    // snapshot 极大，只报尺寸与格数，不写全文。
    final blocks = result['blocks'];
    if (result.containsKey('width') && blocks is List) {
      return 'snapshot ${result['width']}x${result['height']} blocks=${blocks.length}';
    }
    if (result.containsKey('protocolVersion')) {
      return 'hello protocolVersion=${result['protocolVersion']} '
          'world=${result['worldWidth']}x${result['worldHeight']}';
    }
  }
  return 'resp id=${json['id']} len=${data.length}';
}
