// 檔案名稱：test/member_center_ui_test.dart
// 功能說明：會員中心介面的單元測試（reserved 在使用中，revoked 與 expired 在其他）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/member/widgets/member_list_helpers.dart';

MemberCouponModel _coupon({
  required String id,
  required MemberCouponStatus status,
  DateTime? expireAt,
  DateTime? startAt,
  int usageLimit = 1,
  int usedCount = 0,
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return MemberCouponModel(
    id: id,
    shopId: 'shop',
    userId: 'user',
    name: '券$id',
    type: MemberCouponType.fixedAmount,
    applyTarget: MemberCouponApplyTarget.total,
    source: MemberCouponSource.manual,
    status: status,
    createdAt: now,
    updatedAt: now,
    expireAt: expireAt,
    startAt: startAt,
    usageLimit: usageLimit,
    usedCount: usedCount,
  );
}

MemberPointLogModel _log({
  required int points,
  MemberPointLogType type = MemberPointLogType.bookingEarned,
}) {
  return MemberPointLogModel(
    id: 'l',
    shopId: 's',
    userId: 'u',
    type: type,
    points: points,
    balanceBefore: 0,
    balanceAfter: points,
    reason: 'test',
    operatorUid: '',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('MemberCouponGroups', () {
    test('reserved 在使用中，revoked 與 expired 在其他', () {
      final MemberCouponGroups groups =
          MemberCouponGroups.fromList(<MemberCouponModel>[
            _coupon(id: 'a', status: MemberCouponStatus.available),
            _coupon(id: 'r', status: MemberCouponStatus.reserved),
            _coupon(id: 'u', status: MemberCouponStatus.used),
            _coupon(id: 'v', status: MemberCouponStatus.revoked),
            _coupon(
              id: 'e',
              status: MemberCouponStatus.expired,
              expireAt: DateTime(2020, 1, 1),
            ),
          ]);
      expect(groups.available.map((c) => c.id), <String>['a']);
      expect(groups.reserved.map((c) => c.id), <String>['r']);
      expect(groups.used.map((c) => c.id), <String>['u']);
      expect(groups.other.map((c) => c.id).toList()..sort(), <String>[
        'e',
        'v',
      ]);
    });
  });

  group('MemberPointLogFilter', () {
    test('獲得為正數、使用為負數、過期依 type', () {
      final List<MemberPointLogModel> logs = <MemberPointLogModel>[
        _log(points: 20, type: MemberPointLogType.bookingEarned),
        _log(points: -10, type: MemberPointLogType.rewardExchange),
        _log(points: -5, type: MemberPointLogType.expired),
      ];
      expect(
        MemberPointLogFilter.apply(
          logs: logs,
          filter: MemberPointLogFilter.earned,
        ).single.points,
        20,
      );
      expect(
        MemberPointLogFilter.apply(
          logs: logs,
          filter: MemberPointLogFilter.used,
        ).single.points,
        -10,
      );
      expect(
        MemberPointLogFilter.apply(
          logs: logs,
          filter: MemberPointLogFilter.expired,
        ).single.points,
        -5,
      );
    });

    test('點數增減顏色', () {
      expect(
        20 > 0 ? ShopFrontendTheme.successColor : ShopFrontendTheme.errorColor,
        ShopFrontendTheme.successColor,
      );
      expect(
        -10 > 0 ? ShopFrontendTheme.successColor : ShopFrontendTheme.errorColor,
        ShopFrontendTheme.errorColor,
      );
    });
  });

  group('MemberBookingFilters', () {
    test('進行中包含待確認、已確認、入住中，不含完成與取消', () {
      expect(MemberBookingFilters.matches('active', 'pending'), isTrue);
      expect(MemberBookingFilters.matches('active', 'unpaid'), isTrue);
      expect(MemberBookingFilters.matches('active', 'confirmed'), isTrue);
      expect(MemberBookingFilters.matches('active', 'checked_in'), isTrue);
      expect(MemberBookingFilters.matches('active', 'completed'), isFalse);
      expect(MemberBookingFilters.matches('active', 'cancelled'), isFalse);
      expect(MemberBookingFilters.matches('completed', 'completed'), isTrue);
      expect(MemberBookingFilters.matches('cancelled', 'cancelled'), isTrue);
    });
  });

  group('訂單列表顯示', () {
    test('住宿顯示晚數，安親不顯示臨托或晚', () {
      final BookingDetailViewData stay = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'accommodation',
          'nights': 2,
          'shopName': '喵屋',
        },
        docId: 'stay1',
      );
      expect(stay.durationLabel, '2 晚');
      expect(stay.serviceLabel, '住宿');

      final BookingDetailViewData daycare = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'daycare',
          'startDate': DateTime(2026, 8, 1),
          'endDate': DateTime(2026, 8, 1),
        },
        docId: 'day1',
      );
      expect(daycare.serviceLabel, '安親');
      expect(daycare.serviceLabel.contains('臨托'), isFalse);
      expect(daycare.durationLabel.contains('晚'), isFalse);
      expect(daycare.statusTitle.contains('臨托'), isFalse);
    });

    test('未分房不顯示 ---', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'accommodation',
          'roomTypeName': '套房',
        },
        docId: 'id',
      );
      expect(view.roomAssignmentLabel.contains('---'), isFalse);
      expect(view.roomAssignmentLabel, contains('店家確認後安排房間'));
    });
  });
}
