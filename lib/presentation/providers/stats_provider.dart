import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/work_record.dart';
import 'repository_providers.dart';

class MonthlyStats {
  final DateTime month;
  final Map<String, int> quantityByJobType; // 按单价分类汇总
  final Map<DateTime, int> vehicleCountByDay; // 每日车数
  final Map<String, double> incomeByWorker; // 多维度人员统计
  final double totalIncome;

  const MonthlyStats({
    required this.month,
    required this.quantityByJobType,
    required this.vehicleCountByDay,
    required this.incomeByWorker,
    required this.totalIncome,
  });
}

final statsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyStatsProvider = Provider<MonthlyStats>((ref) {
  final repository = ref.watch(recordRepositoryProvider);
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  final month = ref.watch(statsMonthProvider);
  final unitPrices = settingsRepository.getUnitPrices();

  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final List<WorkRecord> records =
      repository.query(start: start, end: end);

  final quantityByJobType = <String, int>{};
  final vehicleCountByDay = <DateTime, int>{};
  final incomeByWorker = <String, double>{};
  double totalIncome = 0;

  for (final r in records) {
    r.jobQuantities.forEach((jobType, qty) {
      quantityByJobType[jobType] = (quantityByJobType[jobType] ?? 0) + qty;
    });

    final dayKey = DateTime(r.date.year, r.date.month, r.date.day);
    vehicleCountByDay[dayKey] = (vehicleCountByDay[dayKey] ?? 0) + 1;

    final amount = r.amount(unitPrices);
    incomeByWorker[r.workerName] = (incomeByWorker[r.workerName] ?? 0) + amount;
    totalIncome += amount;
  }

  return MonthlyStats(
    month: month,
    quantityByJobType: quantityByJobType,
    vehicleCountByDay: vehicleCountByDay,
    incomeByWorker: incomeByWorker,
    totalIncome: totalIncome,
  );
});
