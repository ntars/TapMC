import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/game_repository.dart';
import '../data/rpc/rpc_client.dart';
import '../data/transport/transport.dart';
import '../domain/block_type.dart';
import '../domain/geometry.dart';
import '../domain/models.dart';

/// 连接状态。UI 据此决定画什么：加载态、错误态、还是游戏界面。
enum ConnectionStatus { idle, connecting, ready, reconnecting, failed }

/// 游戏会话状态。用 [ChangeNotifier] 而非引入状态管理库——
/// 骨架阶段只有一个页面，多引一个依赖不值。
///
/// **单向数据流**：UI 调本类的方法，本类调仓储，仓储回来的数据改自己的字段，
/// 再 [notifyListeners]。UI 里不出现任何网络调用。
class GameSession extends ChangeNotifier {
  /// 用位置参数而非命名参数：Dart 不允许命名参数与私有字段同名，
  /// 强行命名就得写成 `repository: repository` 再赋给 `_repository`，不如直接传。
  GameSession(this._repository, this._rpc);

  final GameRepository _repository;
  final RpcClient _rpc;
  StreamSubscription<WorldChange>? _subscription;
  StreamSubscription<Object>? _disconnectSubscription;

  ConnectionStatus _status = ConnectionStatus.idle;
  String _errorMessage = '';
  int _reconnectAttempt = 0;
  ServerInfo? _serverInfo;
  WorldSnapshot _world = WorldSnapshot.empty;
  PlayerState? _player;
  List<ModInfo> _mods = const [];
  String _lastAction = '';
  BlockType _selectedBlock = BlockType.stone;

  ConnectionStatus get status => _status;
  String get errorMessage => _errorMessage;
  int get reconnectAttempt => _reconnectAttempt;
  ServerInfo? get serverInfo => _serverInfo;
  WorldSnapshot get world => _world;
  PlayerState? get player => _player;
  List<ModInfo> get mods => _mods;
  String get lastAction => _lastAction;
  BlockType get selectedBlock => _selectedBlock;

  /// 是否已进入世界。没进入时移动与方块操作都会被后端拒绝，UI 应禁用入口。
  bool get isJoined => _player != null;

  /// 自动重连是否在退避等待中。UI 用它显示「N 秒后重试」。
  bool get isReconnectScheduled => _reconnectTimer?.isActive ?? false;

  Timer? _reconnectTimer;

