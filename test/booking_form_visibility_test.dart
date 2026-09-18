// 檔案名稱：test/booking_form_visibility_test.dart
// 功能說明：客戶送單／手動表單顯示規則與客戶端隔離。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_form_visibility.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daily_care_report_shortcut.dart';

void main() {
  test('客戶自助下單只顯示客戶送單表單', () {
    final Map<String, dynamic> data = <String, dynamic>{'source': 'app'};
    expect(
      BookingFormVisibility.showCustomerSubmitForm(
        data: data,
        hasAnswers: true,
      ),
      isTrue,
    );
    expect(
      BookingFormVisibility.showAdminCreateForm(
        data: data,
        isShopView: true,
        hasAnswers: true,
      ),
      isFalse,
    );
  });

  test('手動建單只顯示手動訂單表單', () {
    final Map<String, dynamic> data = <String, dynamic>{'source': 'admin'};
    expect(
      BookingFormVisibility.showCustomerSubmitForm(
        data: data,
        hasAnswers: true,
      ),
      isFalse,
    );
    expect(
      BookingFormVisibility.showAdminCreateForm(
        data: <String, dynamic>{'source': 'admin'},
        isShopView: true,
        hasAnswers: false,
      ),
      isTrue,
    );
  });

  test('客戶端絕不顯示手動表單與內部交接', () {
    final Map<String, dynamic> data = <String, dynamic>{'source': 'admin'};
    expect(
      BookingFormVisibility.showAdminCreateForm(
        data: data,
        isShopView: false,
        hasAnswers: true,
      ),
      isFalse,
    );
    expect(
      BookingFormVisibility.showInternalHandover(isShopView: false),
      isFalse,
    );
  });

  test('已取消訂單不出現在已回傳付款分類', () {
    expect(
      DaycareStatusLabels.isDepositReview(<String, dynamic>{
        'status': 'cancelled',
        'depositStatus': 'pending_review',
      }),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(<String, dynamic>{
        'status': 'cancelled',
        'depositStatus': 'pending_review',
      }, 'depositReview'),
      isFalse,
    );
    expect(
      DaycareStatusLabels.matchesFilter(<String, dynamic>{
        'status': 'cancelled',
        'depositStatus': 'pending_review',
      }, 'history'),
      isTrue,
    );
  });

  test('有每日照護資格才顯示回報入口，已取消不顯示', () {
    expect(
      AdminDailyCareReportShortcut.shouldShow(<String, dynamic>{
        'status': 'confirmed',
        'dailyCareEntitlement': <String, dynamic>{
          'enabled': true,
          'finalReports': 2,
        },
      }),
      isFalse,
    );
    expect(
      AdminDailyCareReportShortcut.shouldShow(<String, dynamic>{
        'status': 'checked_in',
        'dailyCareEntitlement': <String, dynamic>{
          'enabled': true,
          'finalReports': 2,
        },
      }),
      isTrue,
    );
    expect(
      AdminDailyCareReportShortcut.shouldShow(<String, dynamic>{
        'status': 'cancelled',
        'dailyCareEntitlement': <String, dynamic>{
          'enabled': true,
          'finalReports': 2,
        },
      }),
      isFalse,
    );
    expect(
      AdminDailyCareReportShortcut.shouldShow(<String, dynamic>{
        'status': 'checked_in',
      }),
      isFalse,
    );
  });
}
