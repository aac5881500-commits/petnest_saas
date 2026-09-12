// 檔案名稱：test/admin_booking_payment_aside_test.dart
// 功能說明：手機版銀行轉帳隱藏查看完整交易；桌機版仍顯示。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_payment_aside.dart';

Widget _wrap(Widget child, {required double width}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 1100)),
    child: ShopFrontendThemeInherited(
      theme: ShopFrontendTheme.fallback,
      child: MaterialApp(
        home: AdminBookingDetailScope(
          mode: width >= 1024
              ? AdminBookingDetailMode.desktop
              : AdminBookingDetailMode.phone,
          width: width,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _transfer() {
  return <String, dynamic>{
    'shopId': 'shop-a',
    'paymentMethod': 'transfer',
    'totalPrice': 2000,
    'paidAmount': 0,
    'depositAmount': 500,
    'transferImageUrl': 'https://a/img.jpg',
  };
}

void main() {
  testWidgets('手機銀行轉帳不顯示查看完整交易，仍顯示回傳照片', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrap(
        AdminBookingDetailPaymentAside(
          data: _transfer(),
          bookingId: 'b1',
        ),
        width: 390,
      ),
    );
    await tester.pump();
    expect(find.text('查看完整交易'), findsNothing);
    expect(find.text('查看付款回傳照片'), findsOneWidget);
  });

  testWidgets('桌機銀行轉帳仍顯示查看完整交易', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrap(
        AdminBookingDetailPaymentAside(
          data: _transfer(),
          bookingId: 'b1',
        ),
        width: 1440,
      ),
    );
    await tester.pump();
    expect(find.text('查看完整交易'), findsOneWidget);
    expect(find.text('查看付款回傳照片'), findsOneWidget);
  });
}
