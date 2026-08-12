import 'package:flutter/material.dart';

/// 基于 Material 3 的浅色/深色主题配置。
///
/// 全站视觉升级（专业商务·精致风）的核心：统一字体节奏、卡片轻质感、
/// 导航高亮、按钮/分割线/列表等组件规范。仅扩展 [ThemeData]，不改动
/// 任何业务逻辑，自动兼容 7 套主题色与深色模式。
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
    final isLight = brightness == Brightness.light;
    final baseText =
        isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme;
    // 在 M3 默认字体基础上微调：标题字重上调、大数字等宽对齐（金额/车数更整齐）。
    final textTheme = baseText.copyWith(
      displaySmall:
          baseText.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: baseText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      // 统一的「画布」底色，营造留白与层次。
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF6F7F9) : Colors.grey.shade900,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor:
            isLight ? const Color(0xFFF6F7F9) : Colors.grey.shade900,
        foregroundColor: colorScheme.onSurface,
      ),
      // 卡片：极轻 elevation + 柔阴影 + 1px 淡描边，告别纯平面感。
      cardTheme: CardTheme(
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: isLight ? Colors.black12 : Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      // 底部导航：选中项主色浅底高亮（indicator 由主题驱动，页面无需改）。
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.all<TextStyle?>(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        height: 64,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.grey.shade50 : Colors.grey.shade900,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor:
              isLight ? Colors.grey.shade100 : Colors.grey.shade800,
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
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        foregroundColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withOpacity(0.15),
        circularTrackColor: colorScheme.primary.withOpacity(0.15),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
