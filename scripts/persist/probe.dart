// 存档验证探针：连后端，可选地改几格，然后把 world.snapshot 落成 JSON 文件。
//
// 为什么单独写一个而不复用 scripts/smoke/probe.dart：那个脚本的职责是「断言握手
// 通不通」，它不写文件也不改世界。把它改成两用会让冒烟日志里混进存档的东西。
// 这里只依赖 dart:io 与 dart:convert，所以不需要 pubspec，直接 `dart` 跑。
//
// 用法：
//   dart scripts/persist/probe.dart [--host 127.0.0.1] [--port 8777] [--mutate] [--dump 文件]
//
//   --mutate  先破 (0,0)、放 (0,0) 石头、挖 (5,5)、(6,5)
//   --dump    把快照写到指定文件（不加则只打印摘要）
//
// 退出码：0 成功 / 1 断言失败 / 2 连不上

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const Duration _timeout = Duration(seconds: 5);

/// 改动清单。挑这三处的原因：
/// - (0,0) 是边界围栏，验「破坏 + 放置」两步都过；
/// - (5,5)/(6,5) 在地图内部，验普通地形的写入。
/// 都不依赖地形细节，换世界尺寸也不会挑到水塘上导致「放不下」。
const List<Map<String, Object>> _mutations = [
  {'method': 'world.breakBlock', 'params': {'x': 0, 'y': 0}},
  {'method': 'world.placeBlock', 'params': {'x': 0, 'y': 0, 'block': 'STONE'}},
  {'method': 'world.breakBlock', 'params': {'x': 5, 'y': 5}},
  {'method': 'world.breakBlock', 'params': {'x': 6, 'y': 5}},
];

Future<void> main(List<String> args) async {
  var host = '127.0.0.1';
  var port = 8777;
  var mutate = false;
  String? dumpPath;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--host':
        if (i + 1 < args.length) host = args[++i];
      case '--port':
        if (i + 1 < args.length) port = int.parse(args[++i]);
      case '--mutate':
        mutate = true;
      case '--dump':
        if (i + 1 < args.length) dumpPath = args[++i];
      case '--help' || '-h':
        stdout.writeln('用法: dart scripts/persist/probe.dart '
            '[--host 127.0.0.1] [--port 8777] [--mutate] [--dump 文件]');
        return;
      default:
        stderr.writeln('未知参数: ${args[i]}');
        exit(2);
    }
  }

  final uri = Uri(scheme: 'ws', host: host, port: port);
  WebSocket socket;
  try {
    socket = await WebSocket.connect(uri.toString()).timeout(_timeout);
  } on Object catch (error) {
    stderr.writeln('[persist-probe] 连接失败：$error');
    exit(2);
  }

  final pending = <String, Completer<Map<String, dynamic>>>{};
  final queue = _Queue(socket);

  // 收包循环。socket 关闭时必然抛错，unawaited 的循环若不吞掉，Dart 会把
  // 「连接已关闭」打到 stderr，看着像失败。
  unawaited(() async {
    try {
      while (true) {
        final frame = await queue.next();
        final Map<String, dynamic> message;
        try {
          message = jsonDecode(frame as String) as Map<String, dynamic>;
        } on Object {
          continue;
        }
        final id = message['id'];
        if (id is String) {
          pending.remove(id)?.complete(message);
        }
      }
    } on Object {
      for (final waiter in pending.values) {
        if (!waiter.isCompleted) {
          waiter.completeError(StateError('连接已关闭，请求未得到响应'));
        }
      }
      pending.clear();
    }
  }());

  var seq = 0;
  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic>? params]) {
    final id = (++seq).toString();
    final completer = Completer<Map<String, dynamic>>();
    pending[id] = completer;
    socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    return completer.future.timeout(_timeout, onTimeout: () {
      pending.remove(id);
      throw TimeoutException('$method 在 ${_timeout.inSeconds}s 内没有响应');
    });
  }

  Never fail(String message) {
    stderr.writeln('[persist-probe] 失败：$message');
    exit(1);
  }

  try {
    if (mutate) {
      // 先 join：actor 身份来自连接，没有它 actorId 会是 "system"，
      // 存档里记的改动来源就不真实了。
      final join = await call('player.join');
      if (join.containsKey('error')) fail('player.join 失败：${join['error']}');

      for (final mutation in _mutations) {
        final response = await call(
            mutation['method'] as String, mutation['params'] as Map<String, dynamic>);
        if (response.containsKey('error')) {
          fail('${mutation['method']} ${mutation['params']} 失败：${response['error']}');
        }
      }
      stdout.writeln('[persist-probe] 已应用 ${_mutations.length} 处改动');
    }

    final snapshot = await call('world.snapshot');
    if (snapshot.containsKey('error')) fail('world.snapshot 失败：${snapshot['error']}');
    final result = snapshot['result'] as Map<String, dynamic>;
    final blocks = result['blocks'] as List<dynamic>;
    final width = result['width'] as int;
    final height = result['height'] as int;
    if (blocks.length != width * height) {
      fail('blocks 数量 ${blocks.length} 与 ${width}x$height 不符');
    }

    if (dumpPath != null) {
      await File(dumpPath).writeAsString(jsonEncode({
        'width': width,
        'height': height,
        'blocks': blocks,
      }));
      stdout.writeln('[persist-probe] 快照已写入 $dumpPath（${blocks.length} 格）');
    } else {
      stdout.writeln('[persist-probe] 快照 ${width}x$height，${blocks.length} 格');
    }

    await socket.close();
    exit(0);
  } on Object catch (error) {
    fail('$error');
  }
}

/// 极简「可 await 的流队列」：只实现按序取下一条。
/// package:async 的 StreamQueue 会引入依赖，探针要保持零依赖。
class _Queue {
  _Queue(Stream<dynamic> stream) {
    _subscription = stream.listen(
      (event) {
        final waiter = _waiter;
        if (waiter != null && !waiter.isCompleted) {
          _waiter = null;
          waiter.complete(event);
        } else {
          _buffer.add(event);
        }
      },
      onError: (Object error) {
        _waiter?.completeError(error);
        _waiter = null;
      },
      onDone: () {
        final waiter = _waiter;
        if (waiter != null && !waiter.isCompleted) {
          _waiter = null;
          waiter.completeError(StateError('连接已被服务端关闭'));
        }
      },
    );
  }

  late final StreamSubscription<dynamic> _subscription;
  final List<dynamic> _buffer = [];
  Completer<dynamic>? _waiter;

  Future<dynamic> next() {
    if (_buffer.isNotEmpty) return Future<dynamic>.value(_buffer.removeAt(0));
    final completer = Completer<dynamic>();
    _waiter = completer;
    return completer.future;
  }

  Future<void> cancel() => _subscription.cancel();
}
