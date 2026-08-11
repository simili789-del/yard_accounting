import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/job_types.dart';
import '../../../domain/entities/work_record.dart';
import '../../providers/repository_providers.dart';
import '../../providers/selected_date_record_provider.dart';
import '../../widgets/job_type_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/yard_app_bar.dart';
import '../../pages/import/import_wizard_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: YardAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: '导入 Excel',
            onPressed: () async {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['xlsx', 'xls', 'csv'],
              );
              final path = picked?.files.single.path;
              if (path != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ImportWizardPage(filePath: path)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_outlined),
            tooltip: '复制昨日',
            onPressed: () =>
                ref.read(selectedDateRecordProvider.notifier).copyYesterday(),
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(selectedDateRecordProvider);
    final unitPrices = ref.watch(unitPricesProvider);
    final jobTypes = unitPrices.keys.isNotEmpty
        ? unitPrices.keys.toList()
        : DefaultJobTypes.types;
    final selectedDate = ref.watch(selectedDateProvider);

    return recordAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('加载失败：$e')),
      data: (record) => ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SectionHeader('快速记账'),
          _DateSelector(date: selectedDate),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _TextFieldCard(
                    label: '姓名',
                    value: record.workerName,
                    onChanged: (v) => ref
                        .read(selectedDateRecordProvider.notifier)
                        .updateBasicInfo(workerName: v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldCard(
                    label: '车号',
                    value: record.vehicleNo,
                    onChanged: (v) => ref
                        .read(selectedDateRecordProvider.notifier)
                        .updateBasicInfo(vehicleNo: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _TextFieldCard(
              label: '船名（挖掘机绩效等）',
              value: record.boatName ?? '',
              onChanged: (v) => ref
                  .read(selectedDateRecordProvider.notifier)
                  .updateBasicInfo(boatName: v),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<ShiftType>(
              segments: const [
                ButtonSegment(
                  value: ShiftType.day,
                  label: Text('白班'),
                  icon: Icon(Icons.wb_sunny_outlined),
                ),
                ButtonSegment(
                  value: ShiftType.night,
                  label: Text('夜班'),
                  icon: Icon(Icons.nights_stay_outlined),
                ),
              ],
              selected: {record.shift},
              onSelectionChanged: (s) => ref
                  .read(selectedDateRecordProvider.notifier)
                  .updateBasicInfo(shift: s.first),
            ),
          ),
          const SizedBox(height: 8),
          ...jobTypes.map((jobType) => JobTypeCard(
                jobType: jobType,
                quantity: record.jobQuantities[jobType] ?? 0,
                unitPrice: unitPrices[jobType] ?? 0,
                onChanged: (delta) => ref
                    .read(selectedDateRecordProvider.notifier)
                    .updateJobQuantity(jobType, delta),
              )),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextFormField(
              initialValue: record.remark,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '选填',
              ),
              maxLines: 2,
              onChanged: (v) => ref
                  .read(selectedDateRecordProvider.notifier)
                  .updateRemark(v),
            ),
          ),
          const SizedBox(height: 16),
          _SaveButton(record: record, unitPrices: unitPrices),
          const SectionHeader('今日摘要'),
          _SummaryCards(record: record),
          const SectionHeader('今日记录'),
          const _TodayRecordsPlaceholder(),
        ],
      ),
    );
  }
}

class _DateSelector extends ConsumerWidget {
  final DateTime date;

  const _DateSelector({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              ref.read(selectedDateProvider.notifier).state = picked;
              ref.read(selectedDateRecordProvider.notifier).reload();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('yyyy/MM/dd').format(date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _TextFieldCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
      ),
      onChanged: onChanged,
    );
  }
}

class _SaveButton extends ConsumerWidget {
  final WorkRecord record;
  final Map<String, double> unitPrices;

  const _SaveButton({required this.record, required this.unitPrices});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAmount = record.amount(unitPrices);
    final totalQty = record.jobQuantities.values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FilledButton.icon(
        icon: const Icon(Icons.check),
        label: Text('保存 · ¥${totalAmount.toStringAsFixed(2)} · $totalQty车'),
        onPressed: () async {
          await ref.read(selectedDateRecordProvider.notifier).save();
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('已保存')));
          }
        },
      ),
    );
  }
}

class _SummaryCards extends ConsumerWidget {
  final WorkRecord record;

  const _SummaryCards({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitPrices = ref.watch(unitPricesProvider);
    final totalAmount = record.amount(unitPrices);
    final totalQty = record.jobQuantities.values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: '今日车数',
              value: '$totalQty',
              subtitle:
                  '☀白${record.shift == ShiftType.day ? totalQty : 0} · 🌙夜${record.shift == ShiftType.night ? totalQty : 0}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: '今日收入',
              value: '¥${totalAmount.toStringAsFixed(2)}',
              subtitle: '昨日合计 0车 · ¥0.00',
              valueColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayRecordsPlaceholder extends StatelessWidget {
  const _TodayRecordsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          '今天还没有记录',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
        ),
      ),
    );
  }
}
