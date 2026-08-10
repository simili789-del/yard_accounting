import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/job_types.dart';
import '../../../domain/entities/work_record.dart';
import '../../providers/repository_providers.dart';
import '../../providers/today_record_provider.dart';
import '../../widgets/job_quantity_stepper.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(todayRecordProvider);
    final unitPrices = ref.watch(unitPricesProvider);
    final jobTypes = unitPrices.keys.isNotEmpty
        ? unitPrices.keys.toList()
        : DefaultJobTypes.types;

    return Scaffold(
      appBar: AppBar(
        title: Text('今日记账 · ${DateFormat('MM月dd日').format(DateTime.now())}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: '复制昨日',
            onPressed: () => ref.read(todayRecordProvider.notifier).copyYesterday(),
          ),
        ],
      ),
      body: recordAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('加载失败：$e')),
        data: (record) => _HomeForm(
          record: record,
          jobTypes: jobTypes,
          unitPrices: unitPrices,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.save),
        label: const Text('保存'),
        onPressed: () async {
          await ref.read(todayRecordProvider.notifier).save();
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('已保存今日记账')));
          }
        },
      ),
    );
  }
}

class _HomeForm extends ConsumerWidget {
  final WorkRecord record;
  final List<String> jobTypes;
  final Map<String, double> unitPrices;

  const _HomeForm({
    required this.record,
    required this.jobTypes,
    required this.unitPrices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todayRecordProvider.notifier);
    final totalAmount = record.amount(unitPrices);
    final totalQty =
        record.jobQuantities.values.fold<int>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: record.workerName,
                decoration: const InputDecoration(labelText: '姓名'),
                onChanged: (v) => notifier.updateBasicInfo(workerName: v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: record.vehicleNo,
                decoration: const InputDecoration(labelText: '车号'),
                onChanged: (v) => notifier.updateBasicInfo(vehicleNo: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<ShiftType>(
          segments: const [
            ButtonSegment(value: ShiftType.day, label: Text('白班')),
            ButtonSegment(value: ShiftType.night, label: Text('夜班')),
          ],
          selected: {record.shift},
          onSelectionChanged: (s) => notifier.updateBasicInfo(shift: s.first),
        ),
        const SizedBox(height: 16),
        Text('作业类型', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...jobTypes.map((jobType) => JobQuantityStepper(
              jobType: jobType,
              quantity: record.jobQuantities[jobType] ?? 0,
              unitPrice: unitPrices[jobType] ?? 0,
              onChanged: (delta) => notifier.updateJobQuantity(jobType, delta),
            )),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: record.remark,
          decoration: const InputDecoration(labelText: '备注'),
          maxLines: 2,
          onChanged: notifier.updateRemark,
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('今日摘要', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '共 $totalQty 件 · ¥${totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
