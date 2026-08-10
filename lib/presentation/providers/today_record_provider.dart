import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/record_repository.dart';
import '../../domain/entities/work_record.dart';
import 'repository_providers.dart';

/// “今日记账”模块状态管理：加载今日草稿、增减作业数量、保存、复制昨日。
final todayRecordProvider =
    StateNotifierProvider<TodayRecordNotifier, AsyncValue<WorkRecord>>((ref) {
  final repository = ref.watch(recordRepositoryProvider);
  return TodayRecordNotifier(repository);
});

class TodayRecordNotifier extends StateNotifier<AsyncValue<WorkRecord>> {
  final RecordRepository _repository;

  TodayRecordNotifier(this._repository) : super(const AsyncLoading()) {
    _loadTodayRecord();
  }

  Future<void> _loadTodayRecord() async {
    state = const AsyncLoading();
    try {
      final record = await _repository.getTodayRecord();
      state = AsyncData(record);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void updateBasicInfo(
      {String? workerName, String? vehicleNo, ShiftType? shift, String? boatName}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      workerName: workerName,
      vehicleNo: vehicleNo,
      shift: shift,
      boatName: boatName,
    ));
  }

  void updateJobQuantity(String jobType, int delta) {
    final current = state.value;
    if (current != null) {
      final newQuantities = Map<String, int>.from(current.jobQuantities);
      newQuantities[jobType] = ((newQuantities[jobType] ?? 0) + delta).clamp(0, 9999);
      state = AsyncData(current.copyWith(jobQuantities: newQuantities));
    }
  }

  void updateRemark(String remark) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(remark: remark));
  }

  /// 一键复制昨日数据（姓名/车号/作业数量），保留今日日期。
  Future<void> copyYesterday() async {
    final yesterday = await _repository.getYesterdayRecord();
    final current = state.value;
    if (yesterday == null || current == null) return;
    state = AsyncData(current.copyWith(
      workerName: yesterday.workerName,
      vehicleNo: yesterday.vehicleNo,
      boatName: yesterday.boatName,
      shift: yesterday.shift,
      jobQuantities: Map<String, int>.from(yesterday.jobQuantities),
    ));
  }

  Future<void> save() async {
    final current = state.value;
    if (current == null) return;
    await _repository.saveRecord(current);
    state = AsyncData(current);
  }
}
