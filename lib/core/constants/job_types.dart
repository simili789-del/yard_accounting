import 'package:flutter/material.dart';

/// 默认作业类型列表，用户可在“设置管理”中动态增删并配置单价。
class DefaultJobTypes {
  DefaultJobTypes._();

  static const List<String> types = [
    '货场装车',
    '货场归剁',
    '货场倒货',
    '内倒装车',
    '内倒归垛',
    '挖掘机加高',
    '神华装车',
    '神华归垛',
    '封垛',
  ];

  static const Map<String, double> defaultPrices = {
    '货场装车': 1.2,
    '货场归剁': 1.2,
    '货场倒货': 1.8,
    '内倒装车': 1.8,
    '内倒归垛': 1.2,
    '挖掘机加高': 1.0,
    '神华装车': 1.2,
    '神华归垛': 1.2,
    '封垛': 1.0,
  };

  /// 作业类型展示色，用于卡片、图表、列表圆点。
  static const Map<String, Color> colors = {
    '货场装车': Colors.blue,
    '货场归剁': Colors.purple,
    '货场倒货': Colors.orange,
    '内倒装车': Colors.red,
    '内倒归垛': Colors.green,
    '火车装车': Colors.brown,
    '挖掘机加高': Colors.teal,
    '神华装车': Colors.indigo,
    '神华归垛': Colors.deepOrange,
    '封垛': Colors.cyan,
  };

  static Color colorOf(String jobType) =>
      colors[jobType] ?? Colors.blueGrey;

  static double priceOf(String jobType) =>
      defaultPrices[jobType] ?? 1.0;
}

/// Hive Box 名称统一管理，避免魔法字符串散落各处。
class HiveBoxes {
  HiveBoxes._();

  static const String records = 'work_records_box';
  static const String jobPrices = 'job_prices_box';
  static const String salarySettings = 'salary_settings_box';
  static const String appSettings = 'app_settings_box';
  static const String appSettingsV2 = 'app_settings_v2_box';
}
