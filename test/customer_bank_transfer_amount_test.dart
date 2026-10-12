// 檔案名稱：test/customer_bank_transfer_amount_test.dart
// 功能說明：客戶銀行轉帳畫面顯示本次應轉金額，全額用最終應付。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_finance_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

Widget _wrap(Widget child) {
  return ShopFrontendThemeInherited(
    theme: ShopFrontendTheme.fallback,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Map<String, dynamic> _booking({required String payAmountType}) {
  return <String, dynamic>{
    'status': 'pending',
    'paymentMethod': 'transfer',
    'payAmountType': payAmountType,
    'originalTotal': 5000,
    'discountAmount': 500,
    'pointAmount': 500,
    'totalPrice': 4000,
    'depositAmount': 1500,
    'paidAmount': 0,
    'bankName': '測試銀行',
    'accountName': '店家',
    'accountNumber': '123',
  };
}

void main() {
  Future<void> pumpTall(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(child));
  }

  testWidgets('銀行轉帳訂金應轉訂金金額', (WidgetTester tester) async {
    final Map<String, dynamic> data = _booking(payAmountType: 'deposit');
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: data,
      docId: 'b1',
    );
    expect(view.dueNowAmount, 1500);
    expect(BookingPaymentStatus.initialPaymentChoice(data).purpose, 'deposit');
    final TextEditingController last5 = TextEditingController();
    addTearDown(last5.dispose);
    await pumpTall(
      tester,
      BookingDetailFinanceSection(
          view: view,
          bookingId: 'b1',
          shopFlags: const BookingDetailShopPaymentFlags(
            catalog: ShopPaymentCatalog(
              methods: <ShopPaymentMethodOption>[],
              isDepositMode: true,
              serviceType: 'stay',
            ),
          ),
          last5Controller: last5,
          loading: false,
          creatingPayment: false,
          onUploadImage: () {},
          onSubmitDeposit: () {},
          onDeleteTransferImage: (_) {},
          onPayOnline: () {},
      ),
    );
    expect(find.text('本次應付訂金'), findsOneWidget);
    expect(find.text('NT\$ 1500'), findsWidgets);
    expect(find.text('本次應付全額'), findsNothing);
    expect(find.text('銀行轉帳'), findsWidgets);
  });

  testWidgets('銀行轉帳全額應轉最終應付，不是原價或訂金', (WidgetTester tester) async {
    final Map<String, dynamic> data = _booking(payAmountType: 'full');
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: data,
      docId: 'b1',
    );
    expect(view.dueNowAmount, 4000);
    expect(view.payAmountType, 'full');
    expect(BookingPaymentStatus.initialPaymentChoice(data).purpose, 'full');
    expect(BookingPaymentStatus.initialPaymentChoice(data).amount, 4000);
    final TextEditingController last5 = TextEditingController();
    addTearDown(last5.dispose);
    await pumpTall(
      tester,
      BookingDetailFinanceSection(
          view: view,
          bookingId: 'b1',
          shopFlags: const BookingDetailShopPaymentFlags(
            catalog: ShopPaymentCatalog(
              methods: <ShopPaymentMethodOption>[],
              isDepositMode: false,
              serviceType: 'stay',
            ),
          ),
          last5Controller: last5,
          loading: false,
          creatingPayment: false,
          onUploadImage: () {},
          onSubmitDeposit: () {},
          onDeleteTransferImage: (_) {},
          onPayOnline: () {},
      ),
    );
    expect(find.text('本次應付全額'), findsOneWidget);
    expect(find.text('NT\$ 4000'), findsWidgets);
    expect(find.text('本次應付訂金'), findsNothing);
    expect(find.text('NT\$ 5000'), findsNothing);
    expect(find.text('NT\$ 1500'), findsNothing);
  });
}
