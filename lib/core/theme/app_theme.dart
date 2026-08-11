import 'package:flutter/material.dart';

/// 基于 Material 3 的浅色/深色主题配置。
class AppTheme {
  AppTheme._();

  /// 可选主题色列表，与 `AppSettings.primaryColorIndex` 对应。
  static const List<Color> primaries = [
    Color(0xFF2E7D32), // 货场绿
    Color(0xFF1565C0), // 工程蓝
    Color(0xFF6A1B9A), // 深紫
    Color(0xFFC62828), // 警示红
    Color(0xFFEF6C00), // 活力橙
    Color(0xFF00897B), // 青绿
    Color(0xFFEC407A), // 玫红
  ];

  static Color seedForIndex(int index) =>
      primaries[index.clamp(0, primaries.length - 1)];

  static ThemeData light({int primaryIndex = 0}) => _theme(
        brightness: Brightness.light,
        seedColor: seedForIndex(primaryIndex),
      );

  static ThemeData dark({int primaryIndex = 0}) => _theme(
        brightness: Brightness.dark,
        seedColor: seedForIndex(primaryIndex),
      );

  static ThemeData _theme({
    required Brightness brightness,
    required Color seedColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: brightness == Brightness.light
                ? Colors.grey.shade200
                : Colors.grey.shade800,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.grey.shade50
            : Colors.grey.shade900,
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
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: brightness == Brightness.light
              ? Colors.grey.shade100
              : Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
      ),
    );
  }
}
