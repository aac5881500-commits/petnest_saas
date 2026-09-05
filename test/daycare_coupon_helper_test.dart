// 檔案名稱：test/daycare_coupon_helper_test.dart
// 功能說明：安親優惠券輔助的單元測試（allowCoupon 預設為關閉）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/daycare_coupon_helper.dart';

void main() {
  test('allowCoupon 預設為關閉', () {
    expect(const DaycareSettingsModel().allowCoupon, isFalse);
    expect(
      DaycareSettingsModel.fromMap(const <String, dynamic>{}).allowCoupon,
      isFalse,
    );
  });

  test('住宿券不可用於臨托', () {
    final MemberCouponModel coupon = MemberCouponModel(
      id: 'c1',
      shopId: 's1',
      userId: 'u1',
      name: '免費住宿',
      type: MemberCouponType.freeStay,
      applyTarget: MemberCouponApplyTarget.room,
      source: MemberCouponSource.manual,
      status: MemberCouponStatus.available,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      expireAt: DateTime(2027, 1, 1),
    );
    expect(DaycareCouponHelper.appliesToDaycare(coupon), isFalse);
  });

  test('固定金額優惠券可折臨托總額', () {
    final MemberCouponModel coupon = MemberCouponModel(
      id: 'c2',
      shopId: 's1',
      userId: 'u1',
      name: '折 100',
      type: MemberCouponType.fixedAmount,
      applyTarget: MemberCouponApplyTarget.total,
      source: MemberCouponSource.manual,
      status: MemberCouponStatus.available,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      expireAt: DateTime(2027, 1, 1),
      discountValue: 100,
    );
    expect(DaycareCouponHelper.appliesToDaycare(coupon), isTrue);
    expect(
      DaycareCouponHelper.discountAmount(
        coupon: coupon,
        planAmount: 500,
        extraPetAmount: 0,
        addonAmount: 50,
        surchargeAmount: 0,
        campaignDiscountAmount: 0,
        selectedAddons: const <Map<String, dynamic>>[],
        specialDateAllowsCoupon: true,
      ),
      100,
    );
  });
}
