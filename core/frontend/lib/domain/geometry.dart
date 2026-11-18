import 'package:flutter/foundation.dart';

/// 方块坐标。不可变值对象，按值比较。
///
/// 原点左上，x 向右、y 向下——与后端 `BlockPos` 一致。
@immutable
class BlockPos {
  const BlockPos(this.x, this.y);

  final int x;
  final int y;

  /// 四个方向的相邻格。
  BlockPos offset(MoveDirection direction) =>
      BlockPos(x + direction.dx, y + direction.dy);

  factory BlockPos.fromJson(Map<String, dynamic> json) =>
      BlockPos((json['x'] as num).toInt(), (json['y'] as num).toInt());

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      other is BlockPos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

/// 四方向移动。与后端 `MoveDirection` 对齐。
///
/// [dx] / [dy] 的符号直接决定操作是否反着来，改之前先确认坐标原点在左上。
enum MoveDirection {
  north('NORTH', 0, -1),
  south('SOUTH', 0, 1),
  west('WEST', -1, 0),
  east('EAST', 1, 0);

  const MoveDirection(this.wireName, this.dx, this.dy);

  final String wireName;
  final int dx;
  final int dy;

  /// 从线上名解析，未知返回 null（后端新增方向时前端应忽略而不是猜）。
  static MoveDirection? fromWire(String? name) {
    for (final direction in MoveDirection.values) {
      if (direction.wireName == name) return direction;
    }
    return null;
  }
}
