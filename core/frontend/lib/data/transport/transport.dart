/// 传输层抽象。RPC 客户端只依赖这个接口，不直接依赖 WebSocket。
///
/// 这样做的两个实际好处：
/// 1. 测试可以塞一个假实现，不必起真实端口；
/// 2. 将来若要支持「进程内直连」（桌面端把 Java 跑在同进程）或
///    「标准输入管道」，只需换一个实现，上层一行不动。
abstract interface class Transport {
  /// 建立连接。失败抛 [TransportException]。
  Future<void> connect();

  /// 发出的文本帧流。
  Stream<String> get incoming;

  /// 发一段文本。未连接时抛 [TransportException]。
  void send(String text);

  /// 主动断开。重复调用安全。
  Future<void> close();

  /// 是否仍处于连接状态。
  bool get isConnected;
}

/// 传输层错误。[message] 是给人看的中文说明，包含「发生了什么 + 下一步」。
class TransportException implements Exception {
  const TransportException(this.message);

  final String message;

  @override
  String toString() => message;
}
