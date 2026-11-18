import 'package:flutter/material.dart';

import '../../domain/geometry.dart';

/// 方向盘。四向十字布局，拇指可达。
///
/// 用十字布局而非摇杆：骨架阶段只有四方向离散移动，十字能准确表达
/// 「一次一格」的语义；摇杆会让人误以为支持连续移动。
class DirectionPad extends StatelessWidget {
  const DirectionPad({
    super.key,
    required this.onMove,
    this.enabled = true,
  });

  final void Function(MoveDirection direction) onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PadButton(
            icon: Icons.keyboard_arrow_up,
            semanticLabel: '向北移动',
            onPressed: enabled ? () => onMove(MoveDirection.north) : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PadButton(
                icon: Icons.keyboard_arrow_left,
                semanticLabel: '向西移动',
                onPressed: enabled ? () => onMove(MoveDirection.west) : null,
              ),
              const SizedBox(width: 44, height: 44),
              _PadButton(
                icon: Icons.keyboard_arrow_right,
                semanticLabel: '向东移动',
                onPressed: enabled ? () => onMove(MoveDirection.east) : null,
              ),
            ],
          ),
          _PadButton(
            icon: Icons.keyboard_arrow_down,
            semanticLabel: '向南移动',
            onPressed: enabled ? () => onMove(MoveDirection.south) : null,
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: semanticLabel,
        style: IconButton.styleFrom(
          backgroundColor: onPressed == null
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : scheme.surfaceContainerHighest,
          foregroundColor: onPressed == null
              ? scheme.onSurface.withValues(alpha: 0.38)
              : scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
