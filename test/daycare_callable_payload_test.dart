// 檔案名稱：test/daycare_callable_payload_test.dart
// 功能說明：安親 callable payload 僅允許純資料，不含 Timestamp／DateTime。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/daycare_callable_payload.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/utils/callable_payload.dart';

void main() {
  test('toCallableFields 不含 Timestamp', () {
    final TermsConsentSnapshot snapshot = TermsConsentSnapshot(
      termsType: 'daycare',
      termsVersion: 1,
      termsTitle: '安親條款',
      termsAcceptedAt: DateTime.utc(2026, 9, 5, 4),
    );
    final Map<String, dynamic> fields = snapshot.toCallableFields();
    expect(fields['termsAcceptedAt'], '2026-09-05T04:00:00.000Z');
    expect(fields['policyAcceptedAt'], '2026-09-05T04:00:00.000Z');
    expect(snapshot.toBookingFields()['termsAcceptedAt'], isA<Timestamp>());
    CallablePayload.assertValid(fields);
  });

  test('方案 callable snapshot 不含 DateTime', () {
    final DaycarePlanModel plan = DaycarePlanModel(
      id: 'p1',
      name: '每小時計費',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
    expect(plan.toMap()['createdAt'], isA<DateTime>());
    final Map<String, dynamic> snap = plan.toCallableSnapshot();
    expect(snap.containsKey('createdAt'), isFalse);
    expect(snap.containsKey('updatedAt'), isFalse);
    CallablePayload.assertValid(snap);
  });

  test('房型 snapshot 只有純資料', () {
    const DaycareRoomTypeSetting room = DaycareRoomTypeSetting(
      roomTypeId: 'vip',
      basePrice: 880,
      maxBaseCharge: 1500,
    );
    CallablePayload.assertValid(room.toCallableSnapshot());
    expect(room.toCallableSnapshot().keys, <String>[
      'roomTypeId',
      'enabled',
      'includedMinutes',
      'basePrice',
      'extraBillingMinutes',
      'extraBillingPrice',
      'extraPetPrice',
      'maxBaseCharge',
      'maxPets',
    ]);
  });

  test('加值服務 snapshot 不含 Firestore 物件', () {
    final Map<String, dynamic> raw = <String, dynamic>{
      'id': 'photo',
      'name': '每日照片回報',
      'type': 'value',
      'price': 100,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    };
    final Map<String, dynamic> snap = DaycareCallablePayload.addonSnapshot(
      raw,
      amount: 100,
    );
    expect(snap.containsKey('createdAt'), isFalse);
    CallablePayload.assertValid(snap);
  });

  test('房型／時計 payload 通過遞迴型別檢查', () {
    const DaycarePlanModel plan = DaycarePlanModel(
      id: 'hourly',
      name: '每小時計費',
      includedMinutes: 120,
      basePrice: 200,
    );
    const DaycareRoomTypeSetting room = DaycareRoomTypeSetting(
      roomTypeId: 'vip',
      includedMinutes: 300,
      basePrice: 880,
    );
    final TermsConsentSnapshot terms = TermsConsentSnapshot(
      termsType: 'daycare',
      termsVersion: 1,
      termsTitle: '條款',
      termsAcceptedAt: DateTime.utc(2026, 9, 5),
    );
    final Map<String, dynamic> roomPayload = <String, dynamic>{
      'shopId': 'SHOP0001',
      'scheduledStartAt': DateTime.utc(2026, 9, 5, 1).toIso8601String(),
      'pets': <Map<String, dynamic>>[
        DaycareCallablePayload.petSnapshot(<String, dynamic>{
          'petId': 'p1',
          'name': '小白',
          'isNeutered': true,
        }),
      ],
      'daycarePlanPriceSnapshot': <String, dynamic>{},
      'requestedRoomTypePriceSnapshot': room.toCallableSnapshot(),
      'addons': <Map<String, dynamic>>[
        DaycareCallablePayload.addonSnapshot(<String, dynamic>{
          'id': 'a1',
          'name': '分開放風',
          'price': 200,
        }, amount: 200),
      ],
      ...terms.toCallableFields(),
      'depositAmount': 1000,
    };
    CallablePayload.assertValid(roomPayload);
    final Map<String, dynamic> planPayload = <String, dynamic>{
      ...roomPayload,
      'daycarePlanPriceSnapshot': plan.toCallableSnapshot(),
      'requestedRoomTypePriceSnapshot': <String, dynamic>{},
    };
    CallablePayload.assertValid(planPayload);
  });

  test('Timestamp 會指出欄位路徑', () {
    expect(
      CallablePayload.firstInvalidPath(<String, dynamic>{
        'termsAcceptedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }),
      'data.termsAcceptedAt',
    );
  });

  test('固定訂金與 quote 一致', () {
    const DaycareSettingsModel settings = DaycareSettingsModel(
      depositType: DaycareDepositTypes.fixed,
      depositValue: 1000,
    );
    const DaycarePlanModel plan = DaycarePlanModel(
      id: 'p',
      name: '每小時計費',
      includedMinutes: 120,
      basePrice: 200,
      extraBillingMinutes: 30,
      extraBillingPrice: 100,
      extraPetPrice: 100,
      maxBaseCharge: 1000,
    );
    final DaycareQuote quote = DaycarePricingService.instance.quote(
      settings: settings,
      plan: plan,
      startAt: DateTime(2026, 9, 5, 9),
      endAt: DateTime(2026, 9, 5, 17),
      petCount: 2,
      addonAmount: 400,
      couponAmount: 100,
    );
    expect(quote.depositAmount, 1000);
  });
}
