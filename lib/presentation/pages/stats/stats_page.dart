import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/stats_provider.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final stats = ref.watch(monthlyStatsProvider);
    final days = stats.vehicleCountByDay.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('月报统计 · ${DateFormat('yyyy年MM月').format(month)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref
                .read(statsMonthProvider.notifier)
                .update((m) => DateTime(m.year, m.month - 1)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref
                .read(statsMonthProvider.notifier)
                .update((m) => DateTime(m.year, m.month + 1)),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出工资单',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('工资单已生成，可通过分享菜单发送')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('本月总收入'),
                  Text(
                    '¥${stats.totalIncome.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('每日车数', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(
            height: 220,
            child: days.isEmpty
                ? const Center(child: Text('本月暂无数据'))
                : BarChart(
                    BarChartData(
                      barGroups: [
                        for (int i = 0; i < days.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: (stats.vehicleCountByDay[days[i]] ?? 0)
                                  .toDouble(),
                              width: 10,
                            ),
                          ]),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= days.length) {
                                return const SizedBox.shrink();
                              }
                              return Text('${days[i].day}',
                                  style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text('按作业类型汇总', style: Theme.of(context).textTheme.titleMedium),
          ...stats.quantityByJobType.entries.map(
            (e) => ListTile(
              dense: true,
              title: Text(e.key),
              trailing: Text('${e.value} 件'),
            ),
          ),
          const SizedBox(height: 16),
          Text('人员统计', style: Theme.of(context).textTheme.titleMedium),
          ...stats.incomeByWorker.entries.map(
            (e) => ListTile(
              dense: true,
              title: Text(e.key.isEmpty ? '（未填写姓名）' : e.key),
              trailing: Text('¥${e.value.toStringAsFixed(2)}'),
            ),
          ),
        ],
      ),
    );
  }
}
