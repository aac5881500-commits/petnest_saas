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
    expect(DaycareStatusLabels.matchesFilter(cancelledReview, 'pending'), isFalse);
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
  });
}
