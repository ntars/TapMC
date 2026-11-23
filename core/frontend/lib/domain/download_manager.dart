import 'dart:async';
import 'package:flutter/foundation.dart';

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
}

class DownloadTask {
  final String id;
  final String url;
  final String filename;
  final int totalSize;
  int downloadedSize;
  DownloadStatus status;
  double speed;
  DateTime? startTime;
  DateTime? endTime;
  String? errorMessage;

  DownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    this.totalSize = 0,
    this.downloadedSize = 0,
    required this.status,
    this.speed = 0.0,
    this.startTime,
    this.endTime,
    this.errorMessage,
  });

  double get progress => totalSize > 0 ? downloadedSize / totalSize : 0.0;

  DownloadTask copyWith({
    String? id,
    String? url,
    String? filename,
    int? totalSize,
    int? downloadedSize,
    DownloadStatus? status,
    double? speed,
    DateTime? startTime,
    DateTime? endTime,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      totalSize: totalSize ?? this.totalSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadManager extends ChangeNotifier {
  final List<DownloadTask> _tasks = [];
  int _maxConcurrentDownloads = 3;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  int get activeCount => _tasks.where((t) => t.status == DownloadStatus.downloading).length;
  int get pendingCount => _tasks.where((t) => t.status == DownloadStatus.pending).length;
  int get completedCount => _tasks.where((t) => t.status == DownloadStatus.completed).length;
  int get failedCount => _tasks.where((t) => t.status == DownloadStatus.failed).length;

  void initialize({int maxConcurrent = 3}) {
    _maxConcurrentDownloads = maxConcurrent;
    notifyListeners();
  }

  DownloadTask add(String url, String filename, {int? totalSize}) {
    final task = DownloadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      filename: filename,
      totalSize: totalSize ?? 0,
      downloadedSize: 0,
      status: DownloadStatus.pending,
    );
    
    _tasks.add(task);
    notifyListeners();
    _startNextPendingTask();
    
    return task;
  }

  void cancel(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    
    if (task.status == DownloadStatus.downloading || 
        task.status == DownloadStatus.pending) {
      _stopTask(task);
      
      task.status = DownloadStatus.failed;
      task.errorMessage = '下载已取消';
      notifyListeners();
    }
  }

  void pause(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    
    if (task.status == DownloadStatus.downloading) {
      _stopTask(task);
      task.status = DownloadStatus.paused;
      notifyListeners();
    }
  }

  void resume(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    
    if (task.status == DownloadStatus.paused || 
        task.status == DownloadStatus.failed) {
      task.errorMessage = null;
      
      if (task.status == DownloadStatus.paused) {
        task.status = DownloadStatus.pending;
        _startNextPendingTask();
      } else if (task.downloadedSize > 0) {
        task.status = DownloadStatus.pending;
        _startNextPendingTask();
      } else {
        task.downloadedSize = 0;
        task.status = DownloadStatus.pending;
        _startNextPendingTask();
      }
    }
  }

  void remove(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  void clear() {
    for (final task in _tasks.where((t) => t.status == DownloadStatus.downloading)) {
      _stopTask(task);
    }
    
    _tasks.clear();
    notifyListeners();
  }

  void _startNextPendingTask() {
    if (activeCount >= _maxConcurrentDownloads) return;
    
    final pendingTask = _tasks.firstWhere(
      (t) => t.status == DownloadStatus.pending,
      orElse: () => throw StateError('No pending task'),
    );
    
    _startDownload(pendingTask);
  }

  void _startDownload(DownloadTask task) {
    if (task.status != DownloadStatus.pending && 
        task.status != DownloadStatus.paused) return;
    
    task.status = DownloadStatus.downloading;
    task.startTime = DateTime.now();
    notifyListeners();

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (task.status != DownloadStatus.downloading) {
        timer.cancel();
        return;
      }

      final speed = 10240 + (DateTime.now().millisecondsSinceEpoch % 490) * 1024;
      task.speed = speed.toDouble();

      const chunkSize = 1024 * 1024;
      task.downloadedSize += chunkSize;

      if (task.totalSize > 0 && task.downloadedSize >= task.totalSize) {
        task.downloadedSize = task.totalSize;
        task.status = DownloadStatus.completed;
        task.endTime = DateTime.now();
        timer.cancel();
      }

      notifyListeners();
    });
  }

  void _stopTask(DownloadTask task) {
  }

  void setMaxConcurrent(int count) {
    _maxConcurrentDownloads = count;
    notifyListeners();
    _startNextPendingTask();
  }

  Map<String, dynamic> getStats() {
    final totalSize = _tasks.fold<int>(0, (sum, t) => sum + t.totalSize);
    final downloadedSize = _tasks.fold<int>(0, (sum, t) => sum + t.downloadedSize);
    
    return {
      'total': _tasks.length,
      'active': activeCount,
      'pending': pendingCount,
      'completed': completedCount,
      'failed': failedCount,
      'totalSize': totalSize,
      'downloadedSize': downloadedSize,
    };
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
