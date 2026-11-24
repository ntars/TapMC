import 'package:flutter/material.dart';
import 'dart:async';

/// 实例管理页面
class InstancePage extends StatefulWidget {
  const InstancePage({super.key});

  @override
  State<InstancePage> createState() => _InstancePageState();
}

class _InstancePageState extends State<InstancePage> {
  List<dynamic> instances = [];
  bool loading = true;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _loadInstances();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _loadInstances());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadInstances() async {
    try {
      // 模拟实例列表（实际应从后端获取）
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        instances = [
          {'id': 'default', 'name': '默认实例', 'gameVersion': '1.20.1'},
          {'id': 'survival', 'name': '生存模式', 'gameVersion': '1.20.1'},
        ];
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载实例失败: $e')),
        );
      }
    }
  }

  Future<void> _createInstance() async {
    final nameController = TextEditingController();
    String? selectedTemplate;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新实例'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '实例名称'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '模板'),
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('默认')),
                  DropdownMenuItem(value: 'survival', child: Text('生存模式')),
                ],
                onChanged: (value) => selectedTemplate = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop({
                  'name': nameController.text,
                  'templateId': selectedTemplate ?? 'default',
                });
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    
    // 创建实例后刷新列表
    await _loadInstances();
  }

  Future<void> _deleteInstance(dynamic instance) async {
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除实例'),
        content: Text('确定要删除实例 "${instance['name']}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        // 调用后端 API
        await _loadInstances();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除实例失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('实例管理')),
      body: ListView.builder(
        itemCount: instances.length,
        itemBuilder: (context, index) {
          final instance = instances[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(instance['name']),
              subtitle: Text('版本: ${instance['gameVersion']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _launchInstance(instance),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editInstance(instance),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteInstance(instance),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createInstance,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _launchInstance(dynamic instance) {
    // TODO: 实现启动逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('启动实例: ${instance['name']}')),
    );
  }

  void _editInstance(dynamic instance) {
    // TODO: 实现编辑逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('编辑实例: ${instance['name']}')),
    );
  }
}
