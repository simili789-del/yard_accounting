import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/excel_importer.dart';
import '../../data/repositories/record_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/work_record.dart';
import '../../domain/models/imported_row.dart';
import '../providers/history_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/selected_date_record_provider.dart';
import '../providers/stats_provider.dart';

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

  /// 强匹配开关：开启时只导入「默认姓名」对应的人员；关闭时可导入全部。默认开。
  final bool enforceFixed;

  /// 是否匹配到历史模板（同格式表）。
  final bool templateMatched;

  /// 命中设置页「默认姓名」时的聚焦人员；非空时 UI 默认只勾他并强制仅导他。
  final String? focusedWorker;

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
    this.enforceFixed = true,
    this.templateMatched = false,
    this.focusedWorker,
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
    bool? enforceFixed,
    bool? templateMatched,
    String? focusedWorker,
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
      enforceFixed: enforceFixed ?? this.enforceFixed,
      templateMatched: templateMatched ?? this.templateMatched,
      focusedWorker: focusedWorker ?? this.focusedWorker,
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

  /// 归一化辅助：去除所有空白（含零宽/不可见字符），用于稳健匹配。
  static String normalize(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').replaceAll('　', '');

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

      final names = result.rows.map((r) => normalize(r.workerName)).toSet();
      final repo = _ref.read(settingsRepositoryProvider);
      final rawDefaultName = repo.getAppSettings().defaultWorkerName.trim();
      final defaultName = normalize(rawDefaultName);

      // 默认姓名即导入目标人：非空且表格里有该姓名时，默认只勾选并仅导入他；
      // 否则默认全选，不强制过滤。匹配使用归一化字符串，兼容空格/不可见字符。
      String? focusedWorker;
      Set<String> selected;
      bool enforce;
      if (defaultName.isNotEmpty && names.contains(defaultName)) {
        focusedWorker = rawDefaultName;
        selected = {focusedWorker};
        enforce = true;
      } else {
        selected = result.rows.map((r) => r.workerName).toSet();
        enforce = false;
      }

      // 模板匹配：同 sheet + 同原始列集合 视为同一格式表
      final tpl = repo.getImportTemplate();
      final fp = importTemplateFingerprint(result.sheetName, result.rawJobColumns);
      final matched = tpl != null &&
          importTemplateFingerprint(tpl.sheetName, tpl.rawColumns) == fp;
      state = state.copyWith(
        loading: false,
        result: result,
        selectedWorkers: selected,
        date: result.date,
        shift: result.shift,
        enforceFixed: enforce,
        focusedWorker: focusedWorker,
        templateMatched: matched,
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
  void setEnforceFixed(bool v) => state = state.copyWith(enforceFixed: v);

  /// 已勾选人员各作业类型车数求和（用于合计对账）。
  Map<String, int> get computedTotals {
    final totals = <String, int>{};
    final result = state.result;
    if (result == null) return totals;
    for (final row in result.rows) {
      if (!state.selectedWorkers.contains(row.workerName)) continue;
      for (final e in row.quantities.entries) {
        totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    return totals;
  }

  /// 与表格合计行不一致的作业类型列名（差异=漏录/错录）。
  List<String> get mismatches {
    final result = state.result;
    if (result?.sheetTotals == null) return [];
    final computed = computedTotals;
    final miss = <String>[];
    result!.sheetTotals!.forEach((col, tableTotal) {
      final got = computed[col] ?? 0;
      if (got != tableTotal) miss.add(col);
    });
    return miss;
  }

  /// 确认导入：先同步作业类型（删旧的默认类 + 加表格清洗出的新类与单价），
  /// 再写入勾选的人员记录；若强匹配开启且设置了默认姓名，则只导入默认姓名对应的记录。
  Future<void> confirm() async {
    final result = state.result;
    if (result == null) return;
    final date = state.date ?? DateTime.now();

    // 1) 同步作业类型：确保表格出现的类型存在并带上价格；
    //    不删除默认类型/已有类型，避免用户设置页自定义的单价被清掉。
    final notifier = _ref.read(unitPricesProvider.notifier);
    final current = Map<String, double>.from(_ref.read(unitPricesProvider));
    for (final col in result.jobColumns) {
      final price = col.price ?? current[col.name] ?? 1.0;
      notifier.add(col.name, price);
    }

    // 2) 构造并写入记录
    final repo = _ref.read(recordRepositoryProvider);
    final settings = _ref.read(settingsRepositoryProvider);
    final defaultName = normalize(settings.getAppSettings().defaultWorkerName);
    bool keep(ImportedRow row) {
      if (!state.selectedWorkers.contains(row.workerName)) return false;
      if (state.enforceFixed && defaultName.isNotEmpty) {
        if (normalize(row.workerName) != defaultName) return false;
      }
      return true;
    }

    // 待导入记录的（人+货场+班次）组合去重，按组合精准删除旧记录：
    // 只清掉同一货场同一班次的旧数据，绝不误删其他货场/班次（多表导入不丢数）。
    final combos = <(String, String?, ShiftType)>{};
    for (final row in result.rows) {
      if (keep(row)) combos.add((row.workerName, row.yard, state.shift));
    }
    for (final (name, yard, shift) in combos) {
      await repo.deleteImportedByWorker(date, name, yard: yard, shift: shift);
    }

    final records = <WorkRecord>[];
    for (final row in result.rows) {
      if (!keep(row)) continue;
      // 加班列的值合并进备注（如「加班：3」），与原有备注用「·」连接。
      String? remark = row.remark;
      if (row.overtime != null && row.overtime!.isNotEmpty) {
        final ot = '加班：${row.overtime}';
        remark = (remark == null || remark.isEmpty) ? ot : '$remark·$ot';
      }
      records.add(WorkRecord(
        // 带船名的挖掘机记录按船分条；铲车记录按 人+货场+班次 一条。
        id: RecordRepository.makeImportId(date, row.workerName,
            yard: row.yard, shift: state.shift, boat: row.boatName),
        date: DateTime(date.year, date.month, date.day),
        workerName: row.workerName,
        vehicleNo: row.vehicleNo,
        shift: state.shift,
        jobQuantities: Map<String, int>.from(row.quantities),
        remark: remark,
        boatName: row.boatName,
        yard: row.yard,
      ));
    }
    await repo.saveImportedRecords(records);

    // 5) 刷新所有记录相关 Provider，让首页/明细页/月报页立刻反映新数据
    _ref.invalidate(historyRecordsProvider);
    _ref.invalidate(lastRecordProvider);
    _ref.invalidate(selectedDateRecordProvider);
    _ref.invalidate(last7DaysSummaryProvider);
    _ref.invalidate(monthlyStatsProvider);
    _ref.invalidate(dayRecordsProvider);

    // 3) 作业类型同步后刷新联动
    _ref.read(unitPricesProvider.notifier).refresh();

    // 4) 记忆本次表格模板（同格式表下次自动识别）
    await settings.saveImportTemplate(ImportTemplate(
      sheetName: result.sheetName,
      headerRow: result.headerRow,
      rawColumns: result.rawJobColumns,
    ));

    state = state.copyWith(done: true, importedCount: records.length);
  }

  /// 供 UI 在 confirm 完成后安全读取导入条数（避免越权访问 protected 的 state）。
  int get lastImportedCount => state.importedCount;

  void reset() => state = ImportUiState();
}

/// 存放「微信/系统分享进来的待导入文件」路径；RootShell 监听后跳转向导并消费置空。
final sharedFileProvider = StateProvider<String?>((ref) => null);

/// 是否为可导入的表格文件（按扩展名过滤，因微信分享 MIME 常为 octet-stream）。
bool isImportableFile(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.xlsx') || p.endsWith('.xls') || p.endsWith('.csv');
}
