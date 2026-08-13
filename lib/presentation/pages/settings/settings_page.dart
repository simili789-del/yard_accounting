import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/job_types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/share_file.dart';
import '../../../data/serialization/record_serialization.dart';
import '../../../domain/entities/salary_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/selected_date_record_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/section_header.dart';
import '../../widgets/yard_app_bar.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const YardAppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: const [
          _ProfileSection(),
          _JobTypePriceSection(),
          _SalarySection(),
          _AppearanceSection(),
          _TargetSection(),
          _BackupSection(),
        ],
      ),
    );
  }
}

class _ProfileSection extends ConsumerStatefulWidget {
  const _ProfileSection();

  @override
  ConsumerState<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<_ProfileSection> {
  final _workerCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _yardCtrl = TextEditingController();
  bool _synced = false;

  @override
  void dispose() {
    _workerCtrl.dispose();
    _vehicleCtrl.dispose();
    _yardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    // 仅首次把已保存值填入输入框；之后由用户输入驱动，避免每次重建覆盖光标/输入。
    if (!_synced) {
      _workerCtrl.text = settings.defaultWorkerName;
      _vehicleCtrl.text = settings.defaultVehicleNo;
      _yardCtrl.text = settings.yardName;
      _synced = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('个人信息'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SettingsTextField(
                  label: '默认姓名',
                  controller: _workerCtrl,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).updateDefaultWorkerName(v.trim()),
                ),
                const SizedBox(height: 12),
                _SettingsTextField(
                  label: '默认车号',
                  controller: _vehicleCtrl,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).updateDefaultVehicleNo(v.trim()),
                ),
                const SizedBox(height: 12),
                _SettingsTextField(
                  label: '货场名称',
                  controller: _yardCtrl,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).updateYardName(v.trim()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      // 让首页当前记录重新加载，立即反映默认姓名/车号/货场名
                      ref.invalidate(selectedDateRecordProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('个人信息已保存')),
                      );
                    },
                    child: const Text('保存个人信息'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JobTypePriceSection extends ConsumerStatefulWidget {
  const _JobTypePriceSection();

  @override
  ConsumerState<_JobTypePriceSection> createState() =>
      _JobTypePriceSectionState();
}

class _JobTypePriceSectionState extends ConsumerState<_JobTypePriceSection> {
  /// 每个作业类型对应一个 Controller，用于失焦/外部点击时读取当前输入值。
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  /// 每个作业类型独立的防抖 Timer，避免多个单价框互相取消保存。
  final Map<String, Timer> _priceDebounces = {};

  @override
  void dispose() {
    for (final t in _priceDebounces.values) {
      t.cancel();
    }
    _priceDebounces.clear();
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _savePrice(String jobType, String value) {
    final price = double.tryParse(value);
    if (price == null) return;
    ref.read(unitPricesProvider.notifier).setPrice(jobType, price);
  }

  void _saveName(String oldName, String value) {
    final newName = value.trim();
    if (newName.isEmpty || newName == oldName) return;
    ref.read(unitPricesProvider.notifier).rename(oldName, newName);
  }

  @override
  Widget build(BuildContext context) {
    final unitPrices = ref.watch(unitPricesProvider);
    final entries = unitPrices.entries.toList();

    // 清理已删除作业类型的 Controller / 防抖 Timer，避免内存泄漏。
    final currentKeys = unitPrices.keys.toSet();
    _nameControllers.removeWhere((key, ctrl) {
      if (!currentKeys.contains(key)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });
    _priceControllers.removeWhere((key, ctrl) {
      if (!currentKeys.contains(key)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });
    _priceDebounces.removeWhere((key, timer) {
      if (!currentKeys.contains(key)) {
        timer.cancel();
        return true;
      }
      return false;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('作业类型与单价（元/车）'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('暂无作业类型，可在下方添加',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
                for (final e in entries)
                  Builder(builder: (_) {
                    final jobType = e.key;
                    final price = e.value;
                    final nameCtrl = _nameControllers.putIfAbsent(
                      jobType,
                      () => TextEditingController(text: jobType),
                    );
                    final priceCtrl = _priceControllers.putIfAbsent(
                      jobType,
                      () => TextEditingController(
                          text: price.toStringAsFixed(2)),
                    );

                    return Padding(
                      key: ValueKey(jobType),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: DefaultJobTypes.colorOf(jobType),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: '作业类型',
                                filled: true,
                              ),
                              onFieldSubmitted: (v) => _saveName(jobType, v),
                              onEditingComplete: () =>
                                  _saveName(jobType, nameCtrl.text),
                              onTapOutside: (_) =>
                                  _saveName(jobType, nameCtrl.text),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                labelText: '单价',
                                filled: true,
                              ),
                              onChanged: (v) {
                                _priceDebounces[jobType]?.cancel();
                                _priceDebounces[jobType] = Timer(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (!mounted) return;
                                    _savePrice(jobType, v);
                                    _priceDebounces.remove(jobType);
                                  },
                                );
                              },
                              onFieldSubmitted: (v) {
                                _priceDebounces[jobType]?.cancel();
                                _priceDebounces.remove(jobType);
                                _savePrice(jobType, v);
                              },
                              onEditingComplete: () {
                                _priceDebounces[jobType]?.cancel();
                                _priceDebounces.remove(jobType);
                                _savePrice(jobType, priceCtrl.text);
                              },
                              onTapOutside: (_) {
                                _priceDebounces[jobType]?.cancel();
                                _priceDebounces.remove(jobType);
                                _savePrice(jobType, priceCtrl.text);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => ref
                                .read(unitPricesProvider.notifier)
                                .remove(jobType),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                const _AddJobTypeCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddJobTypeCard extends ConsumerStatefulWidget {
  const _AddJobTypeCard();

  @override
  ConsumerState<_AddJobTypeCard> createState() => _AddJobTypeCardState();
}

class _AddJobTypeCardState extends ConsumerState<_AddJobTypeCard> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增作业类型',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '类型名称',
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: '单价',
                      filled: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  final price = double.tryParse(_priceCtrl.text) ?? 0;
                  if (name.isNotEmpty) {
                    ref.read(unitPricesProvider.notifier).add(name, price);
                    _nameCtrl.clear();
                    _priceCtrl.clear();
                  }
                },
                child: const Text('添加类型'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalarySection extends ConsumerWidget {
  const _SalarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salary = ref.watch(salarySettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('工资构成设置'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _NumberField(
                  label: '基本底薪',
                  value: salary.baseSalary,
                  onChanged: (v) => _update(ref, salary.copyWith(baseSalary: v)),
                ),
                _NumberField(
                  label: '餐补',
                  value: salary.mealAllowance,
                  onChanged: (v) =>
                      _update(ref, salary.copyWith(mealAllowance: v)),
                ),
                _NumberField(
                  label: '加班',
                  value: salary.overtime,
                  onChanged: (v) => _update(ref, salary.copyWith(overtime: v)),
                ),
                _NumberField(
                  label: '工龄/奖金',
                  value: salary.seniorityBonus,
                  onChanged: (v) =>
                      _update(ref, salary.copyWith(seniorityBonus: v)),
                ),
                _NumberField(
                  label: '扣款',
                  value: salary.deduction,
                  onChanged: (v) => _update(ref, salary.copyWith(deduction: v)),
                ),
                const SizedBox(height: 12),
                // 工资构成实时合计（不含计件收入），随输入即时刷新
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('工资构成合计（不含计件）',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const Spacer(),
                      Text('¥${salary.totalSalary(0).toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('工资设置已保存')),
                      );
                    },
                    child: const Text('保存工资设置'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _update(WidgetRef ref, SalarySettings settings) {
    ref.read(salarySettingsProvider.notifier).update(settings);
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('外观设置'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主题颜色',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: List.generate(AppTheme.primaries.length, (i) {
                    final color = AppTheme.primaries[i];
                    final selected = settings.primaryColorIndex == i;
                    return InkWell(
                      onTap: () => ref
                          .read(appSettingsProvider.notifier)
                          .updatePrimaryColorIndex(i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: Text('隐藏金额',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface))),
                    Switch(
                      value: settings.hideAmount,
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .updateHideAmount(v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: Text('深色模式',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface))),
                    Switch(
                      value: themeMode == 'dark',
                      onChanged: (v) {
                        final mode = v ? 'dark' : 'light';
                        ref.read(themeModeProvider.notifier).state = mode;
                        ref
                            .read(settingsRepositoryProvider)
                            .setThemeMode(mode);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetSection extends ConsumerStatefulWidget {
  const _TargetSection();

  @override
  ConsumerState<_TargetSection> createState() => _TargetSectionState();
}

class _TargetSectionState extends ConsumerState<_TargetSection> {
  final _dailyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  bool _synced = false;

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (!_synced) {
      _dailyCtrl.text = settings.dailyTargetVehicles.toString();
      _monthlyCtrl.text = settings.monthlyTargetVehicles.toString();
      _synced = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('目标与参数'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SettingsTextField(
                  label: '每日目标车数',
                  controller: _dailyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => ref
                      .read(appSettingsProvider.notifier)
                      .updateDailyTarget(int.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 12),
                _SettingsTextField(
                  label: '每月目标车数',
                  controller: _monthlyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => ref
                      .read(appSettingsProvider.notifier)
                      .updateMonthlyTarget(int.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref.invalidate(selectedDateRecordProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('目标设置已保存')),
                      );
                    },
                    child: const Text('保存目标设置'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _busy = false;

  String get _stamp {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}'
        '_${n.hour.toString().padLeft(2, '0')}'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String content) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  /// 统一处理「忙碌状态 + 异常捕获」，子任务自行弹出成功提示。
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) _snack('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('数据安全与备份'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _BackupButton(
                  label: '导出 JSON 备份',
                  loading: _busy,
                  onPressed: () => _run(() async {
                    final repo = ref.read(recordRepositoryProvider);
                    final records = repo.getAllRecords();
                    if (records.isEmpty) {
                      if (mounted) _snack('暂无记录可导出');
                      return;
                    }
                    final json = RecordSerialization.toJson(records);
                    await shareTextFile(json, '货场记账备份_$_stamp.json');
                    if (mounted) _snack('已导出 ${records.length} 条记录');
                  }),
                ),
                _BackupButton(
                  label: '从 JSON 恢复',
                  loading: _busy,
                  onPressed: () => _run(() async {
                    final picked = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    final path = picked?.files.single.path;
                    if (path == null) return;
                    final content = await File(path).readAsString();
                    final records = RecordSerialization.fromJson(content);
                    if (records.isEmpty) {
                      if (mounted) _snack('文件中没有有效记录');
                      return;
                    }
                    final ok = await _confirm(
                      '恢复备份',
                      '将用 ${records.length} 条记录覆盖当前全部数据，确定继续？',
                    );
                    if (!ok) return;
                    await ref
                        .read(recordRepositoryProvider)
                        .replaceAllRecords(records);
                    ref.invalidate(historyRecordsProvider);
                    ref.invalidate(lastRecordProvider);
                    ref.invalidate(last7DaysSummaryProvider);
                    ref.invalidate(monthlyStatsProvider);
                    ref.invalidate(dayRecordsProvider);
                    ref.invalidate(selectedDateRecordProvider);
                    if (mounted) _snack('已恢复 ${records.length} 条记录');
                  }),
                ),
                _BackupButton(
                  label: '恢复示例数据',
                  loading: _busy,
                  onPressed: () => _run(() async {
                    final ok = await _confirm(
                      '恢复示例数据',
                      '将写入 3 条示例记录（已存在的日期会被覆盖），确定？',
                    );
                    if (!ok) return;
                    await ref.read(recordRepositoryProvider).seedSampleData();
                    ref.invalidate(historyRecordsProvider);
                    ref.invalidate(lastRecordProvider);
                    ref.invalidate(last7DaysSummaryProvider);
                    ref.invalidate(monthlyStatsProvider);
                    ref.invalidate(dayRecordsProvider);
                    ref.invalidate(selectedDateRecordProvider);
                    if (mounted) _snack('已写入示例数据');
                  }),
                ),
                _BackupButton(
                  label: '清空全部数据',
                  foregroundColor: Theme.of(context).colorScheme.error,
                  loading: _busy,
                  onPressed: () => _run(() async {
                    final ok = await _confirm(
                      '清空全部数据',
                      '将删除所有记账记录，且不可恢复，确定？',
                    );
                    if (!ok) return;
                    await ref.read(recordRepositoryProvider).clearAllRecords();
                    // 刷新所有依赖记录数据的 Provider，确保首页/明细页/统计页均无残留
                    ref.invalidate(historyRecordsProvider);
                    ref.invalidate(lastRecordProvider);
                    ref.invalidate(selectedDateRecordProvider);
                    ref.invalidate(last7DaysSummaryProvider);
                    ref.invalidate(monthlyStatsProvider);
                    ref.invalidate(dayRecordsProvider);
                    if (mounted) _snack('已清空全部数据');
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? foregroundColor;
  final bool loading;

  const _BackupButton({
    required this.label,
    required this.onPressed,
    this.foregroundColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _SettingsTextField({
    required this.label,
    this.initialValue,
    this.controller,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      // controller 与 initialValue 互斥：传 controller 时不再传 initialValue
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
      ),
      onChanged: onChanged,
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                )),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: value.toStringAsFixed(2),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                filled: true,
              ),
              onChanged: (v) => onChanged(double.tryParse(v) ?? value),
            ),
          ),
        ],
      ),
    );
  }
}
