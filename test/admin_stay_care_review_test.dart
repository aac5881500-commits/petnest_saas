import 'package:petnest_saas/features/medication/medication_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/admin/widgets/admin_stay_settle_sheet.dart';

Map<String, dynamic> booking({bool pending = true, bool finalized = false}) => {
  'shopId': 's',
  'status': 'checked_in',
  'quotedTotalPrice': 3650,
  'paidAmount': 4250,
  'extraCharges': [
    {'title': '陪玩加購', 'amount': 600},
  ],
  'pets': [
    {'petId': 'p', 'name': '布丁'},
  ],
  'medication': {
    'state': 'confirmed',
    'finalized': finalized,
    'setting': {'mode': 'visit', 'successOnly': true},
    'request': {
      'medicines': [
        {'id': 'm', 'petId': 'p', 'name': '藥', 'type': 'oral'},
      ],
    },
    'tasks': <Map<String, dynamic>>[
      {
        'id': 't',
        'petId': 'p',
        'medicineIds': ['m'],
        'scheduledAt': '2026-11-20T09:00:00+08:00',
        'result': pending ? 'pending' : 'done',
        'finished': !pending,
      },
    ],
  },
};

void main() {
  Future<void> show(
    WidgetTester tester,
    Map<String, dynamic> data, {
    double width = 1440,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminStaySettleSheet(
            shopId: 's',
            bookingId: 'b',
            booking: data,
            asDialog: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final care = find.textContaining('用藥核對・');
    if (care.evaluate().isNotEmpty) {
      await tester.tap(care.first);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('未補登用藥只能開原結果表單，無收費checkbox且不能結算', (tester) async {
    await show(tester, booking());
    expect(find.text('補登結果'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('確認結算'), findsNothing);
    expect(find.text('2026-11-20・1 項待補登'), findsOneWidget);
    await tester.tap(find.text('前往補登與核對'));
    await tester.pumpAndSettle();
    expect(find.text('尚有 1 項用藥未補登，不能結算'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('結果補齊才可核對最終費用', (tester) async {
    await show(tester, booking(pending: false));
    expect(find.text('補登結果'), findsNothing);
    expect(find.text('確認用藥最終費用'), findsOneWidget);
    expect(find.text('確認結算'), findsNothing);
  });
  testWidgets('結果與費用確認後可以結算', (tester) async {
    await show(tester, booking(pending: false, finalized: true));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '確認結算'))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('手機補登入口無溢出', (tester) async {
    await show(tester, booking(), width: 390);
    expect(find.text('補登結果'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('伺服器確認補登後外層立即移除並顯示成功及剩餘數', (tester) async {
    final data = booking();
    await show(tester, data);
    await tester.tap(find.text('補登結果'));
    await tester.pumpAndSettle();
    final panel = tester.widget<BookingMedicationPanel>(
      find.byType(BookingMedicationPanel),
    );
    final medication = Map<String, dynamic>.from(data['medication'] as Map);
    medication['tasks'] = [
      for (final task in medication['tasks'] as List)
        {
          ...Map<String, dynamic>.from(task as Map),
          'finished': true,
          'result': 'done',
        },
    ];
    panel.onTaskRecordSaved!(medication);
    await tester.pump();
    expect(find.text('補登結果'), findsNothing);
    expect(find.textContaining('剩餘 0 項'), findsOneWidget);
    expect(find.textContaining('✓ 已儲存：'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
