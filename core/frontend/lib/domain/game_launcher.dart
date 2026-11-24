import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

enum LaunchStatus {
  idle,
  starting,
  running,
  stopping,
  stopped,
  failed,
}

class LaunchConfig {
  final String javaPath;
  final String jarPath;
  final int memoryMin;
  final int memoryMax;
  final List<String> jvmArgs;
  final List<String> gameArgs;

  LaunchConfig({
    required this.javaPath,
    required this.jarPath,
    this.memoryMin = 1024,
    this.memoryMax = 4096,
    this.jvmArgs = const [],
    this.gameArgs = const [],
  });

  List<String> toCommand() {
    return [
      javaPath,
      '-Xms${memoryMin}M',
      '-Xmx${memoryMax}M',
      ...jvmArgs,
      '-jar',
      jarPath,
      ...gameArgs,
    ];
  }
}

class GameLauncher with ChangeNotifier {
  final LaunchConfig config;
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;

  LaunchStatus _status = LaunchStatus.idle;
  String _output = '';
  int? _pid;

  LaunchStatus get status => _status;
  String get output => _output;
  int? get pid => _pid;

  GameLauncher(this.config);

  Future<void> launch() async {
    if (_status == LaunchStatus.running) throw StateError('游戏已在运行');

    try {
      _status = LaunchStatus.starting;
      notifyListeners();

      final cmd = config.toCommand();
      _process = await Process.start(cmd[0], cmd.sublist(1));
      _pid = _process!.pid;

      _stdoutSubscription?.cancel();
      _stderrSubscription?.cancel();

      _stdoutSubscription = _process!.stdout.listen((data) {
        _output += '${utf8.decode(data).trim()}\n';
        notifyListeners();
      });

      _stderrSubscription = _process!.stderr.listen((data) {
        _output += '[ERROR] ${utf8.decode(data).trim()}\n';
        notifyListeners();
      });

      _process!.exitCode.whenComplete(() {
        _status = LaunchStatus.stopped;
        notifyListeners();
      });

      _status = LaunchStatus.running;
      notifyListeners();
    } catch (e) {
      _status = LaunchStatus.failed;
      _output += '启动失败: $e\n';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_status != LaunchStatus.running && _status != LaunchStatus.starting) return;

    try {
      _status = LaunchStatus.stopping;
      notifyListeners();

      if (_process != null) {
        await _process!.kill();
      }
      await Future.delayed(const Duration(milliseconds: 500));

      _stdoutSubscription?.cancel();
      _stderrSubscription?.cancel();

      if (_status == LaunchStatus.stopping) {
        _status = LaunchStatus.stopped;
      }
      notifyListeners();
    } catch (e) {
      _status = LaunchStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  bool kill() {
    if (_process != null) {
      _process!.kill();
      return true;
    }
    return false;
  }
}
