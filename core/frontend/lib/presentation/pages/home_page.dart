import 'package:flutter/material.dart';

import '../../data/transport/web_socket_transport.dart';
import '../../domain/block_type.dart';
import '../../domain/geometry.dart';
import '../game_session.dart';
import '../widgets/direction_pad.dart';
import '../widgets/world_grid.dart';

/// 主页面。骨架阶段只有一个页面，因此不引入路由。
///
/// 三块布局：顶部状态条（连接信息 + 最后一条操作反馈）、中部世界、右侧控制区。
/// 窄屏（手机竖屏）时控制区移到世界下方，避免挤压地图。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});

  final GameSession session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 首帧之后再发请求：连接失败时要弹提示，得先有 context。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.session.connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TapMC'),
        actions: [
          ListenableBuilder(
            listenable: widget.session,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _StatusChip(status: widget.session.status),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          final session = widget.session;

          if (session.status == ConnectionStatus.connecting ||
              session.status == ConnectionStatus.idle) {
            return const _LoadingView();
          }

          if (session.status == ConnectionStatus.failed) {
            return _ErrorView(
              message: session.errorMessage,
              onRetry: session.connect,
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final world = _WorldPane(session: session);
              final controls = _ControlPane(session: session);

              if (isNarrow) {
                return Column(
                  children: [
                    Expanded(child: world),
                    controls,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: world),
                  SizedBox(width: 260, child: controls),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 世界区：地图 + 底部操作反馈条。
class _WorldPane extends StatelessWidget {
  const _WorldPane({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final player = session.player;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WorldGrid(
                  width: session.world.width,
                  height: session.world.height,
                  blockAt: session.world.at,
                  playerPos: player == null ? null : (player.pos.x, player.pos.y),
                  onTap: (x, y) => session.placeAt(BlockPos(x, y)),
                  onLongPress: (x, y) => session.breakAt(BlockPos(x, y)),
                ),
              ),
            ),
          ),
        ),
        _FeedbackBar(text: session.lastAction),
      ],
    );
  }
}

/// 控制区：方块选择 + 方向盘 + 图例。
class _ControlPane extends StatelessWidget {
  const _ControlPane({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = session.player;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 位置信息
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('位置', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    player == null ? '未进入世界' : '${player.pos}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('放置方块', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in BlockType.values)
                if (type != BlockType.air)
                  ChoiceChip(
                    label: Text(_labelOf(type)),
                    selected: session.selectedBlock == type,
                    onSelected: (_) => session.selectBlock(type),
                  ),
            ],
          ),
          const SizedBox(height: 20),

          Center(
            child: DirectionPad(
              enabled: session.isJoined,
              onMove: session.move,
            ),
          ),
          const SizedBox(height: 16),

          // 图例。地图上的色块没有文字，需要一处说明。
          Text('图例', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final type in BlockType.values)
                if (type != BlockType.air)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _colorOf(type),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: const Color(0x22000000), width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(_labelOf(type),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
            ],
          ),
          const SizedBox(height: 20),

          Text('操作提示', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            '轻点格子放置方块，长按格子破坏方块。\n'
            '被模组拦下时会在下方提示原因。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _labelOf(BlockType type) => switch (type) {
        BlockType.air => '空气',
        BlockType.dirt => '泥土',
        BlockType.stone => '石头',
        BlockType.water => '水',
        BlockType.wood => '树干',
      };

  static Color _colorOf(BlockType type) => switch (type) {
        BlockType.air => const Color(0xFFF2F2F5),
        BlockType.dirt => const Color(0xFFC9A87C),
        BlockType.stone => const Color(0xFF9AA0A6),
        BlockType.water => const Color(0xFF7FB3D5),
        BlockType.wood => const Color(0xFF8D6E63),
      };
}

/// 底部操作反馈条。始终占位（无内容时透明），避免内容出现时布局跳动。
class _FeedbackBar extends StatelessWidget {
  const _FeedbackBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.surfaceContainerLow,
      child: Text(
        text.isEmpty ? ' ' : text,
        style: theme.textTheme.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      ConnectionStatus.idle => ('待连接', scheme.outline),
      ConnectionStatus.connecting => ('连接中', scheme.primary),
      ConnectionStatus.ready => ('已连接', const Color(0xFF2E7D32)),
      ConnectionStatus.failed => ('连接失败', scheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 14),
          Text('正在连接游戏服务端…'),
        ],
      ),
    );
  }
}

/// 错误视图。必须包含「发生了什么、可能原因、下一步」，不是只甩一句失败。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 14),
              Text('无法连接到游戏服务端',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message.isEmpty ? '未获得具体原因。' : message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(height: 10),
              Text(
                '提示：后端默认监听 127.0.0.1:${defaultEndpointFor().port}。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
