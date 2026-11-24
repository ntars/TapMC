import 'package:flutter/material.dart';

/// 日志与诊断页面
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<String> logs = [];
  bool loading = true;
  String selectedLevel = 'All';
  
  final List<String> logLevels = ['All', 'Error', 'Warn', 'Info'];
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      loading = true;
      logs = [
        '[Info] 2026-11-23 21:00:00 启动 TapMC 游戏服务端...',
        '[Info] 2026-11-23 21:00:01 正在加载世界存档...',
        '[Info] 2026-11-23 21:00:02 世界加载完成，大小: 512x512',
        '[Info] 2026-11-23 21:00:03 启动 WebSocket 服务端，监听端口 8777...',
        '[Info] 2026-11-23 21:00:04 WebSocket 服务启动成功',
        '[Info] 2026-11-23 21:05:12 客户端连接: 127.0.0.1:54321',
        '[Info] 2026-11-23 21:05:13 处理 hello 请求',
        '[Info] 2026-11-23 21:05:14 处理 snapshot 请求',
        '[Info] 2026-11-23 21:05:15 处理 join 请求',
        '[Error] 2026-11-23 21:10:30 连接超时，客户端断开',
        '[Warn] 2026-11-23 21:10:35 自动重连尝试 1/3',
        '[Info] 2026-11-23 21:10:40 自动重连成功',
      ];
    });
    
    // 模拟实时日志更新
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        logs.add('[Info] 2026-11-23 21:15:00 定时存档触发...');
        logs.add('[Info] 2026-11-23 21:15:01 存档保存完成');
      });
    }
    
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  List<String> get filteredLogs {
    if (selectedLevel == 'All') return logs;
    return logs.where((log) => log.contains('[${selectedLevel}]')).toList();
  }

  Color levelColor(String level) {
    switch (level) {
      case 'Error':
        return Colors.red;
      case 'Warn':
        return Colors.orange;
      case 'Info':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Future<void> _exportLogs() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在导出日志...')),
    );
    
    // 模拟导出
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日志已导出到 ./logs/export.txt')),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => logs = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志与诊断'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: logLevels.map((level) {
                return Expanded(
                  child: FilterChip(
                    label: Text(level),
                    selected: selectedLevel == level,
                    onSelected: (selected) {
                      setState(() => selectedLevel = level);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filteredLogs.isEmpty
                    ? const Center(child: Text('暂无日志'))
                    : ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          String? level;
                          if (log.contains('[Error]')) {
                            level = 'Error';
                          } else if (log.contains('[Warn]')) {
                            level = 'Warn';
                          } else if (log.contains('[Info]')) {
                            level = 'Info';
                          }
                          return ListTile(
                            leading: level != null
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: levelColor(level),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            title: Text(
                              log,
                              style: TextStyle(color: levelColor(level ?? '')),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
