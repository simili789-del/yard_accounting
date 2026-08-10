import 'package:hive/hive.dart';

part 'salary_settings.g.dart';

/// “设置管理”-> 工资构成：底薪 / 餐补 / 扣款。
@HiveType(typeId: 2)
class SalarySettings extends HiveObject {
  @HiveField(0)
  final double baseSalary;

  @HiveField(1)
  final double mealAllowance;

  @HiveField(2)
  final double deduction;

  SalarySettings({
    this.baseSalary = 0,
    this.mealAllowance = 0,
    this.deduction = 0,
  });

  SalarySettings copyWith({
    double? baseSalary,
    double? mealAllowance,
    double? deduction,
  }) {
    return SalarySettings(
      baseSalary: baseSalary ?? this.baseSalary,
      mealAllowance: mealAllowance ?? this.mealAllowance,
      deduction: deduction ?? this.deduction,
    );
  }
}
