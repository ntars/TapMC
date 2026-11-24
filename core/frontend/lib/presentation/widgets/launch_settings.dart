import 'package:flutter/material.dart';

class LaunchSettings {
  final int memoryMin;
  final int memoryMax;
  final List<String> jvmArgs;
  final List<String> gameArgs;

  LaunchSettings({
    this.memoryMin = 1024,
    this.memoryMax = 4096,
    this.jvmArgs = const [],
    this.gameArgs = const [],
  });

  LaunchSettings copyWith({
    int? memoryMin,
    int? memoryMax,
    List<String>? jvmArgs,
    List<String>? gameArgs,
  }) {
    return LaunchSettings(
      memoryMin: memoryMin ?? this.memoryMin,
      memoryMax: memoryMax ?? this.memoryMax,
      jvmArgs: jvmArgs ?? this.jvmArgs,
      gameArgs: gameArgs ?? this.gameArgs,
    );
  }
}

class LaunchSettingsDialog extends StatefulWidget {
  final LaunchSettings initialSettings;

  const LaunchSettingsDialog({
    super.key,
    required this.initialSettings,
  });

  @override
  State<LaunchSettingsDialog> createState() => _LaunchSettingsDialogState();
}

class _LaunchSettingsDialogState extends State<LaunchSettingsDialog> {
  late LaunchSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '启动设置',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            
            _buildMemorySettings(),
            const SizedBox(height: 16),
            
            _buildJvmArgs(),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _settings),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemorySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('内存分配 (MB)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最小内存', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _settings.memoryMin.toString()),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'MB',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          memoryMin: int.tryParse(value) ?? 1024,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最大内存', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _settings.memoryMax.toString()),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'MB',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          memoryMax: int.tryParse(value) ?? 4096,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            thumbColor: Theme.of(context).colorScheme.primary,
          ),
          child: Slider(
            min: 512,
            max: 16384,
            divisions: 30,
            value: _settings.memoryMax.toDouble(),
            label: '${_settings.memoryMax} MB',
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(memoryMax: value.toInt()));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJvmArgs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JVM 参数', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: '-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '添加自定义 JVM 参数（每行一个）',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class LaunchSettingsButton extends StatelessWidget {
  final LaunchSettings initialSettings;
  final Function(LaunchSettings) onConfirm;

  const LaunchSettingsButton({
    super.key,
    required this.initialSettings,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () async {
        final result = await showDialog<LaunchSettings>(
          context: context,
          builder: (context) => LaunchSettingsDialog(
            initialSettings: initialSettings,
          ),
        );
        
        if (result != null) {
          onConfirm(result);
        }
      },
      icon: const Icon(Icons.settings),
      label: const Text('启动设置'),
    );
  }
}
