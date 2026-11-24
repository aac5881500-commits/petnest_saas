import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_action_runner.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool refund = false,
    int amount = 3680,
  }) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const runner = SettlementActionRunner(
      shopId: 's',
      bookingId: 'b',
      data: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => refund
                  ? runner.refund(context, amount)
                  : runner.collect(context, amount),
              child: const Text('開啟'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'collection amount is read only while payment method remains selectable',
    (tester) async {
      await open(tester);
      expect(find.text('NT\$ 3680'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('金額如需修改，請先回到「調整結算」。'), findsOneWidget);
      await tester.tap(find.text('店內付款'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('銀行轉帳').last);
      await tester.pumpAndSettle();
      expect(find.text('NT\$ 3680'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('refund keeps fixed amount and preserves other-method note', (
    tester,
  ) async {
    await open(tester, refund: true, amount: 500);
    expect(find.text('NT\$ 500'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.text('現場退款'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('其他退款').last);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(TextField), '其他退款註記');
    expect(find.text('確認已退款'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
