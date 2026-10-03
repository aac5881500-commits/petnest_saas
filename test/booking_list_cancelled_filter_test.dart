// 檔案名稱：test/booking_list_cancelled_filter_test.dart
// 功能說明：住宿／安親取消訂單只留在歷史，不進已回傳付款。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';

void main() {
  const Map<String, dynamic> cancelledReview = <String, dynamic>{
    'status': 'cancelled',
    'depositStatus': 'pending_review',
    'bookingKind': 'accommodation',
  };

  test('取消訂單不匹配待確認／已回傳／已確認／待分房', () {
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'pending'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'depositReview'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'confirmed'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'awaitingRoom'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'active'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'settled'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(cancelledReview, 'cancelled'),
      isTrue,
    );
  });

  test('全部只留有效訂單，結清與取消分開', () {
    for (final String kind in <String>['accommodation', 'daycare']) {
      final Map<String, dynamic> pending = <String, dynamic>{
        'bookingKind': kind,
        'status': 'pending',
      };
      final Map<String, dynamic> confirmed = <String, dynamic>{
        'bookingKind': kind,
        'status': 'confirmed',
      };
      final Map<String, dynamic> checkedIn = <String, dynamic>{
        'bookingKind': kind,
        'status': 'checked_in',
      };
      final Map<String, dynamic> completed = <String, dynamic>{
        'bookingKind': kind,
        'status': 'completed',
      };
      final Map<String, dynamic> cancelled = <String, dynamic>{
        'bookingKind': kind,
        'status': 'cancelled',
      };
      final Map<String, dynamic> noShow = <String, dynamic>{
        'bookingKind': kind,
        'status': 'no_show',
      };
      final Map<String, dynamic> checkedOut = <String, dynamic>{
        'bookingKind': kind,
        'status': 'checked_out',
      };

      for (final Map<String, dynamic> active in <Map<String, dynamic>>[
        pending,
        confirmed,
        checkedIn,
        checkedOut,
      ]) {
        expect(DaycareStatusLabels.matchesFilter(active, 'active'), isTrue);
        expect(DaycareStatusLabels.matchesFilter(active, 'settled'), isFalse);
        expect(DaycareStatusLabels.matchesFilter(active, 'cancelled'), isFalse);
      }
      expect(DaycareStatusLabels.matchesFilter(completed, 'active'), isFalse);
      expect(DaycareStatusLabels.matchesFilter(completed, 'settled'), isTrue);
      expect(
        DaycareStatusLabels.matchesFilter(completed, 'cancelled'),
        isFalse,
      );
      expect(DaycareStatusLabels.matchesFilter(cancelled, 'active'), isFalse);
      expect(DaycareStatusLabels.matchesFilter(cancelled, 'settled'), isFalse);
      expect(DaycareStatusLabels.matchesFilter(cancelled, 'cancelled'), isTrue);
      expect(DaycareStatusLabels.matchesFilter(noShow, 'settled'), isFalse);
      expect(DaycareStatusLabels.matchesFilter(noShow, 'cancelled'), isTrue);
      expect(DaycareStatusLabels.matchesFilter(noShow, 'active'), isFalse);
    }
  });

  test('安親已結算但仍待補款留在全部，不進結清', () {
    final Map<String, dynamic> awaiting = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'completed',
      'settlementConfirmed': true,
      'totalPrice': 100,
    };
    expect(DaycareStatusLabels.isHistory(awaiting), isFalse);
    expect(DaycareStatusLabels.matchesFilter(awaiting, 'active'), isTrue);
    expect(DaycareStatusLabels.matchesFilter(awaiting, 'settled'), isFalse);
  });
}
