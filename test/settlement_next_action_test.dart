// 檔案名稱：test/settlement_next_action_test.dart
// 功能說明：結算下一步只依既有結算結果決定，不再把已退房一律當成重新結算。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/models/settlement_next_action.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_next_action_view.dart';

void main() {
  Map<String, dynamic> stay(String status) {
    return <String, dynamic>{'bookingKind': 'accommodation', 'status': status};
  }

  test('入住中顯示辦理退房，已退房未結算不顯示重新結算', () {
    final SettlementNextAction checkedIn = resolveSettlementNextAction(
      stay('checked_in'),
    );
    expect(checkedIn.kind, SettlementNextActionKind.checkoutOrSettle);
    expect(checkedIn.primaryLabel, '辦理退房／結算');
    expect(checkedIn.primaryLabel.contains('重新結算'), isFalse);

    final SettlementNextAction checkedOut = resolveSettlementNextAction(
      stay('checked_out'),
    );
    expect(checkedOut.primaryLabel, '辦理退房／結算');
    expect(checkedOut.primaryLabel.contains('重新結算'), isFalse);
  });

  test('安親未結束使用安親文案', () {
    final SettlementNextAction action = resolveSettlementNextAction(
      <String, dynamic>{'bookingKind': 'daycare', 'status': 'checked_in'},
    );
    expect(action.primaryLabel, '結算安親／退房');
  });

  test('轉帳待補且未上傳證明時等待客戶付款', () {
    final SettlementNextAction action =
        resolveSettlementNextAction(<String, dynamic>{
          'bookingKind': 'accommodation',
          'status': 'checked_out',
          'settlementConfirmed': true,
          'totalPrice': 1200,
          'paidAmount': 540,
          'settlementTopUpMethod': 'transfer',
          'settlementTopUpStatus': 'awaiting_proof',
        });
    expect(action.kind, SettlementNextActionKind.waitingCustomerPayment);
    expect(action.title, '待補款 NT\$660');
    expect(action.description, '等待客戶上傳轉帳證明');
    expect(action.primaryLabel, '等待客戶付款');
    expect(action.enabled, isFalse);
    expect(action.primaryLabel.contains('重新結算'), isFalse);
    expect(
      action.secondaries,
      contains(SettlementSecondaryAction.switchMethod),
    );
    expect(action.secondaries, contains(SettlementSecondaryAction.adjust));
  });

  test('已上傳付款證明時改為核對客戶回傳', () {
    final SettlementNextAction action =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'checked_out',
          'settlementConfirmed': true,
          'totalPrice': 1200,
          'paidAmount': 540,
          'settlementTopUpMethod': 'transfer',
          'settlementTopUpStatus': 'pending_review',
          'settlementTopUpTransferImageUrl': 'https://example.com/proof.jpg',
        });
    expect(action.kind, SettlementNextActionKind.reviewCustomerProof);
    expect(action.primaryLabel, '核對客戶回傳');
    expect(action.enabled, isTrue);
  });

  test('現金待補款顯示確認已收到款項', () {
    final SettlementNextAction action =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'checked_out',
          'settlementConfirmed': true,
          'totalPrice': 1200,
          'paidAmount': 540,
          'settlementTopUpMethod': 'cash',
        });
    expect(action.kind, SettlementNextActionKind.confirmCashReceived);
    expect(action.primaryLabel, '確認已收到款項 NT\$660');
  });

  test('待退款優先於完成訂單', () {
    final SettlementNextAction action =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'checked_out',
          'settlementConfirmed': true,
          'totalPrice': 100,
          'paidAmount': 400,
        });
    expect(action.kind, SettlementNextActionKind.confirmRefund);
    expect(action.primaryLabel, '確認退款 NT\$300');
  });

  test('帳務歸零且尚未完成時鎖定訂單', () {
    final SettlementNextAction action =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'checked_out',
          'settlementConfirmed': true,
          'totalPrice': 100,
          'paidAmount': 100,
        });
    expect(action.kind, SettlementNextActionKind.finalizeOrder);
    expect(action.primaryLabel, '確認完成並鎖定訂單');
  });

  test('已完成沒有主要按鈕，已取消沒有結算按鈕', () {
    final SettlementNextAction completed =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'completed',
          'settlementConfirmed': true,
          'totalPrice': 100,
          'paidAmount': 100,
        });
    expect(completed.done, isTrue);
    expect(completed.hasPrimary, isFalse);
    expect(completed.title, '✓ 訂單已完成');

    final SettlementNextAction cancelled =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'cancelled',
          'settlementConfirmed': true,
          'totalPrice': 1200,
          'paidAmount': 540,
          'settlementTopUpMethod': 'cash',
        });
    expect(cancelled.visible, isFalse);
    expect(cancelled.hasPrimary, isFalse);
  });

  testWidgets('等待付款的底部列不是重新結算', (WidgetTester tester) async {
    final SettlementNextAction action =
        resolveSettlementNextAction(<String, dynamic>{
          'status': 'checked_out',
          'settlementConfirmed': true,
          'totalPrice': 1200,
          'paidAmount': 540,
          'settlementTopUpMethod': 'transfer',
          'settlementTopUpStatus': 'awaiting_proof',
        });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: SettlementNextActionView(
            action: action,
            shopId: 's',
            bookingId: 'b',
            data: const <String, dynamic>{},
            bar: true,
          ),
        ),
      ),
    );
    expect(find.text('待補款 NT\$660'), findsOneWidget);
    expect(find.text('等待客戶付款'), findsOneWidget);
    expect(find.text('重新結算'), findsNothing);
    expect(find.text('調整結算'), findsOneWidget);
    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '等待客戶付款'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('桌機右欄第一步是下一步', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final SettlementNextAction action = resolveSettlementNextAction(
      stay('checked_in'),
    );
    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: MaterialApp(
          home: AdminBookingDetailScaffold(
            title: '訂單詳細',
            bookingCode: 'B1',
            overview: const SizedBox.shrink(),
            left: const <Widget>[Text('左側長內容')],
            progress: const Text('訂單進度'),
            right: <Widget>[
              SettlementNextActionView(
                key: SettlementNextActionView.slotKey,
                action: action,
                shopId: 's',
                bookingId: 'b',
                data: stay('checked_in'),
              ),
              const Text('住宿結算'),
              const Text('付款摘要'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('辦理退房／結算'), findsOneWidget);
    final double nextTop = tester.getTopLeft(find.text('下一步')).dy;
    final double progressTop = tester.getTopLeft(find.text('訂單進度')).dy;
    expect(nextTop, lessThan(progressTop));
  });
}
