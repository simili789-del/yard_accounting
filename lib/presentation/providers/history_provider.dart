import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/work_record.dart';
import 'repository_providers.dart';

enum QuickRange { today, last7Days, thisMonth, lastMonth, custom }

enum HistorySort { dateDesc, dateAsc, amountDesc }

class HistoryFilter {
  final QuickRange range;
  final String keyword;
  final ShiftType? shift;
  final DateTime? customStart;
  final DateTime? customEnd;
  final HistorySort sort;

  const HistoryFilter({
    this.range = QuickRange.last7Days,
    this.keyword = '',
    this.shift,
    this.customStart,
    this.customEnd,
    this.sort = HistorySort.dateDesc,
  });

  HistoryFilter copyWith({
    QuickRange? range,
    String? keyword,
    ShiftType? shift,
    DateTime? customStart,
    DateTime? customEnd,
    HistorySort? sort,
    bool clearShift = false,
  }) {
    return HistoryFilter(
      range: range ?? this.range,
      keyword: keyword ?? this.keyword,
      shift: clearShift ? null : (shift ?? this.shift),
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      sort: sort ?? this.sort,
    );
  }

  (DateTime, DateTime) resolveDates() {
    final now = DateTime.now();
    // 全部按「完整自然日」归一化：起点取当日 00:00:00，终点取当日 23:59:59.999，
    // 避免带时刻的 now 把当天 0 点 / 月初 / 月末的记录误判为越界而漏统计。
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
    switch (range) {
      case QuickRange.today:
        return (dayStart, dayEnd);
      case QuickRange.last7Days:
        return (dayStart.subtract(const Duration(days: 6)), dayEnd);
      case QuickRange.thisMonth:
        return (DateTime(now.year, now.month, 1), dayEnd);
      case QuickRange.lastMonth:
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd =
            DateTime(now.year, now.month, 0, 23, 59, 59, 999, 999);
        return (lastMonthStart, lastMonthEnd);
      case QuickRange.custom:
        final start = customStart != null
            ? DateTime(customStart.year, customStart.month, customStart.day)
            : dayStart;
        final end = customEnd != null
            ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999, 999)
            : dayEnd;
        return (start, end);
    }
  }
}

final historyFilterProvider =
    StateProvider<HistoryFilter>((ref) => const HistoryFilter());

final historyRecordsProvider = Provider<List<WorkRecord>>((ref) {
  final repository = ref.watch(recordRepositoryProvider);
  final filter = ref.watch(historyFilterProvider);
  // 接入真实单价表，金额排序才能正确生效（原 amount({}) 空表会使排序失效）
  final unitPrices = ref.watch(unitPricesProvider);
  final (start, end) = filter.resolveDates();
  var records = repository.query(
    start: start,
    end: end,
    keyword: filter.keyword,
    shift: filter.shift,
  );
  switch (filter.sort) {
    case HistorySort.dateDesc:
      records.sort((a, b) => b.date.compareTo(a.date));
    case HistorySort.dateAsc:
      records.sort((a, b) => a.date.compareTo(b.date));
    case HistorySort.amountDesc:
      records.sort((a, b) => b.amount(unitPrices).compareTo(a.amount(unitPrices)));
  }
  return records;
});

/// 最近 7 天每日汇总，用于明细页顶部“近7天各类型车数”。
final last7DaysSummaryProvider = Provider<Map<DateTime, List<WorkRecord>>>((ref) {
  final repository = ref.watch(recordRepositoryProvider);
  final now = DateTime.now();
  // 起点取 6 天前的 00:00:00，终点取今日 23:59:59.999，覆盖完整 7 个自然日
  final start = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
  final records = repository.query(start: start, end: end);
  final map = <DateTime, List<WorkRecord>>{};
  for (final r in records) {
    final key = DateTime(r.date.year, r.date.month, r.date.day);
    map.putIfAbsent(key, () => []).add(r);
  }
  return map;
});

/// 某天的全部记录（含「今日记账」纯日期记录 + 当天所有 imp_ 导入记录），
/// 用于首页「今日摘要」聚合展示——导入当天数据后摘要同步更新。
final dayRecordsProvider =
    Provider.family<List<WorkRecord>, DateTime>((ref, date) {
  final repository = ref.watch(recordRepositoryProvider);
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  return repository.query(start: dayStart, end: dayEnd);
});

/// 批量勾选待删除的记录 id 集合。
final selectedRecordIdsProvider = StateProvider<Set<String>>((ref) => {});
