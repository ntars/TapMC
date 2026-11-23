import 'package:flutter/material.dart';

/// 下载与更新页面
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  List<DownloadItem> downloads = [
    DownloadItem(
      id: '1',
      name: 'Modrinth API 集成模块 v1.0',
      progress: 75,
      status: DownloadStatus.downloading,
    ),
    DownloadItem(
      id: '2',
      name: 'CurseForge 模组包 - 100MB',
      progress: 45,
      status: DownloadStatus.downloading,
    ),
    DownloadItem(
      id: '3',
      name: '实例模板 - survival-pack.zip',
      progress: 100,
      status: DownloadStatus.completed,
    ),
  ];

  Future<void> _addDownload() async {
    final nameController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加下载任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '下载链接'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop(nameController.text);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    
    if (mounted) {
      setState(() {
        downloads.add(DownloadItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '新下载任务',
          progress: 0,
          status: DownloadStatus.pending,
        ));
      });
    }
  }

  void _cancelDownload(DownloadItem item) {
    setState(() {
      downloads = downloads.where((d) => d.id != item.id).toList();
    });
  }

  void _retryDownload(DownloadItem item) {
    setState(() {
      final index = downloads.indexWhere((d) => d.id == item.id);
      if (index >= 0) {
        downloads[index] = DownloadItem(
          id: item.id,
          name: item.name,
          progress: 0,
          status: DownloadStatus.pending,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载与更新'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addDownload,
          ),
        ],
      ),
      body: downloads.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, size: 64),
                const SizedBox(height: 16),
                Text('暂无下载任务'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _addDownload,
                  icon: const Icon(Icons.add),
                  label: const Text('添加下载任务'),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final item = downloads[index];
                return DownloadItemCard(
                  item: item,
                  onCancel: () => _cancelDownload(item),
                  onRetry: () => _retryDownload(item),
                );
              },
            ),
    );
  }
}

/// 下载项目类
class DownloadItem {
  final String id;
  final String name;
  int progress;
  DownloadStatus status;

  DownloadItem({
    required this.id,
    required this.name,
    required this.progress,
    required this.status,
  });

  double get progressPercent => progress / 100.0;

  DownloadItem copyWith({
    String? id,
    String? name,
    int? progress,
    DownloadStatus? status,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      name: name ?? this.name,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

/// 下载状态枚举
enum DownloadStatus {
  pending, // 等待中
  downloading, // 下载中
  completed, // 已完成
  failed, // 失败
}

/// 下载项目卡片组件
class DownloadItemCard extends StatelessWidget {
  const DownloadItemCard({
    super.key,
    required this.item,
    required this.onCancel,
    required this.onRetry,
  });

  final DownloadItem item;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 状态图标
                    if (item.status == DownloadStatus.completed)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else if (item.status == DownloadStatus.failed)
                      const Icon(Icons.error, color: Colors.red),
                    // 删除按钮
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: onCancel,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 进度条
            if (item.status == DownloadStatus.downloading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.progress}%'),
                      const SizedBox(width: 16),
                      Text(_formatBytes(item.progress * 1024 * 1024)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: item.progress / 100),
                ],
              )
            else if (item.status == DownloadStatus.completed)
              const Text('下载完成', style: TextStyle(color: Colors.green)),
            
            const SizedBox(height: 16),
            
            // 操作按钮
            if (item.status == DownloadStatus.failed)
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              )
            else if (item.status == DownloadStatus.downloading)
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.pause),
                label: const Text('暂停'),
              ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
