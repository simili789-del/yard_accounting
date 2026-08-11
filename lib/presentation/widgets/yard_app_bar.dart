import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_settings_provider.dart';
import '../providers/repository_providers.dart';

/// 统一顶部栏：Logo + 货场名称 + 日期 + 撤销/主题操作。
class YardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final List<Widget>? actions;

  const YardAppBar({super.key, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final now = DateTime.now();
    const weekDays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final weekDay = weekDays[now.weekday - 1];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '记',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    settings.yardName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${DateFormat('yyyy年M月d日').format(now)} $weekDay',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ...?actions,
            IconButton(
              icon: const Icon(Icons.undo_outlined),
              tooltip: '撤销（功能开发中）',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('撤销功能开发中')),
                );
              },
            ),
            IconButton(
              icon: Icon(
                themeMode == 'dark' ? Icons.dark_mode : Icons.wb_sunny_outlined,
              ),
              tooltip: '切换主题',
              onPressed: () {
                final next = themeMode == 'light'
                    ? 'dark'
                    : themeMode == 'dark'
                        ? 'system'
                        : 'light';
                ref.read(themeModeProvider.notifier).state = next;
                ref.read(settingsRepositoryProvider).setThemeMode(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}
