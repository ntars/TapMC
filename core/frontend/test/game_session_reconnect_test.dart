import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapmc/data/game_repository.dart';
import 'package:tapmc/data/rpc/rpc_client.dart';
import 'package:tapmc/data/transport/transport.dart';
import 'package:tapmc/domain/block_type.dart';
import 'package:tapmc/presentation/game_session.dart';

/// 可控传输层：只实现 GameSession 首屏四步与断线所需的报文。
class FakeTransport implements Transport {
  StreamController<String> incomingController =
      StreamController<String>.broadcast();
  final List<String> sent = [];
  bool connected = false;
  int connectCount = 0;

  @override
  Future<void> connect() async {
    connectCount++;
    connected = true;
    if (incomingController.isClosed) {
      incomingController = StreamController<String>.broadcast();
    }
    // 模拟 WebSocket 握手完成后立刻有一批响应到达。
    scheduleMicrotask(() {
      for (final sentText in List<String>.of(sent)) {
        _respond(sentText);
      }
      sent.clear();
    });
  }

  void _respond(String raw) {
    final request = _decode(raw);
    final method = request['method'] as String;
    final id = request['id'] as String;
    final Object result = switch (method) {
      'system.hello' => {
          'serverName': 'TapMC',
          'serverVersion': '0.2.0',
          'protocolVersion': '1.0',
          'worldWidth': 3,
          'worldHeight': 2,
        },
      'world.snapshot' => {
          'width': 3,
          'height': 2,
          'blocks': ['AIR', 'DIRT', 'STONE', 'WOOD', 'WATER', 'AIR'],
        },
      'system.mods' => const <dynamic>[],
      'player.join' => {
          'id': 'player-1',
          'pos': {'x': 1, 'y': 1},
        },
      'player.move' => {
          'id': 'player-1',
          'pos': {'x': 1, 'y': 0},
        },
      _ => throw StateError('意外方法：$method'),
    };
    incomingController.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    }));
  }

  Map<String, dynamic> _decode(String raw) {
    // 直接复用 dart:convert 的极简解析；测试文件允许引入 dart:convert。
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Stream<String> get incoming => incomingController.stream;

  @override
  void send(String text) {
    if (!connected) throw const TransportException('未连接');
    sent.add(text);
    scheduleMicrotask(() {
      if (sent.isNotEmpty) _respond(sent.removeAt(0));
    });
  }

  @override
  Future<void> close() async {
    connected = false;
  }

  @override
  bool get isConnected => connected;

  void dropConnection() {
    connected = false;
    final controller = incomingController;
    incomingController = StreamController<String>.broadcast();
    controller.close();
  }
}

void main() {
  test('断线后自动重连并重建 hello/snapshot/join 闭环', () async {
    final transport = FakeTransport();
    final rpc = RpcClient(transport);
    final session = GameSession(GameRepository(rpc), rpc);

    await session.connect();
    expect(session.status, ConnectionStatus.ready);
    expect(session.isJoined, isTrue);
    expect(session.world.at(0, 1), BlockType.wood);
    expect(transport.connectCount, 1);

    transport.dropConnection();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(session.status, ConnectionStatus.reconnecting);
    expect(session.reconnectAttempt, 1);

    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(session.status, ConnectionStatus.ready);
    expect(session.reconnectAttempt, 0);
    expect(transport.connectCount, 2);
    expect(session.lastAction, contains('已自动重连并恢复世界'));

    session.dispose();
    await rpc.dispose();
  });
}
