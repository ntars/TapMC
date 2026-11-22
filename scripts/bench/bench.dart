// TapMC 运行期基准探针。只依赖 dart:io / dart:convert，不需要 pub get。
//
// 测两件事：
//   1. 单连接顺序请求的 P50 / P95 往返延迟；
//   2. 10 个并发连接下的 RPC 错误率。
//
// RSS 不在这里测——Dart 看不到服务端进程的 OS 内存，由 bench.sh 采样 ps / proc。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const Duration _timeout = Duration(seconds: 10);

class RpcPeer {
  RpcPeer._(this._socket);

  final WebSocket _socket;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  late final StreamSubscription<dynamic> _subscription;
  int _nextId = 0;

  static Future<RpcPeer> connect(String host, int port) async {
    final socket = await WebSocket.connect(
      Uri(scheme: 'ws', host: host, port: port).toString(),
    ).timeout(_timeout);
    final peer = RpcPeer._(socket);
    peer._subscription = socket.listen(
      (message) {
        if (message is! String) return;
        Map<String, dynamic> envelope;
        try {
          envelope = jsonDecode(message) as Map<String, dynamic>;
        } on Object {
          return;
        }
        final id = envelope['id'];
        if (id is! String) return;
        final waiter = peer._pending.remove(id);
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(envelope);
        }
      },
      onError: (Object error) => peer._failAll(error),
      onDone: () => peer._failAll(
          StateError('服务端关闭了连接，请检查基准测试期间是否发生崩溃')),
    );
    return peer;
  }

  void _failAll(Object error) {
    for (final waiter in _pending.values) {
      if (!waiter.isCompleted) waiter.completeError(error);
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic>? params]) {
    final id = (_nextId++).toString();
    final waiter = Completer<Map<String, dynamic>>();
    _pending[id] = waiter;
    _socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    return waiter.future.timeout(_timeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('$method 超时', _timeout);
    });
  }

  Future<void> close() async {
    await _subscription.cancel();
    _failAll(StateError('连接已关闭'));
    await _socket.close();
  }
}

double _percentile(List<int> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.of(values)..sort();
  final index = (p * sorted.length).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)] / 1000.0;
}

Future<void> main(List<String> args) async {
  var host = '127.0.0.1';
  var port = 8777;
  var requests = 200;
  var clients = 10;
  var clientRequests = 40;
  String? output;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--host':
        host = args[++i];
      case '--port':
        port = int.parse(args[++i]);
      case '--requests':
        requests = int.parse(args[++i]);
      case '--clients':
        clients = int.parse(args[++i]);
      case '--client-requests':
        clientRequests = int.parse(args[++i]);
      case '--json':
        output = args[++i];
      case '-h' || '--help':
        stdout.writeln('用法: bench.dart [--host H] [--port P] [--requests N] '
            '[--clients N] [--client-requests N] [--json FILE]');
        return;
      default:
        stderr.writeln('未知参数 ${args[i]}');
        exit(2);
    }
  }
  if (requests <= 0 || clients <= 0 || clientRequests <= 0) {
    stderr.writeln('请求数与连接数必须为正整数');
    exit(2);
  }

  final latencies = <int>[];
  var singleErrors = 0;

  final single = await RpcPeer.connect(host, port);
  try {
    await single.call('system.hello');
    await single.call('player.join');
    // 预热：JIT 与连接热身的抖动不计入正式样本。
    for (var i = 0; i < 10; i++) {
      await single.call('world.getBlock', {'x': i % 24, 'y': i % 16});
    }
    for (var i = 0; i < requests; i++) {
      final sw = Stopwatch()..start();
      final response =
          await single.call('world.getBlock', {'x': i % 24, 'y': i % 16});
      sw.stop();
      if (response.containsKey('error')) singleErrors++;
      latencies.add(sw.elapsedMicroseconds);
    }
  } finally {
    await single.close();
  }

  final peers = <RpcPeer>[];
  var concurrentTotal = 0;
  var concurrentErrors = 0;
  var transportFailures = 0;
  try {
    for (var i = 0; i < clients; i++) {
      peers.add(await RpcPeer.connect(host, port));
    }
    await Future.wait(peers.map((peer) async {
      await peer.call('system.hello');
      await peer.call('player.join');
    }));

    final outcomes = await Future.wait(peers.asMap().entries.map((entry) async {
      final index = entry.key;
      final peer = entry.value;
      var completed = 0;
      var errors = 0;
      try {
        for (var j = 0; j < clientRequests; j++) {
          final Map<String, dynamic> response;
          // 每 5 次掺一次整图快照，让并发样本覆盖大响应体而不只是小包往返。
          if ((index + j) % 5 == 0) {
            response = await peer.call('world.snapshot');
          } else {
            response = await peer.call('world.getBlock',
                {'x': (index + j) % 24, 'y': j % 16});
          }
          completed++;
          if (response.containsKey('error')) errors++;
        }
      } on Object catch (error) {
        stderr.writeln('[bench] 连接 $index 中断：$error');
      }
      return (completed: completed, errors: errors);
    }));

    for (final outcome in outcomes) {
      concurrentTotal += outcome.completed;
      concurrentErrors += outcome.errors;
    }
    transportFailures = clients * clientRequests - concurrentTotal;
  } finally {
    await Future.wait(peers.map((peer) => peer.close()));
  }

  final errorRate = concurrentTotal == 0
      ? 1.0
      : (concurrentErrors + transportFailures) / (clients * clientRequests);
  final result = <String, dynamic>{
    'single': {
      'requests': requests,
      'errors': singleErrors,
      'p50Ms': _percentile(latencies, 0.50),
      'p95Ms': _percentile(latencies, 0.95),
    },
    'concurrency': {
      'clients': clients,
      'requestsPerClient': clientRequests,
      'planned': clients * clientRequests,
      'completed': concurrentTotal,
      'responseErrors': concurrentErrors,
      'transportFailures': transportFailures,
      'errorRate': errorRate,
    },
  };

  stdout.writeln('[bench] 单连接 ${requests} 次：'
      'P50 ${result['single']['p50Ms']} ms  '
      'P95 ${result['single']['p95Ms']} ms  '
      '错误 ${singleErrors}');
  stdout.writeln('[bench] ${clients} 并发 × ${clientRequests} 次：'
      '完成 ${concurrentTotal}/${clients * clientRequests}  '
      '响应错误 ${concurrentErrors}  传输失败 ${transportFailures}  '
      '错误率 ${(errorRate * 100).toStringAsFixed(2)}%');

  if (output != null) {
    await File(output).writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
  }

  if (singleErrors > 0 || errorRate > 0) exit(1);
}
