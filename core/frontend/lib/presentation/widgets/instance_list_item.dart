import 'package:flutter/material.dart';

/// 实例列表项组件
class InstanceListItem extends StatelessWidget {
  const InstanceListItem({
    super.key,
    required this.id,
    required this.name,
    this.gameVersion,
    this.lastPlayed,
    this.onDeleted,
  });

  final String id;
  final String name;
  final String? gameVersion;
  final DateTime? lastPlayed;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _themeColorOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gameVersion != null) Text('游戏版本: $gameVersion'),
            if (lastPlayed != null)
              Text('最后游玩: ${_formatDateTime(lastPlayed!)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDeleted,
          tooltip: '删除实例',
        ),
      ),
    );
  }

  Color _themeColorOf(BuildContext context) {
    return Colors.blue.withValues(alpha: 0.12);
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }
}
