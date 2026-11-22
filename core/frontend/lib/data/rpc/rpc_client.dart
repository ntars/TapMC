import 'dart:async';
import 'dart:convert';

import '../transport/transport.dart';
import '../../domain/protocol.dart';

/// 一次 RPC 调用的失败。[code] 是 JSON-RPC 错误码，[message] 是后端给的中文说明。
class RpcException implements Exception {
  const RpcException(this.code, this.message, {this.data});

  final int code;
  final String message;
  final Object? data;

  /// 是否是「被模组拦下」。UI 可据此换一种措辞，而不是一律报错。
  bool get isCancelledByMod => code == JsonRpc.cancelledByMod;

  @override
  String toString() => message;
}

/// 服务端主动推的事件。
class RpcEvent {
  const RpcEvent(this.method, this.params);

  final String method;
  final Map<String, dynamic> params;
}

/// JSON-RPC 2.0 客户端。
///
/// 职责边界很清楚：把「方法名 + 参数」变成一次 Future，把「服务端推来的事件」
/// 变成一条流。它不解析业务字段——那是 [GameRepository] 的事。
///
/// **超时**：每个请求默认 10 秒。没有超时的话，一个丢失的响应会让调用方的
/// Future 永远悬挂，UI 上表现为「按钮转圈转到天荒地老」。
class RpcClient {
  RpcClient(this._transport);

  final Transport _transport;
  final Map<String, Completer<dynamic>> _pending = {};
  final StreamController<RpcEvent> _events =
      StreamController<RpcEvent>.broadcast();
  // 连接断开单独成流：事件流是「服务端推来的报文」，而断连是传输层状态变化，
  // 混在 events 里会让上层分不清「业务事件」和「连接没了」。
  final StreamController<Object> _disconnections =
      StreamController<Object>.broadcast();

  int _nextId = 0;
  StreamSubscription<String>? _subscription;
  bool _disposed = false;

  /// 请求超时时长。
  static const Duration requestTimeout = Duration(seconds: 10);

  /// 服务端主动推的事件流。
  Stream<RpcEvent> get events => _events.stream;

  /// 连接意外断开时发出一次。主动 dispose() 不发。
  Stream<Object> get disconnections => _disconnections.stream;

  /// 建立连接并开始接收。
  Future<void> connect() async {
    if (_disposed) {
      throw const TransportException('客户端已释放，无法重连');
    }
    await _transport.connect();
    _subscription = _transport.incoming.listen(
      _onMessage,
      onError: (Object error) {
        _failAllPending(TransportException(error.toString()));
        if (!_events.isClosed) {
          _events.addError(error);
        }
        _notifyDisconnected(error);
      },
      onDone: () {
        _failAllPending(
            const TransportException('与服务端的连接已断开，请检查后端是否仍在运行'));
        _notifyDisconnected(
            const TransportException('与服务端的连接已断开，请检查后端是否仍在运行'));
      },
    );
  }

  /// 重连前把旧传输收干净，再走一次完整握手。
  /// 上层会重新执行 hello → snapshot → join，因此世界状态与玩家身份都会恢复。
  Future<void> reconnect() async {
    await _transport.close();
    await _subscription?.cancel();
    _subscription = null;
    await connect();
  }

  void _notifyDisconnected(Object error) {
    if (!_disconnections.isClosed && !_disposed) {
      _disconnections.add(error);
    }
  }

  /// 调用一个方法。失败抛 [RpcException]（业务错误）或 [TransportException]（连接问题）。
  Future<T> call<T>(
    String method, {
    Map<String, dynamic>? params,
    Duration? timeout,
  }) async {
    if (_disposed) {
      throw const TransportException('客户端已释放');
    }

    final id = _nextId++;
    final key = id.toString();
    final completer = Completer<dynamic>();
    _pending[key] = completer;

    // 先构造必填字段，再按需补 params。
    // 不用 `?'params': params` 这种空安全元素语法：它要求 Dart 3.9+ 的语言版本，
    // 而本项目为覆盖鸿蒙把 SDK 下限压到了 3.8。
    final payload = <String, dynamic>{
      'jsonrpc': JsonRpc.version,
      'id': key,
      'method': method,
    };
    if (params != null) {
      payload['params'] = params;
    }
    try {
      _transport.send(jsonEncode(payload));
    } on Object catch (error) {
      _pending.remove(key);
      throw error is TransportException
          ? error
          : TransportException('发送请求失败：$error');
    }

    try {
      final result = await completer.future
          .timeout(timeout ?? requestTimeout, onTimeout: () {
        _pending.remove(key);
        throw TimeoutException(
          '调用 $method 超时（${(timeout ?? requestTimeout).inSeconds} 秒未响应）',
        );
      });
      return result as T;
    } finally {
      _pending.remove(key);
    }
  }

  /// 处理一条入站报文。区分「响应」与「事件」靠有没有 `id`。
  void _onMessage(String raw) {
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        // 不是对象就不是合法报文，丢弃。不给前端抛异常——
        // 一条坏报文不该让整个连接崩掉。
        return;
      }
      envelope = decoded;
    } on FormatException {
      return;
    }

    final id = envelope['id'];

    // 有 id：是响应，交给对应的等待者。
    if (id != null) {
      final completer = _pending.remove(id.toString());
      if (completer == null) {
        // 超时后迟到的响应，没有等待者，丢弃即可。
        return;
      }
      final error = envelope['error'];
      if (error is Map<String, dynamic>) {
        completer.completeError(RpcException(
          (error['code'] as num?)?.toInt() ?? JsonRpc.internalError,
          error['message'] as String? ?? '未知错误',
          data: error['data'],
        ));
        return;
      }
      completer.complete(envelope['result']);
      return;
    }

    // 无 id 但有 method：是事件。
    final method = envelope['method'];
    if (method is String) {
      final params = envelope['params'];
      if (!_events.isClosed) {
        _events.add(RpcEvent(
          method,
          params is Map<String, dynamic> ? params : const {},
        ));
      }
    }
  }

  /// 连接断开时让所有等待者立刻失败，而不是等到各自超时。
  void _failAllPending(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  /// 断开并释放。重复调用安全。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    _failAllPending(const TransportException('客户端已关闭'));
    await _transport.close();
    await _events.close();
    await _disconnections.close();
  }
}
