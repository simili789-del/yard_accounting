import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/work_record.dart';
import 'repository_providers.dart';

enum QuickRange { last7Days, thisMonth, lastMonth, custom }

class HistoryFilter {
  final QuickRange range;
  final String keyword;
  final ShiftType? shift;
  final DateTime? customStart;
  final DateTime? customEnd;

  const HistoryFilter({
    this.range = QuickRange.last7Days,
    this.keyword = '',
    this.shift,
    this.customStart,
    this.customEnd,
  });

  HistoryFilter copyWith({
    QuickRange? range,
    String? keyword,
    ShiftType? shift,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return HistoryFilter(
      range: range ?? this.range,
      keyword: keyword ?? this.keyword,
      shift: shift ?? this.shift,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
    );
  }

  (DateTime, DateTime) resolveDates() {
    final now = DateTime.now();
    switch (range) {
      case QuickRange.last7Days:
        return (now.subtract(const Duration(days: 6)), now);
      case QuickRange.thisMonth:
        return (DateTime(now.year, now.month, 1), now);
      case QuickRange.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0);
        return (lastMonth, lastDay);
      case QuickRange.custom:
        return (customStart ?? now, customEnd ?? now);
    }
  }
}

final historyFilterProvider =
    StateProvider<HistoryFilter>((ref) => const HistoryFilter());

final historyRecordsProvider = Provider<List<WorkRecord>>((ref) {
  final repository = ref.watch(recordRepositoryProvider);
  final filter = ref.watch(historyFilterProvider);
  final (start, end) = filter.resolveDates();
  return repository.query(
    start: start,
    end: end,
    keyword: filter.keyword,
    shift: filter.shift,
  );
});

/// 批量勾选待删除的记录 id 集合。
final selectedRecordIdsProvider = StateProvider<Set<String>>((ref) => {});
