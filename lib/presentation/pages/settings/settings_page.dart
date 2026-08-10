import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final unitPrices = settingsRepo.getUnitPrices();
    final salary = settingsRepo.getSalarySettings();
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置管理')),
      body: ListView(
        children: [
          const _SectionHeader('作业类型单价配置'),
          ...unitPrices.entries.map((e) => ListTile(
                title: Text(e.key),
                trailing: SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: e.value.toStringAsFixed(2),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(prefixText: '¥'),
                    onFieldSubmitted: (v) {
                      final price = double.tryParse(v) ?? e.value;
                      settingsRepo.setUnitPrice(e.key, price);
                    },
                  ),
                ),
                onLongPress: () => settingsRepo.removeJobType(e.key),
              )),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新增作业类型'),
            onTap: () => _showAddJobTypeDialog(context, ref),
          ),
          const Divider(),
          const _SectionHeader('工资构成'),
          _NumberField(
            label: '底薪',
            value: salary.baseSalary,
            onChanged: (v) => settingsRepo.saveSalarySettings(
              salary.copyWith(baseSalary: v),
            ),
          ),
          _NumberField(
            label: '餐补',
            value: salary.mealAllowance,
            onChanged: (v) => settingsRepo.saveSalarySettings(
              salary.copyWith(mealAllowance: v),
            ),
          ),
          _NumberField(
            label: '扣款',
            value: salary.deduction,
            onChanged: (v) => settingsRepo.saveSalarySettings(
              salary.copyWith(deduction: v),
            ),
          ),
          const Divider(),
          const _SectionHeader('主题'),
          RadioListTile(
            title: const Text('跟随系统'),
            value: 'system',
            groupValue: themeMode,
            onChanged: (v) => _setTheme(ref, v!),
          ),
          RadioListTile(
            title: const Text('浅色模式'),
            value: 'light',
            groupValue: themeMode,
            onChanged: (v) => _setTheme(ref, v!),
          ),
          RadioListTile(
            title: const Text('深色模式'),
            value: 'dark',
            groupValue: themeMode,
            onChanged: (v) => _setTheme(ref, v!),
          ),
        ],
      ),
    );
  }

  void _setTheme(WidgetRef ref, String mode) {
    ref.read(themeModeProvider.notifier).state = mode;
    ref.read(settingsRepositoryProvider).setThemeMode(mode);
  }

  void _showAddJobTypeDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增作业类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '类型名称'),
            ),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: '单价'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (name.isNotEmpty) {
                ref.read(settingsRepositoryProvider).setUnitPrice(name, price);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
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
    return ListTile(
      title: Text(label),
      trailing: SizedBox(
        width: 120,
        child: TextFormField(
          initialValue: value.toStringAsFixed(2),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '¥'),
          onFieldSubmitted: (v) => onChanged(double.tryParse(v) ?? value),
        ),
      ),
    );
  }
}
