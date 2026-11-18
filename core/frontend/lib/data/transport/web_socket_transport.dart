import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'transport.dart';

/// 基于 WebSocket 的传输实现。
///
/// 用 `web_socket_channel` 而非 `dart:io` 的 `WebSocket`：Web 端没有 `dart:io`，
/// 而 `web_socket_channel` 在 Web 走浏览器的原生 WebSocket、在移动与桌面走 IO 实现，
/// 是唯一能一套代码覆盖六端的选择。
///
/// **平台差异**：Android 模拟器访问宿主机要用 `10.0.2.2` 而不是 `127.0.0.1`，
/// 这个判断放在 [defaultEndpointFor] 里，避免每个调用点各写一遍。
class WebSocketTransport implements Transport {
  WebSocketTransport(this.uri);

  final Uri uri;

  WebSocketChannel? _channel;
  StreamController<String>? _controller;
  StreamSubscription<dynamic>? _subscription;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get incoming {
    final controller = _controller;
    if (controller == null) {
      throw const TransportException('传输层尚未初始化，请先调用 connect()');
    }
    return controller.stream;
  }

  @override
  Future<void> connect() async {
    if (_connected) return;

    final controller = StreamController<String>.broadcast();
    _controller = controller;

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // ready 会等到握手真正完成。不 await 的话连接失败要等到第一次
      // 读流时才暴露，错误位置会离真正原因很远。
      await channel.ready;

      _subscription = channel.stream.listen(
        (message) {
          if (message is String) {
            controller.add(message);
          }
          // 二进制帧当前协议不用，静默忽略而不是报错——
          // 将来加二进制通道时不会因为这里抛异常而断连。
        },
        onError: (Object error) {
          controller.addError(TransportException(_describe(error)));
          _connected = false;
        },
        onDone: () {
          _connected = false;
          controller.close();
        },
        cancelOnError: false,
      );

      _connected = true;
    } on Object catch (error) {
      _connected = false;
      await _subscription?.cancel();
      _subscription = null;
      _channel = null;
      if (!controller.isClosed) {
        await controller.close();
      }
      _controller = null;
      if (error is TransportException) rethrow;
      throw TransportException(_describe(error));
    }
  }

  @override
  void send(String text) {
    final channel = _channel;
    if (!_connected || channel == null) {
      throw const TransportException('连接已断开，无法发送请求');
    }
    channel.sink.add(text);
  }

  @override
  Future<void> close() async {
    if (!_connected && _channel == null) return;
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  /// 把底层异常翻成能给人看的话。不写「连接失败」，写出原因与去处。
  static String _describe(Object error) {
    final text = error.toString();
    if (text.contains('Connection refused') || text.contains('Failed to connect')) {
      return '无法连接到游戏服务端：连接被拒绝。请确认后端已启动'
          '（backend 目录执行 ./gradlew :server:run），且端口与地址正确。';
    }
    if (text.contains('timed out') || text.contains('TimeoutException')) {
      return '连接游戏服务端超时。请确认地址可达，若在 Android 模拟器中请用 10.0.2.2。';
    }
    return '连接游戏服务端时出错：$text';
  }
}

/// 按运行平台给出默认的后端地址。
///
/// - Android **模拟器**把宿主机映射为 `10.0.2.2`，直接连 `127.0.0.1` 会连到
///   模拟器自身，因此这里在 Android 上默认用 `10.0.2.2`；
/// - 安卓**真机**不在模拟器网络里，`10.0.2.2` 也无效，必须通过
///   `--dart-define=TAPMC_SERVER_HOST=<开发机局域网 IP>` 显式指定；
/// - iOS 模拟器与桌面端共享宿主网络，用 `127.0.0.1`；
/// - Web 端由浏览器发起，同样回落到 `127.0.0.1`（同机开发时成立）。
///
/// 用 [defaultTargetPlatform] 而非 `Platform.isAndroid`：Web 端没有 `dart:io`，
/// 而 [defaultTargetPlatform] 在 Web 上也能用。
Uri defaultEndpointFor({
  String host = '',
  int port = 8777,
}) {
  final resolvedHost = host.isNotEmpty ? host : _defaultHost();
  return Uri(scheme: 'ws', host: resolvedHost, port: port);
}

/// 未显式指定主机时的兜底地址。
String _defaultHost() {
  if (kIsWeb) return '127.0.0.1';
  // Android 模拟器：宿主机别名。真机需用 dart-define 覆盖。
  if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return '127.0.0.1';
}
