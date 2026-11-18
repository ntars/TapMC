import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tapmc/data/game_repository.dart';
import 'package:tapmc/data/rpc/rpc_client.dart';
import 'package:tapmc/data/transport/web_socket_transport.dart';
import 'package:tapmc/domain/block_type.dart';
import 'package:tapmc/domain/geometry.dart';
import 'package:tapmc/domain/models.dart';

/// 端到端契约测试：连真实后端，验证「两端的字段名确实一致」。
///
/// 为什么必须有这一层：Dart 与 Java 各自有一套模型类，字段名写错时
/// 单元测试双双通过，只有真实对撞才会暴露。这个文件跑不通就说明协议裂了。
///
/// 默认跳过。要跑需要先启动后端：
/// ```
/// cd backend && ./gradlew :server:run
/// cd frontend && TAPMC_E2E=1 flutter test test/e2e_contract_test.dart
/// ```
///
/// 用环境变量而不是 `--dart-define`：`flutter test` 下 dart-define 与 const 求值
/// 的配合容易踩到「值没传进去却静默跳过」，环境变量在测试进程里一定可见。
final bool _runE2e = Platform.environment['TAPMC_E2E'] == '1';

/// 后端地址。与 `Main.DEFAULT_PORT` 保持一致。
const String _endpoint = 'ws://127.0.0.1:8777';

/// 把某一格恢复成期望的方块。
///
/// 这些用例共享同一个长期运行的后端进程，而世界状态不会随连接断开而重置。
/// 破坏性用例必须把地形放回原位，否则下一次跑（或同批次后面的用例）会因为
/// 「地形变了」而失败，那种失败会伪装成协议问题，极难排查。
Future<void> _restoreBlock(
    GameRepository repo, int x, int y, BlockType want) async {
  final snapshot = await repo.snapshot();
  final current = snapshot.at(x, y);
  if (current == want) return;
  // placeBlock 只接受空气格，所以已有方块必须先挖掉。
  if (current != BlockType.air) {
    await repo.breakBlock(x, y);
  }
  if (want != BlockType.air) {
    await repo.placeBlock(x, y, want.wireName);
  }
}

void main() {
  group('与真实后端的协议契约', () {
    late RpcClient rpc;
    late GameRepository repo;

    // 契约测试假设世界是「刚启动」的状态：下面的用例会断言围栏的位置与材质。
    // 如果后端已经被人手动玩过、或上一轮测试没恢复干净，这里直接给出可操作的
    // 提示，而不是让那几条断言以「协议坏了」的样子红掉。
    setUpAll(() async {
      if (!_runE2e) return;
      final probe = RpcClient(WebSocketTransport(Uri.parse(_endpoint)));
      await probe.connect();
      final snapshot = await GameRepository(probe).snapshot();
      await probe.dispose();

      final intact = snapshot.at(0, 0) == BlockType.wood &&
          snapshot.at(snapshot.width - 1, 0) == BlockType.wood &&
          snapshot.at(0, snapshot.height - 1) == BlockType.wood;
      if (!intact) {
        fail('后端世界已被改动，契约测试需要一个干净的世界。'
            '请重启后端后再跑：backend 目录执行 ./gradlew :server:run');
      }
    });

    setUp(() async {
      rpc = RpcClient(
        WebSocketTransport(Uri.parse(_endpoint)),
      );
      repo = GameRepository(rpc);
      await rpc.connect();
    });

    tearDown(() async {
      await rpc.dispose();
    });

    test('hello 字段可被解析', () async {
      final info = await repo.hello();
      expect(info.serverName, isNotEmpty);
      expect(info.protocolVersion, isNotEmpty);
      expect(info.worldWidth, greaterThan(0));
      expect(info.worldHeight, greaterThan(0));
    });

    test('snapshot 的格子数与尺寸匹配，且方块名可识别', () async {
      final snapshot = await repo.snapshot();
      expect(snapshot.blocks.length, snapshot.width * snapshot.height);

      // 生成的地形必然含树干（围栏）与泥土（地面）。
      expect(snapshot.blocks, contains(BlockType.wood));
      expect(snapshot.blocks, contains(BlockType.dirt));

      // 越界读安全。
      expect(snapshot.at(-1, -1), BlockType.air);
    });

    test('坐标原点在左上：左上与右上都是围栏', () async {
      final snapshot = await repo.snapshot();
      expect(snapshot.at(0, 0), BlockType.wood);
      expect(snapshot.at(snapshot.width - 1, 0), BlockType.wood);
    });

    test('join 返回玩家身份与合法出生点', () async {
      final player = await repo.join();
      expect(player.id, isNotEmpty);

      final snapshot = await repo.snapshot();
      expect(player.pos.x, inInclusiveRange(0, snapshot.width - 1));
      expect(player.pos.y, inInclusiveRange(0, snapshot.height - 1));
      expect(snapshot.at(player.pos.x, player.pos.y).walkable, isTrue,
          reason: '出生点必须可站立');
    });

    test('移动后位置按方向变化', () async {
      await repo.join();
      final snapshot = await repo.snapshot();

      // 找一个确实能走的方向，避免落在围栏边上导致测试不稳。
      MoveDirection? workable;
      PlayerState? before;
      for (final dir in MoveDirection.values) {
        final from = (await repo.hello()).worldWidth; // 仅用于消耗一次调用
        expect(from, greaterThan(0));
        before = await repo.join(); // 重新 join 会复用同一玩家（幂等）
        final target = before.pos.offset(dir);
        if (snapshot.at(target.x, target.y).walkable &&
            target.x >= 0 &&
            target.x < snapshot.width &&
            target.y >= 0 &&
            target.y < snapshot.height) {
          workable = dir;
          break;
        }
      }

      expect(workable, isNotNull, reason: '出生点周围至少应有一个可走方向');
      final after = await repo.move(workable!);
      expect(after.pos, before!.pos.offset(workable));
    });

    test('破坏再放置走通完整回合', () async {
      await repo.join();

      // (0,0) 是外围围栏，材质为 WOOD。测完要还原成 WOOD，不能留成空气——
      // 否则同批次里断言「(0,0) 是围栏」的用例会连带失败。
      var target = const BlockPos(0, 0);
      final broken = await repo.breakBlock(target.x, target.y);
      expect(broken.block, BlockType.air);

      final placed =
          await repo.placeBlock(target.x, target.y, BlockType.stone.wireName);
      expect(placed.block, BlockType.stone);

      // stone 已经在格子里，要先挖掉才能放回 wood。
      await repo.breakBlock(target.x, target.y);
      await repo.placeBlock(target.x, target.y, BlockType.wood.wireName);
    });

    test('越界请求被拒且错误码为 outOfBounds', () async {
      await expectLater(
        repo.placeBlock(9999, 9999, BlockType.stone.wireName),
        throwsA(isA<RpcException>()
            .having((e) => e.code, 'code', -32002)),
      );
    });

    test('事件流能收到自己触发的变化', () async {
      await repo.join();

      final events = <WorldChange>[];
      final sub = repo.worldChanges.listen(events.add);

      await repo.breakBlock(1, 0);
      // 等事件到达。广播与响应是两条独立通道，响应先到是正常的。
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(events, isNotEmpty, reason: '破坏方块应触发 event.worldChanged');
      expect(events.first.pos, const BlockPos(1, 0));

      await sub.cancel();
      // 恢复围栏。(1,0) 此时已是空气，直接放回 WOOD。
      await _restoreBlock(repo, 1, 0, BlockType.wood);
    });
  }, skip: _runE2e ? false : '需要真实后端：设置 TAPMC_E2E=1 后重跑');
}
