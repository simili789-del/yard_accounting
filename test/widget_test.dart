import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yard_accounting/presentation/root_shell.dart';

void main() {
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
