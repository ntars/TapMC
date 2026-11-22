import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapmc/data/game_repository.dart';
import 'package:tapmc/data/rpc/rpc_client.dart';
import 'package:tapmc/data/transport/transport.dart';
import 'package:tapmc/presentation/game_session.dart';
import 'package:tapmc/presentation/pages/home_page.dart';
import 'package:tapmc/presentation/widgets/direction_pad.dart';
import 'package:tapmc/presentation/widgets/world_grid.dart';

/// 只回答首屏四步的传输层。布局测试不需要真实后端。
class _LayoutTransport implements Transport {
  final _incoming = StreamController<String>.broadcast();
  bool connected = false;

  @override
  Future<void> connect() async => connected = true;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String text) {
    final request = jsonDecode(text) as Map<String, dynamic>;
    final method = request['method'] as String;
    if (method == 'world.placeBlock' || method == 'world.breakBlock') {
      return; // 布局测试不发写请求，忽略重试期间的迟到调用。
    }
    final result = switch (method) {
      'system.hello' => {
          'serverName': 'TapMC',
          'serverVersion': '0.2.0',
          'protocolVersion': '1.0',
          'worldWidth': 24,
          'worldHeight': 16,
        },
      'world.snapshot' => {
          'width': 24,
          'height': 16,
          'blocks': List<String>.filled(384, 'AIR'),
        },
      'system.mods' => const <dynamic>[],
      'player.join' => {
          'id': 'player-1',
          'pos': {'x': 12, 'y': 8},
        },
      _ => throw StateError('布局测试收到意外方法：$method'),
    };
    scheduleMicrotask(() {
      if (!_incoming.isClosed) {
        _incoming.add(jsonEncode({
          'jsonrpc': '2.0',
          'id': request['id'],
          'result': result,
        }));
      }
    });
  }

  @override
  Future<void> close() async {
    connected = false;
  }

  @override
  bool get isConnected => connected;
}

Future<GameSession> _pumpReadySession(WidgetTester tester) async {
  final transport = _LayoutTransport();
  final rpc = RpcClient(transport);
  final session = GameSession(GameRepository(rpc), rpc);
  addTearDown(() async {
    session.dispose();
    await rpc.dispose();
  });

  await tester.pumpWidget(MaterialApp(home: HomePage(session: session)));
  await tester.pumpAndSettle();
  expect(session.status, ConnectionStatus.ready);
  return session;
}

void main() {
  for (final size in <Size>[Size(375, 667), Size(667, 375)]) {
    final orientation = size.width < size.height ? '竖屏' : '横屏';

    testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} $orientation 无溢出且方向盘不遮挡网格',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpReadySession(tester);

      expect(tester.takeException(), isNull,
          reason: '布局过程中不应有 RenderFlex overflow 等异常');

      final grid = tester.getRect(find.byType(WorldGrid));
      final pad = tester.getRect(find.byType(DirectionPad));

      expect(grid.left, greaterThanOrEqualTo(0));
      expect(grid.right, lessThanOrEqualTo(size.width));
      expect(grid.top, greaterThanOrEqualTo(0));
      expect(grid.bottom, lessThanOrEqualTo(size.height));

      // 竖屏：控制区在世界下方；横屏：控制区退到世界右侧。二者都不压住地图。
      if (size.width < size.height) {
        expect(pad.top, greaterThanOrEqualTo(grid.bottom));
      } else {
        expect(pad.left, greaterThanOrEqualTo(grid.right));
      }
    });
  }
}
