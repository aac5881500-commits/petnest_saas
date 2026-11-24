import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/medication/medication_fee_summary.dart';

void main() {
  for (final width in [390.0, 900.0]) {
    testWidgets('顯示後端結果200及原列600差額，非直接沿用預估 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationFeeSummary(
              medication: {
                'tasks': [
                  {'result': 'done', 'finished': true},
                ],
                'advanceAmount': 600,
                'estimate': {'amount': 600},
              },
              loadPreview: () async => {'amount': 200, 'units': 4},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NT\$ 200'), findsOneWidget);
      expect(find.text('用藥費差額：NT\$ -400'), findsOneWidget);
      expect(find.text('原預估用藥費：NT\$ 600'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('尚未補齊不顯示虛構最終金額也不呼叫最終試算', (tester) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicationFeeSummary(
            medication: {
              'tasks': [
                {'result': 'pending', 'finished': false},
              ],
              'advanceAmount': 600,
            },
            loadPreview: () async {
              calls++;
              return {'amount': 600};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('待補齊結果'), findsOneWidget);
    expect(find.text('NT\$ 600'), findsNothing);
  });
  testWidgets('用藥200取代預列600後整單3850及尾款2885', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MedicationFeeSummary(
              booking: {'quotedTotalPrice': 3650, 'paidAmount': 965},
              medication: {
                'tasks': [
                  {'result': 'done', 'finished': true},
                ],
                'advanceAmount': 600,
              },
              loadPreview: () async => {'amount': 200, 'units': 4},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('整張訂單試算：NT\$ 3850'), findsOneWidget);
    expect(find.text('預計還需收：NT\$ 2885'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
