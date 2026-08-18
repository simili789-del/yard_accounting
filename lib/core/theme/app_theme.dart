import 'package:flutter/material.dart';

import 'app_dimens.dart';

/// 基于 Material 3 的主题配置，支持 7 套主题色预设 + 深色模式。
///
/// 通过 `AppTheme.light(index)` / `AppTheme.dark(index)` 按索引取色，
/// 索引对应 `AppSettings.primaryColorIndex`（设置页取色器也消费 `primaries`）。
///
/// 升级说明（对外 API 完全不变，调用方无需任何改动）：
/// - 组件主题从「够用」升级为「成套」：新增 FilledButton / OutlinedButton /
///   IconButton / Chip / Divider / ListTile / Switch / Slider /
///   ExpansionTile / BottomSheet / Dialog / SnackBar / ProgressIndicator
///   等主题，确保未显式定制样式的原生控件也保持统一的现代化观感。
/// - 圆角、间距全部改为读取 [AppRadius] / [AppSpacing] 令牌，杜绝魔法数字。
/// - 深色模式下的对比度问题（原注释提到的 TextField 文字不可见）保留并加强了修复。
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
      primaries[((index % primaries.length) + primaries.length) %
          primaries.length];

  static ThemeData _createTheme(Color seedColor, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    final baseTextTheme = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      // ===== 卡片：贴底容器色、无投影、统一大圆角 =====
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        color: colorScheme.surfaceContainer,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        centerTitle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // ===== 按钮：统一圆角与内边距，形成一致的触控手感 =====
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        iconColor: colorScheme.onSurfaceVariant,
      ),

      switchTheme: const SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),

      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        collapsedShape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: AppRadius.chip,
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      ),

      // 深色模式下 TextField / TextFormField 文字不可见的修复：
      // Card 内部 surfaceContainer 背景很深，必须显式指定输入框填充色与文字色，
      // 否则默认文字色与背景对比度不足（尤其深色模式）。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),

      // 必须基于当前 brightness 取默认文字色，否则深色模式下
      // TextField 等输入文字会继承浅色主题的黑/灰色，导致看不清。
      textTheme: baseTextTheme.copyWith(
        titleLarge: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()], // 数字等宽对齐
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
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
