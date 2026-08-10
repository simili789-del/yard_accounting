import 'package:flutter/material.dart';

/// 基于 Material 3 的浅色/深色主题配置。
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF2E7D32); // 货场绿，贴合作业场景

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: const CardTheme(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: const CardTheme(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );
}
