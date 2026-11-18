import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapmc/data/rpc/rpc_client.dart';
import 'package:tapmc/data/transport/transport.dart';
import 'package:tapmc/domain/protocol.dart';

/// 可控的假传输层：测试自己往里塞入站报文，并检查出站报文。
class FakeTransport implements Transport {
  final _incoming = StreamController<String>.broadcast();
  final List<String> sent = [];
  bool connected = false;
  bool closed = false;

  @override
  Future<void> connect() async {
    connected = true;
  }

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String text) {
    if (!connected) throw const TransportException('未连接');
    sent.add(text);
  }

  @override
  Future<void> close() async {
    connected = false;
    closed = true;
    await _incoming.close();
  }

  @override
  bool get isConnected => connected;

  /// 模拟服务端推一条报文下来。
  void receive(String text) => _incoming.add(text);

  /// 解析最后一条发出报文的 JSON。
  Map<String, dynamic> get lastSent =>
      jsonDecode(sent.last) as Map<String, dynamic>;
}

void main() {
  late FakeTransport transport;
  late RpcClient client;

  setUp(() async {
    transport = FakeTransport();
    client = RpcClient(transport);
    await client.connect();
  });

  tearDown(() async {
    await client.dispose();
  });

  group('请求与响应', () {
    test('发出的报文符合 JSON-RPC 2.0 形状', () async {
      final future = client.call<dynamic>(
        Methods.worldGetBlock,
        params: {'x': 3, 'y': 4},
      );
      await Future<void>.delayed(Duration.zero);

      final sent = transport.lastSent;
      expect(sent['jsonrpc'], '2.0');
      expect(sent['method'], Methods.worldGetBlock);
      expect(sent['id'], isA<String>());
      expect(sent['params'], {'x': 3, 'y': 4});

      // 把这条请求收尾，避免 tearDown 关连接时留下悬挂的 Future。
      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'id': sent['id'] as String,
        'result': 'DIRT',
      }));
      expect(await future, 'DIRT');
    });

    test('params 为空时报文里不出现 params 字段', () async {
      final future = client.call<dynamic>(Methods.systemHello);
      await Future<void>.delayed(Duration.zero);

      expect(transport.lastSent.containsKey('params'), isFalse,
          reason: '与后端「省略 null」的约定一致');

      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'id': transport.lastSent['id'] as String,
        'result': const <String, dynamic>{},
      }));
      await future;
    });

    test('收到同 id 的响应时完成对应的 Future', () async {
      final future = client.call<Map<String, dynamic>>(Methods.systemHello);
      await Future<void>.delayed(Duration.zero);

      final id = transport.lastSent['id'] as String;
      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': {'serverName': 'TapMC'},
      }));

      expect(await future, {'serverName': 'TapMC'});
    });

    test('响应带 error 时抛 RpcException 并保留错误码', () async {
      final future = client.call<dynamic>(Methods.playerMove);
      await Future<void>.delayed(Duration.zero);

      final id = transport.lastSent['id'] as String;
      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': JsonRpc.cancelledByMod, 'message': '被模组拦下：牢笼已锁'},
      }));

      await expectLater(
        future,
        throwsA(isA<RpcException>()
            .having((e) => e.code, 'code', JsonRpc.cancelledByMod)
            .having((e) => e.isCancelledByMod, 'isCancelledByMod', true)),
      );
    });

    test('超时抛 TimeoutException 且不泄漏等待者', () async {
      final future = client.call<dynamic>(
        Methods.systemHello,
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(future, throwsA(isA<TimeoutException>()));

      // 超时后迟到的响应应被安全丢弃，不抛异常。
      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'id': '0',
        'result': 'late',
      }));
    });

    test('多个并发请求按 id 正确配对', () async {
      final first = client.call<dynamic>(Methods.systemHello);
      final second = client.call<dynamic>(Methods.worldSnapshot);
      await Future<void>.delayed(Duration.zero);

      final ids = transport.sent
          .map((raw) => (jsonDecode(raw) as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(ids.length, 2);

      // 故意倒序回包，验证不是按到达顺序瞎猜。
      transport.receive(
          jsonEncode({'jsonrpc': '2.0', 'id': ids[1], 'result': 'second'}));
      transport.receive(
          jsonEncode({'jsonrpc': '2.0', 'id': ids[0], 'result': 'first'}));

      expect(await first, 'first');
      expect(await second, 'second');
    });
  });

  group('事件', () {
    test('无 id 的报文被当作事件推入流', () async {
      final received = <RpcEvent>[];
      final sub = client.events.listen(received.add);

      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'method': Methods.eventWorldChanged,
        'params': {
          'change': {
            'pos': {'x': 1, 'y': 2},
            'block': 'STONE',
            'actor': 'player-1',
          }
        },
      }));

      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);
      expect(received.first.method, Methods.eventWorldChanged);
      await sub.cancel();
    });

    test('坏报文被丢弃且不打断连接', () async {
      final received = <RpcEvent>[];
      final sub = client.events.listen(received.add);

      transport.receive('这不是 JSON');
      transport.receive('[1,2,3]');
      transport.receive(jsonEncode({
        'jsonrpc': '2.0',
        'method': Methods.eventWorldChanged,
        'params': const <String, dynamic>{},
      }));

      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1, reason: '只有合法事件被采纳');
      await sub.cancel();
    });
  });

  group('连接断开', () {
    test('断开时所有等待中的请求立刻失败，而不是等到超时', () async {
      final future = client.call<dynamic>(Methods.systemHello);
      await Future<void>.delayed(Duration.zero);

      await transport.close();

      await expectLater(future, throwsA(isA<TransportException>()));
    });

    test('断开后发送请求抛 TransportException', () async {
      await transport.close();
      await expectLater(
        client.call<dynamic>(Methods.systemHello),
        throwsA(isA<TransportException>()),
      );
    });
  });
}
