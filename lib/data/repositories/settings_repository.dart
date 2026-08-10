import 'package:hive/hive.dart';

import '../../core/constants/job_types.dart';
import '../../domain/entities/salary_settings.dart';

/// 设置数据仓库：作业类型单价 + 工资构成 + 主题模式。
class SettingsRepository {
  Box get _priceBox => Hive.box(HiveBoxes.jobPrices);
  Box<SalarySettings> get _salaryBox =>
      Hive.box<SalarySettings>(HiveBoxes.salarySettings);
  Box get _appBox => Hive.box(HiveBoxes.appSettings);

  Map<String, double> getUnitPrices() {
    final map = <String, double>{};
    for (final key in _priceBox.keys) {
      map[key as String] = (_priceBox.get(key) as num).toDouble();
    }
    return map;
  }

  Future<void> setUnitPrice(String jobType, double price) async {
    await _priceBox.put(jobType, price);
  }

  Future<void> removeJobType(String jobType) async {
    await _priceBox.delete(jobType);
  }

  SalarySettings getSalarySettings() {
    return _salaryBox.get('current') ?? SalarySettings();
  }

  Future<void> saveSalarySettings(SalarySettings settings) async {
    await _salaryBox.put('current', settings);
  }

  /// 主题模式：'light' / 'dark' / 'system'
  String getThemeMode() => _appBox.get('themeMode', defaultValue: 'system');

  Future<void> setThemeMode(String mode) async {
    await _appBox.put('themeMode', mode);
  }

  /// 「固定人员名单」：导入向导预勾用，避免每次手动勾选。
  List<String> getFixedWorkers() =>
      List<String>.from(_appBox.get('fixedWorkers', defaultValue: <String>[]));

  Future<void> setFixedWorkers(List<String> workers) async {
    await _appBox.put('fixedWorkers', workers);
  }
}
