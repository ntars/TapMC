import '../../domain/geometry.dart';
import '../../domain/models.dart';
import '../../domain/protocol.dart';
import 'rpc/rpc_client.dart';

/// 游戏仓储：把 RPC 方法封装成领域语义的调用。
///
/// 分层理由：如果让 UI 直接调 `rpc.call('world.placeBlock', params: {...})`，
/// 字符串方法名和 `Map` 参数会渗进每一个界面文件，改一次协议就要全局搜索替换。
/// 收在这一层后，协议变化只影响本文件。
class GameRepository {
  GameRepository(this._rpc);

  final RpcClient _rpc;

  /// 事件流，已解析成领域对象。
  Stream<WorldChange> get worldChanges => _rpc.events
      .where((event) => event.method == Methods.eventWorldChanged)
      .map((event) {
        final change = event.params['change'];
        return WorldChange.fromJson(
            change is Map<String, dynamic> ? change : const {});
      });

  /// 取服务端信息。
  Future<ServerInfo> hello() async {
    final result = await _rpc.call<Map<String, dynamic>>(Methods.systemHello);
    return ServerInfo.fromJson(result);
  }

  /// 取整张地图。
  Future<WorldSnapshot> snapshot() async {
    final result =
        await _rpc.call<Map<String, dynamic>>(Methods.worldSnapshot);
    return WorldSnapshot.fromJson(result);
  }

  /// 并列出生效的模组。
  Future<List<ModInfo>> mods() async {
    final result = await _rpc.call<List<dynamic>>(Methods.systemMods);
    return result
        .whereType<Map<String, dynamic>>()
        .map(ModInfo.fromJson)
        .toList(growable: false);
  }

  /// 加入世界。返回服务端分配的玩家状态。
  Future<PlayerState> join() async {
    final result = await _rpc.call<Map<String, dynamic>>(Methods.playerJoin);
    return PlayerState.fromJson(result);
  }

  /// 按方向移动一格。
  Future<PlayerState> move(MoveDirection direction) async {
    final result = await _rpc.call<Map<String, dynamic>>(
      Methods.playerMove,
      params: {'direction': direction.wireName},
    );
    return PlayerState.fromJson(result);
  }

  /// 放置方块。
  Future<WorldChange> placeBlock(int x, int y, String blockWireName) async {
    final result = await _rpc.call<Map<String, dynamic>>(
      Methods.worldPlaceBlock,
      params: {'x': x, 'y': y, 'block': blockWireName},
    );
    return WorldChange.fromJson(result);
  }

  /// 破坏方块。
  Future<WorldChange> breakBlock(int x, int y) async {
    final result = await _rpc.call<Map<String, dynamic>>(
      Methods.worldBreakBlock,
      params: {'x': x, 'y': y},
    );
    return WorldChange.fromJson(result);
  }
}
