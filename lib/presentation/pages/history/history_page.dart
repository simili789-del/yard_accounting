import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/work_record.dart';
import '../../providers/history_provider.dart';
import '../../providers/repository_providers.dart';
import 'edit_record_page.dart';

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
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出 CSV',
            onPressed: () => _exportCsv(context, ref, records),
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
                hintText: '按姓名 / 车号搜索',
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
                      return ListTile(
                        leading: isSelected
                            ? Checkbox(
                                value: true,
                                onChanged: (_) =>
                                    _toggleSelect(ref, selected, r.id),
                              )
                            : CircleAvatar(
                                backgroundColor: r.shift == ShiftType.night
                                    ? Colors.indigo.shade100
                                    : Colors.green.shade100,
                                child: Text(r.workerName.isNotEmpty
                                    ? r.workerName[0]
                                    : '?'),
                              ),
                        title: Text('${r.workerName} · ${r.vehicleNo}'),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(r.date)} · ${r.shift.label} · '
                          '${r.jobQuantities.values.fold<int>(0, (a, b) => a + b)} 件',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditRecordPage(record: r),
                            ),
                          );
                          // 返回后刷新列表
                          ref.invalidate(historyRecordsProvider);
                        },
                        onLongPress: () =>
                            _toggleSelect(ref, selected, r.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleSelect(WidgetRef ref, Set<String> selected, String id) {
    final next = Set<String>.from(selected);
    selected.contains(id) ? next.remove(id) : next.add(id);
    ref.read(selectedRecordIdsProvider.notifier).state = next;
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

  void _exportCsv(BuildContext context, WidgetRef ref, List<WorkRecord> records) {
    // TODO: 实现真实CSV导出
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV 导出功能开发中')),
    );
  }
}
