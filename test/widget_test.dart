import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:yard_accounting/core/constants/job_types.dart';
import 'package:yard_accounting/domain/entities/salary_settings.dart';
import 'package:yard_accounting/domain/entities/work_record.dart';
import 'package:yard_accounting/presentation/root_shell.dart';

Future<void> main() async {
  // 四大模块页面在 build 时会通过 Riverpod 访问 Hive Box，
  // 因此测试前必须像 main() 一样初始化 Hive 并注册适配器、开箱，
  // 否则 Hive.box() 会抛 HiveError 导致 flutter test 失败、CI 不出包。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
  });

  testWidgets('底部导航包含四大模块入口', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RootShell()),
      ),
    );

    expect(find.text('今日记账'), findsOneWidget);
    expect(find.text('明细查询'), findsOneWidget);
    expect(find.text('月报统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
