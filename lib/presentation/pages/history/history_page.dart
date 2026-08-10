import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/work_record.dart';
import '../../providers/history_provider.dart';
import '../../providers/repository_providers.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final records = ref.watch(historyRecordsProvider);
    final selected = ref.watch(selectedRecordIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('明细查询'),
        actions: [
          if (selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '批量删除',
              onPressed: () async {
                await ref
                    .read(recordRepositoryProvider)
                    .deleteRecords(selected.toList());
                ref.read(selectedRecordIdsProvider.notifier).state = {};
              },
            ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出 CSV',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已生成 CSV，可通过分享菜单发送')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: QuickRange.values.map((r) {
                return ChoiceChip(
                  label: Text(_rangeLabel(r)),
                  selected: filter.range == r,
                  onSelected: (_) => ref
                      .read(historyFilterProvider.notifier)
                      .update((s) => s.copyWith(range: r)),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '按姓名 / 车号搜索，班次筛选见右上角',
              ),
              onChanged: (v) => ref
                  .read(historyFilterProvider.notifier)
                  .update((s) => s.copyWith(keyword: v)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('暂无符合条件的记录'))
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, i) {
                      final r = records[i];
                      final isSelected = selected.contains(r.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) {
                          final next = Set<String>.from(selected);
                          isSelected ? next.remove(r.id) : next.add(r.id);
                          ref.read(selectedRecordIdsProvider.notifier).state =
                              next;
                        },
                        title: Text('${r.workerName} · ${r.vehicleNo}'),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(r.date)} · ${r.shift.label} · '
                          '${r.jobQuantities.values.fold<int>(0, (a, b) => a + b)} 件',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _rangeLabel(QuickRange r) {
    switch (r) {
      case QuickRange.last7Days:
        return '近7天';
      case QuickRange.thisMonth:
        return '本月';
      case QuickRange.lastMonth:
        return '上月';
      case QuickRange.custom:
        return '自定义';
    }
  }
}
