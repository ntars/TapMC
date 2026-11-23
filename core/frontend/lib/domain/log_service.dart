import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

enum LogType {
  info,
  warning,
  error,
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogType type;

  LogEntry({
    required this.message,
    required this.timestamp,
    required this.type,
  });

  factory LogEntry.info(String message) {
    return LogEntry(
      message: message,
      timestamp: DateTime.now(),
      type: LogType.info,
    );
  }

  factory LogEntry.warning(String message) {
    return LogEntry(
      message: '[WARNING] $message',
      timestamp: DateTime.now(),
      type: LogType.warning,
    );
  }

  factory LogEntry.error(String message) {
    return LogEntry(
      message: '[ERROR] $message',
      timestamp: DateTime.now(),
      type: LogType.error,
    );
  }
}

class LogService extends ChangeNotifier {
  final List<LogEntry> _entries = [];
  bool _isConnected = false;
  late Process _process;
  StreamSubscription<dynamic>? _stdoutSubscription;
  StreamSubscription<dynamic>? _stderrSubscription;

  List<LogEntry> get entries => _entries;
  bool get isConnected => _isConnected;

  Future<void> connect(String jarPath) async {
    if (_isConnected) throw StateError('已连接');

    try {
      _process = await Process.start(
        'java',
        ['-jar', jarPath, '--port', '8777'],
      );

      _stdoutSubscription = _process.stdout.listen((data) {
        final line = String.fromCharCodes(data).trim();
        if (line.isNotEmpty) {
          _entries.add(LogEntry.info(line));
          notifyListeners();
        }
      });

      _stderrSubscription = _process.stderr.listen((data) {
        final line = String.fromCharCodes(data).trim();
        if (line.isNotEmpty) {
          _entries.add(LogEntry.error(line));
          notifyListeners();
        }
      });

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _entries.add(LogEntry.error('连接失败: $e'));
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      _stdoutSubscription?.cancel();
      _stderrSubscription?.cancel();
      await _process.kill();
    } finally {
      _isConnected = false;
      notifyListeners();
    }
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  List<LogEntry> getRecent(int count) {
    if (count >= _entries.length) return _entries;
    return _entries.sublist(_entries.length - count);
  }

  void dispose() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    super.dispose();
  }
}
