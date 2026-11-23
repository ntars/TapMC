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
    return _build(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      // App Bar 主题
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: brightness == Brightness.dark ? 2 : 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      
      // 卡片主题
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 2 : 1,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Chip 主题
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        labelStyle: TextStyle(fontSize: 13),
      ),
      
      // 按钮主题
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: brightness == Brightness.dark 
          ? scheme.surfaceContainerHigh 
          : Colors.white,
      ),
      
      // 列表主题
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: scheme.surfaceContainerLow,
        selectedTileColor: scheme.primaryContainer,
      ),
    );
  }
}
