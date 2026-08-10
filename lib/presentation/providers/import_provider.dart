import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/job_types.dart';
import '../../data/repositories/excel_importer.dart';
import '../../data/repositories/record_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/work_record.dart';
import '../providers/repository_providers.dart';

/// 导入向导的 UI 状态。
class ImportUiState {
  final String? filePath;
  final bool loading;
  final String? error;
  final ExcelParseResult? result;
  final Set<String> selectedWorkers;
  final DateTime? date;
  final ShiftType shift;
  final bool done;
  final int importedCount;

  ImportUiState({
    this.filePath,
    this.loading = false,
    this.error,
    this.result,
    this.selectedWorkers = const {},
    this.date,
    this.shift = ShiftType.day,
    this.done = false,
    this.importedCount = 0,
  });

  ImportUiState copyWith({
    String? filePath,
    bool? loading,
    String? error,
    ExcelParseResult? result,
    Set<String>? selectedWorkers,
    DateTime? date,
    ShiftType? shift,
    bool? done,
    int? importedCount,
  }) {
    return ImportUiState(
      filePath: filePath ?? this.filePath,
      loading: loading ?? this.loading,
      error: error,
      result: result ?? this.result,
      selectedWorkers: selectedWorkers ?? this.selectedWorkers,
      date: date ?? this.date,
      shift: shift ?? this.shift,
      done: done ?? this.done,
      importedCount: importedCount ?? this.importedCount,
    );
  }
}

final importProvider =
    StateNotifierProvider<ImportNotifier, ImportUiState>((ref) {
  return ImportNotifier(ref);
});

class ImportNotifier extends StateNotifier<ImportUiState> {
  final Ref _ref;
  ImportNotifier(this._ref) : super(ImportUiState());

  Future<void> loadFile(String path,
      {String? sheetName, int? headerRow}) async {
    state = state.copyWith(
      filePath: path,
      loading: true,
      error: null,
      result: null,
      done: false,
      importedCount: 0,
    );
    try {
      final result = parseXlsx(path, sheetName: sheetName, headerRow: headerRow);
      final names = result.rows.map((r) => r.workerName).toSet();
      final fixed =
          _ref.read(settingsRepositoryProvider).getFixedWorkers().toSet();
      // 有固定人员名单则预勾名单内的人，否则默认全选
      final selected = fixed.isNotEmpty ? names.intersection(fixed) : names;
      state = state.copyWith(
        loading: false,
        result: result,
        selectedWorkers: selected,
        date: result.date,
        shift: result.shift,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void toggleWorker(String name, bool selected) {
    final s = <String>{...state.selectedWorkers};
    if (selected) {
      s.add(name);
    } else {
      s.remove(name);
    }
    state = state.copyWith(selectedWorkers: s);
  }

  void selectAll(bool all) {
    final s = all
        ? state.result?.rows.map((r) => r.workerName).toSet() ?? {}
        : <String>{};
    state = state.copyWith(selectedWorkers: s);
  }

  void setDate(DateTime d) => state = state.copyWith(date: d);
  void setShift(ShiftType s) => state = state.copyWith(shift: s);

  /// 确认导入：先同步作业类型（删旧的4个默认类 + 加表格清洗出的新类与单价），
  /// 再写入勾选人员的记录，最后保存固定人员名单。
  Future<void> confirm() async {
    final result = state.result;
    if (result == null) return;
    final date = state.date ?? DateTime.now();

    // 1) 同步作业类型
    final notifier = _ref.read(unitPricesProvider.notifier);
    final current = Map<String, double>.from(_ref.read(unitPricesProvider));
    for (final old in DefaultJobTypes.types) {
      if (current.containsKey(old)) notifier.remove(old);
    }
    for (final col in result.jobColumns) {
      final price = col.price ?? current[col.name] ?? 1.0;
      notifier.add(col.name, price);
    }

    // 2) 构造并写入记录
    final repo = _ref.read(recordRepositoryProvider);
    final records = <WorkRecord>[];
    for (final row in result.rows) {
      if (!state.selectedWorkers.contains(row.workerName)) continue;
      records.add(WorkRecord(
        id: RecordRepository.makeImportId(date, row.workerName),
        date: DateTime(date.year, date.month, date.day),
        workerName: row.workerName,
        vehicleNo: row.vehicleNo,
        shift: state.shift,
        jobQuantities: Map<String, int>.from(row.quantities),
        remark: row.remark,
      ));
    }
    await repo.saveImportedRecords(records);

    // 3) 沉淀固定人员名单 + 刷新联动
    await _ref.read(settingsRepositoryProvider).setFixedWorkers(
          state.selectedWorkers.toList(),
        );
    _ref.read(unitPricesProvider.notifier).refresh();

    state = state.copyWith(done: true, importedCount: records.length);
  }

  void reset() => state = ImportUiState();
}

/// 存放「微信/系统分享进来的待导入文件」路径；RootShell 监听后跳转向导并消费置空。
final sharedFileProvider = StateProvider<String?>((ref) => null);

/// 是否为可导入的表格文件（按扩展名过滤，因微信分享 MIME 常为 octet-stream）。
bool isImportableFile(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.xlsx') || p.endsWith('.xls') || p.endsWith('.csv');
}
