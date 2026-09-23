// 檔案名稱：test/booking_points_callable_test.dart
// 功能說明：點數折抵換算、訂金與 Callable payload 不含 FieldValue。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';
import 'package:petnest_saas/core/utils/callable_payload.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 21, 4);
  final PointSettingModel setting = PointSettingModel(
    shopId: 's1',
    enabled: true,
    amountPerPoint: 100,
    pointExpireDays: 0,
    issueAfterCompleted: true,
    createdAt: now,
    updatedAt: now,
    spendEnabled: true,
    staySpendEnabled: true,
    daycareSpendEnabled: true,
    pointsPerNtd: 10,
  );

  test('住宿全額／部分／優惠券後點數與訂金', () {
    const int afterCoupon = 1000;
    final PointSpendCap all = setting.capSpend(
      requestedPoints: 999999,
      balance: 20000,
      payableAfterCoupon: afterCoupon,
    );
    expect(all.pointAmount, 1000);
    expect(all.pointsUsed, 10000);
    final int payableAll = PointSettingModel.payableAfterPoints(
      afterCoupon: afterCoupon,
      pointAmount: all.pointAmount,
    );
    expect(payableAll, 0);
    expect(_deposit(percent: 30, total: payableAll), 0);

    final PointSpendCap part = setting.capSpend(
      requestedPoints: 300,
      balance: 2000,
      payableAfterCoupon: afterCoupon,
    );
    expect(part.pointAmount, 30);
    expect(part.pointsUsed, 300);
    final int payablePart = PointSettingModel.payableAfterPoints(
      afterCoupon: afterCoupon,
      pointAmount: part.pointAmount,
    );
    expect(payablePart, 970);
    expect(_deposit(percent: 30, total: payablePart), 291);

    const int afterCouponOnly = 80;
    final PointSpendCap after = setting.capSpend(
      requestedPoints: 5000,
      balance: 5000,
      payableAfterCoupon: afterCouponOnly,
    );
    expect(after.pointAmount, 80);
    expect(after.pointsUsed, 800);
  });

  test('安親不可把點數餘額當台幣，折抵後總額與訂金正確', () {
    final PointSpendCap spend = setting.capSpend(
      requestedPoints: 100,
      balance: 100,
      payableAfterCoupon: 500,
    );
    expect(spend.pointAmount, isNot(100));
    expect(spend.pointAmount, 10);
    expect(spend.pointsUsed, 100);
    final int payable = PointSettingModel.payableAfterPoints(
      afterCoupon: 500,
      pointAmount: spend.pointAmount,
    );
    expect(payable, 490);
    expect(_deposit(percent: 50, total: payable), 245);
  });

  test('點數不足與超過上限會被 cap', () {
    final PointSpendCap low = setting.capSpend(
      requestedPoints: 500,
      balance: 20,
      payableAfterCoupon: 1000,
    );
    expect(low.pointsUsed, 20);
    expect(low.pointAmount, 2);
    final PointSpendCap over = setting.capSpend(
      requestedPoints: 999999,
      balance: 100,
      payableAfterCoupon: 3,
    );
    expect(over.pointAmount, 3);
    expect(over.pointsUsed, 30);
  });

  test('customFormAnswers.toCallableMap 不含 FieldValue 且 submittedAt 為 ISO', () {
    final CustomFormAnswerSnapshot snapshot = CustomFormAnswerSnapshot(
      formId: 'booking_submit',
      formType: 'booking_submit',
      formVersion: 1,
      formTitle: '預約資料',
      submittedAt: now,
      answers: const <CustomFormAnswerItem>[],
    );
    final Map<String, dynamic> payload = <String, dynamic>{
      'booking': <String, dynamic>{
        'customFormAnswers': snapshot.toCallableMap(),
      },
      'requestedPoints': 40,
    };
    expect(CallablePayload.isAllowedValue(payload), isTrue);
    expect(
      payload['booking']['customFormAnswers']['submittedAt'],
      isA<String>(),
    );
    expect(
      payload['booking']['customFormAnswers']['submittedAt'],
      '2026-09-21T04:00:00.000Z',
    );
  });
}

int _deposit({required int percent, required int total}) {
  final int value = (total * percent / 100).round();
  if (value < 0) {
    return 0;
  }
  if (value > total) {
    return total;
  }
  return value;
}
