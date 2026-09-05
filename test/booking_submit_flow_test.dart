// 檔案名稱：test/booking_submit_flow_test.dart
// 功能說明：住宿付款種類與填寫頁送出錯誤／loading 恢復。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_submit_helper.dart';

Widget _form({
  required Future<void> Function(
    String address,
    String emergencyName,
    String emergencyPhone,
    String relation,
    String emergencyAddress,
    String phone2,
    int depositAmount,
    String paymentMethod,
    String payAmountType,
    TermsConsentSnapshot termsConsent,
  )
  onSubmit,
  int total = 1000,
  String? daycareDepositType,
  int daycareDepositValue = 0,
  int? depositOverrideAmount,
  String service = '住宿',
}) {
  final TextEditingController name = TextEditingController(text: '王小明');
  final TextEditingController phone = TextEditingController(text: '0911111111');
  final TextEditingController note = TextEditingController();
  return MaterialApp(
    home: BookingFormPage(
      shopId: 's',
      skipRemoteLoads: true,
      paymentTestState: BookingFormPaymentTestState.ready,
      daycareDepositType: daycareDepositType,
      daycareDepositValue: daycareDepositValue,
      depositOverrideAmount: depositOverrideAmount,
      seedMemberData: const <String, dynamic>{
        'name': '王小明',
        'phone': '0911111111',
        'address': '台北市大安區仁愛路一段1號',
        'emergencyContact': <String, dynamic>{
          'name': '王媽媽',
          'phone': '0987654321',
          'relation': '父母',
          'address': '台北市大安區仁愛路一段1號',
        },
      },
      onSubmitWithData: onSubmit,
      addons: const <Map<String, dynamic>>[],
      formKey: GlobalKey<FormState>(),
      customerNameController: name,
      customerPhoneController: phone,
      noteController: note,
      serviceTypes: <String>[service],
      selectedServiceType: service,
      onServiceChanged: (_) {},
      onSubmit: () {},
      isSubmitting: false,
      canSubmit: true,
      isBlacklisted: false,
      totalPrice: total,
      roomPrice: total,
    ),
  );
}

Future<void> _selectTransferAndSubmit(WidgetTester tester) async {
  await tester.pump();
  await tester.ensureVisible(find.text('銀行轉帳'));
  await tester.tap(find.text('銀行轉帳'));
  await tester.pump();
  await tester.ensureVisible(find.text('送出預約').last);
  await tester.tap(find.text('送出預約').last);
  await tester.pump();
}

void main() {
  test('到店付款與銀行轉帳不是綠界', () {
    expect(BookingSubmitHelper.isEcpayPayment('cash'), isFalse);
    expect(BookingSubmitHelper.isEcpayPayment('transfer'), isFalse);
  });

  test('信用卡／ATM／超商才走綠界', () {
    expect(BookingSubmitHelper.isEcpayPayment('credit_card'), isTrue);
    expect(BookingSubmitHelper.isEcpayPayment('atm'), isTrue);
    expect(BookingSubmitHelper.isEcpayPayment('cvs_code'), isTrue);
  });

  testWidgets('未選付款時按送出預約仍有提示', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _form(
        onSubmit:
            (
              String address,
              String emergencyName,
              String emergencyPhone,
              String relation,
              String emergencyAddress,
              String phone2,
              int depositAmount,
              String paymentMethod,
              String payAmountType,
              TermsConsentSnapshot termsConsent,
            ) async {},
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('送出預約').last);
    await tester.tap(find.text('送出預約').last);
    await tester.pump();
    expect(find.textContaining('請選擇付款方式'), findsWidgets);
  });

  testWidgets('送出錯誤會顯示訊息且按鈕可再按', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _form(
        onSubmit:
            (
              String address,
              String emergencyName,
              String emergencyPhone,
              String relation,
              String emergencyAddress,
              String phone2,
              int depositAmount,
              String paymentMethod,
              String payAmountType,
              TermsConsentSnapshot termsConsent,
            ) async {
              throw Exception('庫存不足');
            },
      ),
    );
    await _selectTransferAndSubmit(tester);
    expect(find.textContaining('庫存不足'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('送出預約'), findsWidgets);
  });

  testWidgets('固定訂金覆寫住宿比例', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? capturedDeposit;
    await tester.pumpWidget(
      _form(
        total: 1580,
        service: 'daycare',
        daycareDepositType: DaycareDepositTypes.fixed,
        daycareDepositValue: 1000,
        depositOverrideAmount: 1000,
        onSubmit:
            (
              String address,
              String emergencyName,
              String emergencyPhone,
              String relation,
              String emergencyAddress,
              String phone2,
              int depositAmount,
              String paymentMethod,
              String payAmountType,
              TermsConsentSnapshot termsConsent,
            ) async {
              capturedDeposit = depositAmount;
            },
      ),
    );
    await tester.pump();
    expect(find.textContaining('先付訂金 NT\$ 1000'), findsWidgets);
    await _selectTransferAndSubmit(tester);
    expect(capturedDeposit, 1000);
  });
}
