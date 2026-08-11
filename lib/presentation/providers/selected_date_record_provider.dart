import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/record_repository.dart';
import '../../domain/entities/work_record.dart';
import 'app_settings_provider.dart';
import 'repository_providers.dart';

/// 首页当前选中的记账日期。
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 根据选中日期加载/保存记录。
final selectedDateRecordProvider =
    StateNotifierProvider<SelectedDateRecordNotifier, AsyncValue<WorkRecord>>(
        (ref) {
  final repo = ref.watch(recordRepositoryProvider);
  return SelectedDateRecordNotifier(repo, ref);
});

class SelectedDateRecordNotifier
    extends StateNotifier<AsyncValue<WorkRecord>> {
  final RecordRepository _repository;
  final Ref _ref;

  SelectedDateRecordNotifier(this._repository, this._ref)
      : super(const AsyncLoading()) {
    reload();
  }

  DateTime get _date => _ref.read(selectedDateProvider);

  Future<void> reload() async {
    state = const AsyncLoading();
    try {
      final record = await _repository.getRecordByDate(_date);
      final defaults = _ref.read(appSettingsProvider);
      state = AsyncData(record.copyWith(
        workerName: record.workerName.isEmpty && defaults.defaultWorkerName.isNotEmpty
            ? defaults.defaultWorkerName
            : record.workerName,
        vehicleNo: record.vehicleNo.isEmpty && defaults.defaultVehicleNo.isNotEmpty
            ? defaults.defaultVehicleNo
            : record.vehicleNo,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void updateBasicInfo(
      {String? workerName,
      String? vehicleNo,
      ShiftType? shift,
      String? boatName}) {
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
    if (current == null) return;
    final newQuantities = Map<String, int>.from(current.jobQuantities);
    newQuantities[jobType] =
        ((newQuantities[jobType] ?? 0) + delta).clamp(0, 9999);
    state = AsyncData(current.copyWith(jobQuantities: newQuantities));
  }

  void updateRemark(String remark) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(remark: remark));
  }

  /// 一键复制昨日数据到当前选中日期。
  Future<void> copyYesterday() async {
    final yesterday = _date.subtract(const Duration(days: 1));
    final source = await _repository.getRecordByDate(yesterday);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      workerName: source.workerName,
      vehicleNo: source.vehicleNo,
      boatName: source.boatName,
      shift: source.shift,
      jobQuantities: Map<String, int>.from(source.jobQuantities),
    ));
  }

  Future<void> save() async {
    final current = state.value;
    if (current == null) return;
    await _repository.saveRecord(current);
    state = AsyncData(current);
  }
}
