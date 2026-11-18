/// 方块类型。与后端 `BlockType` 枚举逐一对齐。
///
/// 用枚举而非字符串，是为了让「拿到一个不认识的方块名」在编译期就暴露；
/// 解析失败回退到 [air]，渲染时表现为空格，不会崩。
///
/// 坐标原点在左上角：x 向右、y 向下。这一点与后端必须一致，写错只会让地图上下颠倒，
/// 不会有任何报错。
enum BlockType {
  air('AIR', walkable: true),
  dirt('DIRT', walkable: true),
  stone('STONE', walkable: true),
  water('WATER', walkable: false),
  wood('WOOD', walkable: false);

  const BlockType(this.wireName, {required this.walkable});

  /// 线上名。必须与后端 `BlockType.name()` 完全一致。
  final String wireName;

  /// 能否站在上面。
  final bool walkable;

  /// 从线上名解析。未知名字回退到 [air]，不抛异常——
  /// 后端加了新方块而前端还没更新时，界面应降级显示而不是白屏。
  static BlockType fromWire(String? name) {
    for (final type in BlockType.values) {
      if (type.wireName == name) return type;
    }
    return BlockType.air;
  }
}
