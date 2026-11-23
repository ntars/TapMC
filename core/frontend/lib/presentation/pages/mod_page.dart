import 'package:flutter/material.dart';
import '../game_session.dart';
import '../../domain/protocol.dart';

/// 模组管理页面
class ModPage extends StatefulWidget {
  const ModPage({super.key, required this.session});

  final GameSession session;

  @override
  State<ModPage> createState() => _ModPageState();
}

class _ModPageState extends State<ModPage> {
  List<dynamic> mods = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMods();
  }

  Future<void> _loadMods() async {
    try {
      final result = await widget.session.repository.call(
        Methods.modList,
        params: {'instanceId': 'default'},
      );
      
      setState(() {
        mods = List<dynamic>.from(result ?? []);
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载模组失败: $e')),
        );
      }
    }
  }

  Future<void> _toggleMod(dynamic mod, bool enabled) async {
    try {
      await widget.session.repository.call(
        enabled ? Methods.modEnable : Methods.modDisable,
        params: {
          'instanceId': 'default',
          'modId': mod['id'],
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${mod['name']} ${enabled ? "启用" : "禁用"}成功')),
        );
        _loadMods(); // 刷新列表
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模组管理'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : mods.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 64),
                      SizedBox(height: 16),
                      Text('暂无模组'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: mods.length,
                  itemBuilder: (context, index) {
                    final mod = mods[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(mod['name'] ?? '未知模组'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mod['version'] ?? ''),
                            if (mod['loader'] != null) Text('加载器: ${mod['loader']}'),
                          ],
                        ),
                        trailing: Switch(
                          value: mod['enabled'] ?? true,
                          onChanged: (value) => _toggleMod(mod, value),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
