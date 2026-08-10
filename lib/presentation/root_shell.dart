import 'package:flutter/material.dart';

import 'pages/history/history_page.dart';
import 'pages/home/home_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/stats/stats_page.dart';

/// 四大模块入口：今日记账 / 明细查询 / 月报统计 / 设置管理
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    HistoryPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: '今日记账'),
          NavigationDestination(icon: Icon(Icons.search), label: '明细查询'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '月报统计'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
