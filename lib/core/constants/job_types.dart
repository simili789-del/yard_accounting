/// 默认作业类型列表，用户可在“设置管理”中动态增删并配置单价。
class DefaultJobTypes {
  DefaultJobTypes._();

  static const List<String> types = [
    '装车',
    '卸车',
    '倒货',
    '理货',
  ];
}

/// Hive Box 名称统一管理，避免魔法字符串散落各处。
class HiveBoxes {
  HiveBoxes._();

  static const String records = 'work_records_box';
  static const String jobPrices = 'job_prices_box';
  static const String salarySettings = 'salary_settings_box';
  static const String appSettings = 'app_settings_box';
}
