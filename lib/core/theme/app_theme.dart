import 'package:flutter/material.dart';

/// 基于 Material 3 的主题配置，支持 7 套主题色预设 + 深色模式。
///
/// 通过 `AppTheme.light(index)` / `AppTheme.dark(index)` 按索引取色，
/// 索引对应 `AppSettings.primaryColorIndex`（设置页取色器也消费 `primaries`）。
/// 仅扩展 [ThemeData]，不改动任何业务逻辑。
class AppTheme {
  AppTheme._();

  /// 7 套主题色预设，与设置页「主题色」取色器一一对应。
  /// 索引 0 为默认货场绿。
  static const List<Color> primaries = [
    Color(0xFF2E7D32), // 0: 货场绿（默认）
    Colors.blue, // 1: 蓝色
    Colors.indigo, // 2: 靛蓝
    Colors.orange, // 3: 橙色
    Colors.red, // 4: 红色
    Colors.teal, // 5: 青色
    Colors.purple, // 6: 紫色
  ];

  static ThemeData light(int primaryIndex) =>
      _createTheme(_seed(primaryIndex), Brightness.light);

  static ThemeData dark(int primaryIndex) =>
      _createTheme(_seed(primaryIndex), Brightness.dark);

  /// 按索引取色（越界时取模循环，避免越界崩溃）。
  static Color _seed(int index) =>
      primaries[index % primaries.length];

  static ThemeData _createTheme(Color seedColor, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      // iOS 18 风格：大圆角、无投影、贴底容器色卡片。
      // CardTheme 在 Flutter 3.47+ 已更名为 CardThemeData。
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        color: colorScheme.surfaceContainer,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
      ),
      // 深色模式下 TextField / TextFormField 文字不可见的修复：
      // Card 内部 surfaceContainer 背景很深，必须显式指定输入框填充色与文字色，
      // 否则默认文字色与背景对比度不足（尤其深色模式）。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      // 必须基于当前 brightness 取默认文字色，否则深色模式下
      // TextField 等输入文字会继承浅色主题的黑/灰色，导致看不清。
      textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
        titleLarge: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()], // 数字等宽对齐
        ),
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        bodySmall: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
