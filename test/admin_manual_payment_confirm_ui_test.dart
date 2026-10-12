// 檔案名稱：test/admin_manual_payment_confirm_ui_test.dart
// 功能說明：店主訂單操作區實際顯示訂金／全額確認文案與按鈕。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_payment_aside.dart';

Widget _wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1200, 900)),
    child: ShopFrontendThemeInherited(
      theme: ShopFrontendTheme.fallback,
      child: MaterialApp(
        home: AdminBookingDetailScope(
          mode: AdminBookingDetailMode.desktop,
          width: 1200,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _booking({required String payAmountType, int payable = 5000}) {
  return <String, dynamic>{
    'shopId': 'shop-a',
    'status': 'pending',
    'paymentMethod': 'transfer',
    'payAmountType': payAmountType,
    'originalTotal': 5000,
    'totalPrice': payable,
    'depositAmount': 1500,
    'paidAmount': 0,
  };
}

Future<void> _noop() async {}

void main() {
  testWidgets('住宿店主頁訂金顯示確認文案與按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingActionSection(
          data: _booking(payAmountType: 'deposit'),
          status: 'pending',
          depositAmount: 1500,
          depositPaid: false,
          onAssignRoom: _noop,
          onChangeRoom: _noop,
          onConfirmBooking: _noop,
          onConfirmDeposit: _noop,
          onCancelBooking: _noop,
          onCheckIn: _noop,
          onCheckOut: _noop,
        ),
      ),
    );
    expect(find.text('付款類型：訂金'), findsOneWidget);
    expect(find.text('本次確認金額：NT\$ 1500'), findsOneWidget);
    expect(find.text('確認訂金入帳'), findsOneWidget);
    expect(find.text('確認全額入帳'), findsNothing);
  });

  testWidgets('住宿店主頁全額顯示確認文案與按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingActionSection(
          data: _booking(payAmountType: 'full', payable: 4000),
          status: 'pending',
          depositAmount: 1500,
          depositPaid: false,
          onAssignRoom: _noop,
          onChangeRoom: _noop,
          onConfirmBooking: _noop,
          onConfirmDeposit: _noop,
          onCancelBooking: _noop,
          onCheckIn: _noop,
          onCheckOut: _noop,
        ),
      ),
    );
    expect(find.text('付款類型：全額付款'), findsOneWidget);
    expect(find.text('本次確認金額：NT\$ 4000'), findsOneWidget);
    expect(find.text('確認全額入帳'), findsOneWidget);
    expect(find.text('確認訂金入帳'), findsNothing);
    expect(find.text('本次確認金額：NT\$ 1500'), findsNothing);
    expect(find.text('本次確認金額：NT\$ 5000'), findsNothing);
  });

  testWidgets('付款摘要全額顯示本次應付全額而不是訂金', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingDetailPaymentAside(
          data: _booking(payAmountType: 'full', payable: 4000),
          bookingId: 'b1',
        ),
      ),
    );
    expect(find.text('本次應付全額'), findsOneWidget);
    expect(find.text('NT\$ 4000'), findsWidgets);
    expect(find.text('本次應付訂金'), findsNothing);
  });

  testWidgets('安親確認摘要與住宿共用同一元件', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        ManualPaymentConfirmSummary(
          data: <String, dynamic>{
            'bookingKind': 'daycare',
            'status': 'pending',
            'paymentMethod': 'transfer',
            'payAmountType': 'full',
            'totalPrice': 4000,
            'quotedTotalPrice': 4000,
            'originalTotal': 5000,
            'depositAmount': 1500,
            'paidAmount': 0,
            'daycareDepositType': 'fixed',
          },
        ),
      ),
    );
    expect(find.text('付款類型：全額付款'), findsOneWidget);
    expect(find.text('本次確認金額：NT\$ 4000'), findsOneWidget);
  });
}
