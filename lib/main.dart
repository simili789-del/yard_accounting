import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/job_types.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/salary_settings.dart';
import 'domain/entities/work_record.dart';
import 'presentation/providers/repository_providers.dart';
import 'presentation/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ShiftTypeAdapter());
  Hive.registerAdapter(WorkRecordAdapter());
  Hive.registerAdapter(SalarySettingsAdapter());

  await Future.wait([
    Hive.openBox<WorkRecord>(HiveBoxes.records),
    Hive.openBox(HiveBoxes.jobPrices),
    Hive.openBox<SalarySettings>(HiveBoxes.salarySettings),
    Hive.openBox(HiveBoxes.appSettings),
  ]);

  runApp(const ProviderScope(child: YardAccountingApp()));
}

class YardAccountingApp extends ConsumerWidget {
  const YardAccountingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: '货场作业记账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: const RootShell(),
    );
  }
}
