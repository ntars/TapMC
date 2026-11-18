import 'package:flutter/material.dart';

/// 应用主题。跟随系统浅色 / 深色。
///
/// 用 Material 3 的 [ColorScheme.fromSeed] 而非手写一整套配色：
/// 手写容易在深色模式下出现对比度不足，而 fromSeed 会自动保证层级关系。
///
/// 主色取蓝（#2F6BFF），与 TapMC 的「轻点即启动」定位一致——冷静、不抢内容。
class TapMcTheme {
  const TapMcTheme._();

  static const Color _seed = Color(0xFF2F6BFF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed);
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      // 桌面端用紧凑密度，手机端保持默认触摸尺寸。
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