  /// 连接断开后的回调。UI 只需订阅状态变化，所有重建逻辑都在这里。
  void _handleDisconnect(Object error) {
    if (_status == ConnectionStatus.failed || _status == ConnectionStatus.idle) {
      return;
    }
    if (_reconnectAttempt >= 3) {
      _status = ConnectionStatus.failed;
      _errorMessage = '连续 3 次自动重连失败：$error。请检查后端后点「重试」。';
      notifyListeners();
      return;
    }

    _reconnectAttempt++;
    _status = ConnectionStatus.reconnecting;
    _errorMessage = error.toString();
    // 500ms / 1s / 2s：短退避避免后端重启时把请求打满，也不让用户等太久。
    final delay = Duration(milliseconds: 500 * (1 << (_reconnectAttempt - 1)));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(connect(isReconnect: true));
    });
    notifyListeners();
  }

  /// 选择要放置的方块类型。
  void selectBlock(BlockType block) {
    if (_selectedBlock == block) return;
    _selectedBlock = block;
    notifyListeners();
  }

  /// 连接后端并完成首屏加载（hello → snapshot → mods → join）。
  ///
  /// 四步串行而不是并行：snapshot 依赖 hello 拿到的尺寸做校验，
  /// join 需要地图已就绪才能算出合法出生点。
  Future<void> connect({bool isReconnect = false}) async {
    if (_status == ConnectionStatus.connecting) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (!isReconnect) {
      _reconnectAttempt = 0;
    }

    _status = ConnectionStatus.connecting;
    _errorMessage = '';
    notifyListeners();

    try {
      await _rpc.reconnect();

      _serverInfo = await _repository.hello();
      _world = await _repository.snapshot();
      _mods = await _repository.mods();
      _player = await _repository.join();

      // 先订阅事件再置为 ready，避免「已连上但漏掉第一条广播」。
      _subscription ??= _repository.worldChanges.listen(_onWorldChange);
      _disconnectSubscription ??=
          _rpc.disconnections.listen(_handleDisconnect);

      _status = ConnectionStatus.ready;
      _reconnectAttempt = 0;
      _lastAction = '已连接 ${_serverInfo?.serverName ?? ''}，'
          '世界 ${_world.width}×${_world.height}'
          '${isReconnect ? '（已自动重连并恢复世界）' : ''}';
    } on RpcException catch (error) {
      _status = ConnectionStatus.failed;
      _errorMessage = error.message;
    } on TransportException catch (error) {
      _status = ConnectionStatus.failed;
      _errorMessage = error.message;
    } on TimeoutException catch (error) {
      _status = ConnectionStatus.failed;
      _errorMessage = error.message ?? '请求超时';
    } on Object catch (error) {
      _status = ConnectionStatus.failed;
      _errorMessage = '连接时发生未预期的错误：$error';
    } finally {
      notifyListeners();
    }
  }

  /// 移动一步。
  Future<void> move(MoveDirection direction) async {
    if (_status != ConnectionStatus.ready || !isJoined) return;
    try {
      _player = await _repository.move(direction);
      _lastAction = '向${_directionLabel(direction)}移动一格';
    } on RpcException catch (error) {
      _lastAction = error.message;
    } on TransportException catch (error) {
      _lastAction = error.message;
      _status = ConnectionStatus.failed;
    } on TimeoutException {
      _lastAction = '移动请求超时，请重试';
    }
    notifyListeners();
  }

  /// 在指定格放置当前选中的方块。
  Future<void> placeAt(BlockPos pos) async {
    if (_status != ConnectionStatus.ready) return;
    try {
      final change = await _repository.placeBlock(
          pos.x, pos.y, _selectedBlock.wireName);
      _world = _world.withBlock(change.pos, change.block);
      _lastAction = '在 ${change.pos} 放置了 ${_selectedBlock.wireName}';
    } on RpcException catch (error) {
      _lastAction = error.message;
    } on TransportException catch (error) {
      _lastAction = error.message;
      _status = ConnectionStatus.failed;
    } on TimeoutException {
      _lastAction = '放置请求超时，请重试';
    }
    notifyListeners();
  }

  /// 破坏指定格的方块。
  Future<void> breakAt(BlockPos pos) async {
    if (_status != ConnectionStatus.ready) return;
    try {
      final change = await _repository.breakBlock(pos.x, pos.y);
      _world = _world.withBlock(change.pos, change.block);
      _lastAction = '破坏了 ${change.pos} 的方块';
    } on RpcException catch (error) {
      _lastAction = error.message;
    } on TransportException catch (error) {
      _lastAction = error.message;
      _status = ConnectionStatus.failed;
    } on TimeoutException {
      _lastAction = '破坏请求超时，请重试';
    }
    notifyListeners();
  }

  /// 收到服务端广播时更新本地世界。
  void _onWorldChange(WorldChange change) {
    _world = _world.withBlock(change.pos, change.block);
    // 广播可能是别的玩家触发的，此时不该覆盖本地的 lastAction 提示。
    notifyListeners();
  }

  static String _directionLabel(MoveDirection direction) => switch (direction) {
        MoveDirection.north => '北',
        MoveDirection.south => '南',
        MoveDirection.west => '西',
        MoveDirection.east => '东',
      };

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _disconnectSubscription?.cancel();
    _disconnectSubscription = null;
    super.dispose();
  }
}
