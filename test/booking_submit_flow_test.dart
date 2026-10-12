// 檔案名稱：test/booking_submit_flow_test.dart
// 功能說明：住宿付款種類與填寫頁送出錯誤／loading 恢復。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/features/booking/models/booking_form_submit_data.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_submit_helper.dart';

Widget _form({
  required Future<void> Function(BookingFormSubmitData data) onSubmit,
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
      _form(onSubmit: (BookingFormSubmitData data) async {}),
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
        onSubmit: (BookingFormSubmitData data) async {
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
        onSubmit: (BookingFormSubmitData data) async {
          capturedDeposit = data.calculatedDeposit;
        },
      ),
    );
    await tester.pump();
    expect(find.textContaining('先付訂金 NT\$ 1000'), findsWidgets);
    await _selectTransferAndSubmit(tester);
    expect(capturedDeposit, 1000);
  });

  test('Firestore permission-denied 不會顯示成庫存權限錯誤', () {
    final FirebaseException error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'The caller does not have permission',
    );

    expect(
      BookingSubmitHelper.userFacingSubmitMessage(
        stage: 'ensure_member',
        error: error,
      ),
      '預約送出失敗，請稍後再試。',
    );
    expect(
      BookingSubmitHelper.userFacingSubmitMessage(
        stage: 'addon_inventory',
        error: const InventoryException('沒有權限執行此庫存操作'),
        bookingStillActive: false,
      ),
      '加購商品處理失敗，這次預約未成立，請重新確認。',
    );
    expect(
      BookingSubmitHelper.userFacingSubmitMessage(
        stage: 'addon_inventory',
        error: const InventoryException('部分加購服務庫存不足，請重新選擇。'),
      ),
      '部分加購服務庫存不足，請重新選擇。',
    );
    expect(
      BookingSubmitHelper.userFacingSubmitMessage(
        stage: 'duplicate_booking',
        error: Exception('該寵物在此日期已有預約，請重新選擇日期或寵物'),
      ),
      '該寵物在此日期已有預約，請重新選擇日期或寵物',
    );
  });

  test('顧客會員回寫只含規則允許的欄位', () {
    final Map<String, dynamic> patch =
        BookingSubmitHelper.customerBookingMemberPatch(
          bookingCount: 1,
          petCount: 2,
          policyVersion: 3,
          policyTitle: '入住須知',
          policyAcceptedAt: '2026-01-01T00:00:00.000Z',
        );

    expect(
      patch.keys.every(BookingSubmitHelper.customerMemberUpdateKeys.contains),
      isTrue,
    );
    expect(patch['bookingCount'], 1);
    expect(patch['policyAccepted'], isTrue);
    expect(patch.containsKey('termsType'), isFalse);
    expect(patch.containsKey('termsVersion'), isFalse);
    expect(patch.containsKey('termsTitle'), isFalse);
    expect(patch.containsKey('consentRecordId'), isFalse);
    expect(patch.containsKey('termsVersionDocumentId'), isFalse);
    expect(patch.containsKey('userId'), isFalse);
    expect(patch.containsKey('blacklisted'), isFalse);
    expect(patch.containsKey('isBlocked'), isFalse);
  });

  test('有效訂單重試沿用原請求，已取消才換新請求', () {
    expect(
      BookingSubmitHelper.shouldKeepBookingRequestId(
        bookingExists: true,
        status: 'pending',
        cancelledAtPresent: false,
      ),
      isTrue,
    );
    expect(
      BookingSubmitHelper.shouldKeepBookingRequestId(
        bookingExists: true,
        status: 'cancelled',
        cancelledAtPresent: true,
      ),
      isFalse,
    );
    expect(
      BookingSubmitHelper.shouldKeepBookingRequestId(
        bookingExists: false,
        status: '',
        cancelledAtPresent: false,
      ),
      isFalse,
    );
  });
}
