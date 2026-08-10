import 'package:hive/hive.dart';

import '../../core/constants/job_types.dart';
import '../../domain/entities/work_record.dart';

/// 记账数据仓库：向上层提供统一数据接口，屏蔽 Hive 存储细节。
class RecordRepository {
  Box<WorkRecord> get _box => Hive.box<WorkRecord>(HiveBoxes.records);

  /// 获取“今日”记录；若不存在则返回一条空白记录供表单编辑。
  Future<WorkRecord> getTodayRecord() async {
    final today = DateTime.now();
    final key = _dateKey(today);
    final existing = _box.get(key);
    if (existing != null) return existing;

    return WorkRecord(
      id: key,
      date: DateTime(today.year, today.month, today.day),
      workerName: '',
      vehicleNo: '',
      shift: ShiftType.day,
      jobQuantities: {},
    );
  }

  Future<void> saveRecord(WorkRecord record) async {
    await _box.put(_dateKey(record.date), record);
  }

  Future<void> deleteRecords(List<String> ids) async {
    await _box.deleteAll(ids);
  }

  /// “复制昨日”：拉取昨日记录的作业数据，套用到今日草稿。
  Future<WorkRecord?> getYesterdayRecord() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _box.get(_dateKey(yesterday));
  }

  /// 按日期范围 + 关键词（姓名/车号）查询明细。
  List<WorkRecord> query({
    DateTime? start,
    DateTime? end,
    String? keyword,
    ShiftType? shift,
  }) {
    return _box.values.where((r) {
      if (start != null && r.date.isBefore(start)) return false;
      if (end != null && r.date.isAfter(end)) return false;
      if (shift != null && r.shift != shift) return false;
      if (keyword != null && keyword.isNotEmpty) {
        final k = keyword.toLowerCase();
        if (!r.workerName.toLowerCase().contains(k) &&
            !r.vehicleNo.toLowerCase().contains(k)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<WorkRecord> get all => _box.values.toList();

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
