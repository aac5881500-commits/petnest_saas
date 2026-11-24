import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/medication/medication_execution_overview.dart';

void main() {
  final tasks = <Map<String, dynamic>>[
    for (final result in ['done', 'failed', 'skipped', 'pending', 'partial'])
      {
        'id': result,
        'petId': result,
        'result': result,
        'finished': result != 'pending',
        'scheduledAt': '2026-11-15T09:00:00+08:00',
        'note': '備註-$result',
      },
  ];
  for (final width in [390.0, 1000.0]) {
    testWidgets('總覽顯示不同結果與部分成功、可篩選且不溢出 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MedicationExecutionOverview(
                tasks: tasks,
                petName: (id) => '貓咪-$id',
                medicineLabel: (_) => '口服藥',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('成功 1'), findsOneWidget);
      expect(find.text('未成功 1'), findsOneWidget);
      expect(find.text('未執行 1'), findsOneWidget);
      expect(find.text('待補登 1'), findsOneWidget);
      expect(find.text('部分成功 1'), findsOneWidget);
      expect(find.text('共 5 項・尚有 1 項待完成確認'), findsOneWidget);
      expect(find.text('備註-failed'), findsNothing);
      await tester.tap(find.text('未成功 1'));
      await tester.pumpAndSettle();
      expect(find.text('09:00  貓咪-failed'), findsOneWidget);
      expect(find.text('09:00  貓咪-done'), findsNothing);
      expect(find.text('2026/11/15・1 項'), findsOneWidget);
      expect(find.text('填寫結果'), findsNothing);
      await tester.tap(find.text('執行時間與備註'));
      await tester.pumpAndSettle();
      expect(find.text('備註-failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
