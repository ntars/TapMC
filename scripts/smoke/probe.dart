// 冒烟探针：用真实 WebSocket 连后端，跑一遍最小握手链路。
//
// 为什么用 Dart 而不是 Node / Python：Flutter 本身就是本项目的硬性前置，
// 而 `dart:io` 自带 WebSocket 客户端，不需要任何第三方包，也不用装解释器。
// 这个文件只 `import 'dart:...'`，因此可以直接 `dart scripts/smoke/probe.dart`
// 运行，不依赖 pubspec。
//
// 用法：
//   dart scripts/smoke/probe.dart [--host 127.0.0.1] [--port 8777]
//
// 退出码：0 全部断言通过；1 断言失败；2 连不上（后端没起）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 超时上限。本地回环一次往返在毫秒级，5 秒还没回说明服务端真的卡住了，
/// 继续等只会让冒烟脚本挂在那里看不出原因。
const Duration _timeout = Duration(seconds: 5);

Future<void> main(List<String> args) async {
  var host = '127.0.0.1';
  var port = 8777;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--host':
        if (i + 1 < args.length) host = args[++i];
      case '--port':
        if (i + 1 < args.length) port = int.parse(args[++i]);
      case '--help' || '-h':
        stdout.writeln('用法: dart scripts/smoke/probe.dart [--host 127.0.0.1] [--port 8777]');
        return;
      default:
        stderr.writeln('未知参数: ${args[i]}');
        exit(2);
    }
  }

  final uri = Uri(scheme: 'ws', host: host, port: port);
  stdout.writeln('[probe] 连接 $uri');

  WebSocket socket;
  try {
    socket = await WebSocket.connect(uri.toString()).timeout(_timeout);
  } on Object catch (error) {
    stderr.writeln('[probe] 连接失败：$error');
    exit(2);
  }

  final pending = <String, Completer<Map<String, dynamic>>>{};
  final incoming = StreamQueue(socket);

  // 收包循环：响应按 id 配对，事件（无 id）直接丢弃——冒烟只关心握手结果。
  //
  // 这个循环在 socket 关闭时必然抛错退出（流关闭 /=/ 异常）。它是 unawaited 的，
  // 若不吞掉异常，Dart 会把「连接已关闭」打到 stderr，看起来像冒烟失败。
  unawaited(() async {
    try {
      while (true) {
        final frame = await incoming.next();
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
      // 连接结束，正常收场。仍在等响应的请求要立刻失败，不能让它们各自
      // 干等到 5 秒超时——那会把「服务端中途断连」误报成「响应太慢」。
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

  // 返回类型标成 Never（内部 exit）：这样编译器知道执行不会继续，
  // 后面就能把 `String?` 收窄成 `String`，不必满篇写 `!`。
  Never fail(String message) {
    stderr.writeln('[probe] 断言失败：$message');
    exit(1);
  }

  try {
    // ---- 1. system.hello：协议版本是三端对齐的锚点，最先验它 ----
    final hello = await call('system.hello');
    if (hello.containsKey('error')) {
      fail('system.hello 返回错误：${hello['error']}');
    }
    final info = hello['result'] as Map<String, dynamic>;
    final protocolVersion = info['protocolVersion'] as String?;
    final width = info['worldWidth'] as int?;
    final height = info['worldHeight'] as int?;
    final blockTypes = info['blockTypes'] as List<dynamic>?;

    if (protocolVersion == null || protocolVersion.isEmpty) {
      fail('system.hello 未返回 protocolVersion');
    }
    if (width == null || height == null || width <= 0 || height <= 0) {
      fail('system.hello 返回的世界尺寸非法：${width}x$height');
    }
    if (blockTypes == null || blockTypes.isEmpty) {
      fail('system.hello 未返回 blockTypes');
    }
    stdout.writeln('[probe] system.hello OK  protocolVersion=$protocolVersion  '
        'world=${width}x$height  blockTypes=${blockTypes.length}');

    // ---- 2. world.snapshot：格子数必须与尺寸自洽，否则前端渲染必错位 ----
    final snapshot = await call('world.snapshot');
    if (snapshot.containsKey('error')) {
      fail('world.snapshot 返回错误：${snapshot['error']}');
    }
    final world = snapshot['result'] as Map<String, dynamic>;
    final blocks = world['blocks'] as List<dynamic>?;
    if (blocks == null || blocks.length != width * height) {
      fail('world.snapshot 的 blocks 数量与尺寸不符：'
          '${blocks?.length} != ${width * height}');
    }
    stdout.writeln('[probe] world.snapshot OK  blocks=${blocks.length}');

    // ---- 3. player.join：分配身份并给出可站立出生点 ----
    final join = await call('player.join');
    if (join.containsKey('error')) {
      fail('player.join 返回错误：${join['error']}');
    }
    final player = join['result'] as Map<String, dynamic>;
    final playerId = player['id'] as String?;
    final pos = player['pos'] as Map<String, dynamic>?;
    if (playerId == null || playerId.isEmpty) {
      fail('player.join 未返回玩家 id');
    }
    if (pos == null || pos['x'] == null || pos['y'] == null) {
      fail('player.join 未返回出生点坐标');
    }
    final px = pos['x'] as int;
    final py = pos['y'] as int;
    if (px < 0 || px >= width || py < 0 || py >= height) {
      fail('出生点 ($px,$py) 落在世界外');
    }
    stdout.writeln('[probe] player.join OK  id=$playerId  pos=($px,$py)');

    // ---- 4. 收尾 ----
    await socket.close();
    stdout.writeln('[probe] 全部断言通过');
    exit(0);
  } on Object catch (error) {
    fail('$error');
  }
}

/// 极简的「可 await 的流队列」。
///
/// dart:async 的 StreamQueue 在 package:async 里，为了让这个探针零依赖，
/// 这里只实现需要的那一个方法：按到达顺序取下一条。
class StreamQueue {
  StreamQueue(Stream<dynamic> stream) {
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
    if (_buffer.isNotEmpty) {
      return Future<dynamic>.value(_buffer.removeAt(0));
    }
    final completer = Completer<dynamic>();
    _waiter = completer;
    return completer.future;
  }

  Future<void> cancel() => _subscription.cancel();
}
