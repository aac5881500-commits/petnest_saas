// 檔案名稱：test/booking_form_page_test.dart
// 功能說明：住宿填寫預約資料頁：自訂緊急關係與付款狀態不得讓表單消失。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';

Map<String, dynamic> _member({String? relation}) {
  return <String, dynamic>{
    'name': '王小明',
    'phone': '0912345678',
    'address': '台北市大安區仁愛路一段1號',
    'emergencyContact': <String, dynamic>{
      'name': '王媽媽',
      'phone': '0987654321',
      'relation': relation ?? '',
      'address': '台北市大安區仁愛路一段1號',
      'phone2': '',
    },
  };
}

Future<void> _pumpForm(
  WidgetTester tester, {
  Map<String, dynamic>? seed,
  BookingFormPaymentTestState payment = BookingFormPaymentTestState.ready,
}) async {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController note = TextEditingController();
  addTearDown(name.dispose);
  addTearDown(phone.dispose);
  addTearDown(note.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: BookingFormPage(
        shopId: 'shop-test',
        skipRemoteLoads: true,
        seedMemberData: seed,
        paymentTestState: payment,
        onSubmitWithData:
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
        addons: const <Map<String, dynamic>>[],
        formKey: GlobalKey<FormState>(),
        customerNameController: name,
        customerPhoneController: phone,
        noteController: note,
        serviceTypes: const <String>['住宿'],
        selectedServiceType: '住宿',
        onServiceChanged: (_) {},
        onSubmit: () {},
        isSubmitting: false,
        canSubmit: true,
        isBlacklisted: false,
        totalPrice: 1000,
        roomPrice: 1000,
      ),
    ),
  );
  await tester.pump();
}

void _expectFormChrome(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.text('填寫預約資料'), findsOneWidget);
  expect(tester.getSize(find.byType(Form)).height, greaterThan(80));
  expect(find.text('聯絡資料'), findsOneWidget);
  expect(find.text('聯絡人姓名 *'), findsOneWidget);
  expect(find.text('聯絡電話 *'), findsOneWidget);
  expect(find.text('地址'), findsOneWidget);
  expect(find.text('緊急聯絡人'), findsOneWidget);
  expect(find.text('訂單備註'), findsOneWidget);
  expect(find.text('費用與付款'), findsOneWidget);
}

void main() {
  testWidgets('緊急聯絡關係是父母時表單正常顯示', (WidgetTester tester) async {
    await _pumpForm(tester, seed: _member(relation: '父母'));
    _expectFormChrome(tester);
    expect(find.text('父母'), findsWidgets);
  });

  testWidgets('自訂緊急關係家人不會 Dropdown assertion，並顯示其他與原文', (
    WidgetTester tester,
  ) async {
    await _pumpForm(tester, seed: _member(relation: '家人'));
    _expectFormChrome(tester);
    expect(find.text('其他'), findsWidgets);
    expect(find.text('家人'), findsOneWidget);
    expect(find.text('請填寫與飼主關係 *'), findsOneWidget);
  });

  testWidgets('緊急聯絡關係空值時表單正常顯示', (WidgetTester tester) async {
    await _pumpForm(tester, seed: _member(relation: ''));
    _expectFormChrome(tester);
    expect(find.text('請填寫與飼主關係 *'), findsNothing);
  });

  testWidgets('付款設定 loading 時聯絡資料仍顯示', (WidgetTester tester) async {
    await _pumpForm(
      tester,
      seed: _member(relation: '父母'),
      payment: BookingFormPaymentTestState.loading,
    );
    _expectFormChrome(tester);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('付款設定載入失敗時表單仍顯示並有重試', (WidgetTester tester) async {
    await _pumpForm(
      tester,
      seed: _member(relation: '父母'),
      payment: BookingFormPaymentTestState.error,
    );
    _expectFormChrome(tester);
    expect(find.text('付款方式載入失敗'), findsOneWidget);
    expect(find.text('重新載入'), findsOneWidget);
  });

  testWidgets('沒有付款方式時表單仍顯示提示', (WidgetTester tester) async {
    await _pumpForm(
      tester,
      seed: _member(relation: '父母'),
      payment: BookingFormPaymentTestState.empty,
    );
    _expectFormChrome(tester);
    expect(find.text('店家目前尚未設定可用的付款方式，請聯絡店家。'), findsOneWidget);
  });
}
