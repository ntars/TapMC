import 'package:flutter/material.dart';

import '../../domain/block_type.dart';

/// 方块配色。放在一处，改配色不用翻遍界面。
///
/// 取值刻意压低饱和度：地图上有二十几格色块，高饱和会晃眼，
/// 也不符合「游戏本体是内容、界面是容器」的层级关系。
const Map<BlockType, Color> _blockColors = {
  BlockType.air: Color(0xFFF2F2F5),
  BlockType.dirt: Color(0xFFC9A87C),
  BlockType.stone: Color(0xFF9AA0A6),
  BlockType.water: Color(0xFF7FB3D5),
  BlockType.wood: Color(0xFF8D6E63),
};

/// 世界网格视图。点击格子放置方块，长按破坏。
///
/// 用 [GridView.builder] 而非手摆 [Positioned]：格子数量固定但尺寸随窗口变化，
/// GridView 会自动处理换行与滚动，不必自己算坐标。
class WorldGrid extends StatelessWidget {
  const WorldGrid({
    super.key,
    required this.width,
    required this.height,
    required this.blockAt,
    required this.onTap,
    required this.onLongPress,
    this.playerPos,
  });

  final int width;
  final int height;
  final BlockType Function(int x, int y) blockAt;
  final void Function(int x, int y) onTap;
  final void Function(int x, int y) onLongPress;

  /// 玩家所在格。为空表示还没进入世界。
  final (int, int)? playerPos;

  @override
  Widget build(BuildContext context) {
    if (width <= 0 || height <= 0) {
      return const Center(child: Text('世界尚未加载'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 让格子尽量接近正方形：按可用空间与格数反推边长。
        final cell = (constraints.maxWidth / width)
            .clamp(8.0, constraints.maxHeight / height);

        return SingleChildScrollView(
          child: SizedBox(
            width: cell * width,
            height: cell * height,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: width,
                mainAxisExtent: cell,
              ),
              itemCount: width * height,
              itemBuilder: (context, index) {
                final x = index % width;
                final y = index ~/ width;
                final type = blockAt(x, y);
                final isPlayer = playerPos == (x, y);

                return GestureDetector(
                  onTap: () => onTap(x, y),
                  onLongPress: () => onLongPress(x, y),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _blockColors[type] ?? _blockColors[BlockType.air],
                      border: Border.all(
                        color: const Color(0x14000000),
                        width: 0.5,
                      ),
                    ),
                    child: isPlayer
                        ? Center(
                            child: Container(
                              width: cell * 0.42,
                              height: cell * 0.42,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2F6BFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
