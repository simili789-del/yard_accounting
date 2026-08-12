import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/job_types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/salary_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/repository_providers.dart';
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
  String _workerName = '';
  String _vehicleNo = '';
  String _yardName = '45万货场';
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (!_initialized) {
      _workerName = settings.defaultWorkerName;
      _vehicleNo = settings.defaultVehicleNo;
      _yardName = settings.yardName;
      _initialized = true;
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
                  initialValue: _workerName,
                  onChanged: (v) => _workerName = v,
                ),
                const SizedBox(height: 12),
                _SettingsTextField(
                  label: '默认车号',
                  initialValue: _vehicleNo,
                  onChanged: (v) => _vehicleNo = v,
                ),
                const SizedBox(height: 12),
                _SettingsTextField(
                  label: '货场名称',
                  initialValue: _yardName,
                  onChanged: (v) => _yardName = v,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final notifier = ref.read(appSettingsProvider.notifier);
                      notifier.updateDefaultWorkerName(_workerName.trim());
                      notifier.updateDefaultVehicleNo(_vehicleNo.trim());
                      notifier.updateYardName(_yardName.trim());
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
  @override
  Widget build(BuildContext context) {
    final unitPrices = ref.watch(unitPricesProvider);
    final entries = unitPrices.entries.toList();

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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('暂无作业类型，可在下方添加',
                        style: TextStyle(color: Colors.grey)),
                  ),
                for (final e in entries)
                  Padding(
                    key: ValueKey(e.key),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: DefaultJobTypes.colorOf(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: e.key,
                            decoration: const InputDecoration(
                              hintText: '作业类型',
                            ),
                            onFieldSubmitted: (v) {
                              final newName = v.trim();
                              if (newName.isNotEmpty && newName != e.key) {
                                ref
                                    .read(unitPricesProvider.notifier)
                                    .rename(e.key, newName);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: e.value.toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            onFieldSubmitted: (v) {
                              final price = double.tryParse(v) ?? e.value;
                              ref
                                  .read(unitPricesProvider.notifier)
                                  .setPrice(e.key, price);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              ref.read(unitPricesProvider.notifier).remove(e.key),
                        ),
                      ],
                    ),
                  ),
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
            const Text('新增作业类型',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: '类型名称',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      hintText: '单价',
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
                const Text('主题颜色'),
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
                    const Expanded(child: Text('隐藏金额')),
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
                    const Expanded(child: Text('深色模式')),
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
  int _dailyTarget = 100;
  int _monthlyTarget = 2500;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (!_initialized) {
      _dailyTarget = settings.dailyTargetVehicles;
      _monthlyTarget = settings.monthlyTargetVehicles;
      _initialized = true;
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
                  initialValue: '$_dailyTarget',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _dailyTarget = int.tryParse(v) ?? _dailyTarget,
                ),
                const SizedBox(height: 12),
                _SettingsTextField(
                  label: '每月目标车数',
                  initialValue: '$_monthlyTarget',
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      _monthlyTarget = int.tryParse(v) ?? _monthlyTarget,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final notifier = ref.read(appSettingsProvider.notifier);
                      notifier.updateDailyTarget(_dailyTarget);
                      notifier.updateMonthlyTarget(_monthlyTarget);
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

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onPressed: () => _showSnack(context, '导出 JSON 备份功能开发中'),
                ),
                _BackupButton(
                  label: '从 JSON 恢复',
                  onPressed: () => _showSnack(context, '从 JSON 恢复功能开发中'),
                ),
                _BackupButton(
                  label: '从 CSV 导入记录',
                  onPressed: () => _showSnack(context, '从 CSV 导入功能开发中'),
                ),
                _BackupButton(
                  label: '恢复示例数据',
                  onPressed: () => _showSnack(context, '恢复示例数据功能开发中'),
                ),
                _BackupButton(
                  label: '清空全部数据',
                  foregroundColor: Colors.red,
                  onPressed: () => _showSnack(context, '清空全部数据功能开发中'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _BackupButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  const _BackupButton({
    required this.label,
    required this.onPressed,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _SettingsTextField({
    required this.label,
    this.initialValue,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
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
          Expanded(child: Text(label)),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: value.toStringAsFixed(2),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (v) => onChanged(double.tryParse(v) ?? value),
            ),
          ),
        ],
      ),
    );
  }
}
