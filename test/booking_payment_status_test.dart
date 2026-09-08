// 檔案名稱：test/booking_payment_status_test.dart
// 功能說明：住宿／安親共用付款狀態：訂金確認 fallback、安親付款期限顯示

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

void main() {
  test('已確認訂金但 paidAmount 缺漏時，已付金額至少為訂金', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'bookingKind': 'daycare',
      'totalPrice': 400,
      'paidAmount': 0,
      'depositAmount': 200,
      'depositPaid': true,
      'depositStatus': 'confirmed',
      'status': 'confirmed',
    };
    expect(BookingPaymentStatus.resolvePaid(data), 200);
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: data,
      docId: 'id',
    );
    expect(view.paidAmount, 200);
    expect(view.remainingAmount, 200);
    expect(view.paymentStatusLabel, '尚有尾款');
    expect(view.paymentTaskComplete, isTrue);
    expect(view.statusTitle, '訂金已確認');
    expect(view.nextStepHint, '已付訂金 NT\$200／尚餘 NT\$200');
    expect(BookingPaymentStatus.latestOrderStatusLabel(data), '訂金已確認');
    expect(
      BookingPaymentStatus.depositPaidSummary(data),
      '已付訂金 NT\$200／尚餘 NT\$200',
    );
  });

  test('安親不收訂金不顯示付款期限', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'bookingKind': 'daycare',
      'daycareDepositType': DaycareDepositTypes.none,
      'depositAmount': 0,
      'depositExpireAt': DateTime(2026, 9, 8, 12),
    };
    expect(BookingPaymentStatus.showPaymentDeadline(data), isFalse);
  });

  test('安親固定訂金尚未付款時本次應付為訂金', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'bookingKind': 'daycare',
      'daycareDepositType': DaycareDepositTypes.fixed,
      'totalPrice': 1000,
      'paidAmount': 0,
      'depositAmount': 500,
      'depositExpireAt': DateTime(2026, 9, 8, 12),
    };
    expect(BookingPaymentStatus.resolveDueNow(data), 500);
    expect(BookingPaymentStatus.showPaymentDeadline(data), isTrue);
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: data,
      docId: 'id',
    );
    expect(view.showDepositDue, isTrue);
    expect(view.dueNowAmount, 500);
  });

  test('安親不收訂金本次應付為 0 且不顯示期限', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'bookingKind': 'daycare',
      'daycareDepositType': DaycareDepositTypes.none,
      'totalPrice': 1000,
      'paidAmount': 0,
      'depositAmount': 0,
    };
    expect(BookingPaymentStatus.resolveDueNow(data), 0);
    expect(BookingPaymentStatus.showPaymentDeadline(data), isFalse);
  });

  test('舊 staff_decide 設定讀成不收訂金', () {
    final DaycareSettingsModel settings = DaycareSettingsModel.fromMap(
      const <String, dynamic>{'depositType': 'staff_decide'},
    );
    expect(settings.depositType, DaycareDepositTypes.none);
  });

  test('住宿未確認訂金時最新訂單仍顯示需支付訂金', () {
    expect(
      BookingPaymentStatus.latestOrderStatusLabel(<String, dynamic>{
        'status': 'pending',
        'depositAmount': 500,
        'depositPaid': false,
      }),
      '需支付訂金',
    );
    expect(
      BookingPaymentStatus.latestOrderStatusLabel(<String, dynamic>{
        'status': 'confirmed',
        'depositPaid': true,
        'depositStatus': 'confirmed',
        'depositAmount': 500,
        'bookingKind': 'accommodation',
      }),
      '已確認',
    );
  });

  test('客戶可變更付款的狀態限制', () {
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'pending',
        'depositStatus': 'unpaid',
        'totalPrice': 1000,
        'paidAmount': 0,
      }),
      isTrue,
    );
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'confirmed',
        'depositStatus': 'pending_review',
        'totalPrice': 1000,
        'paidAmount': 0,
      }),
      isTrue,
    );
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'pending',
        'depositPaid': true,
        'depositStatus': 'confirmed',
        'totalPrice': 1000,
        'paidAmount': 200,
      }),
      isFalse,
    );
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'checked_in',
        'depositStatus': 'unpaid',
        'totalPrice': 1000,
        'paidAmount': 0,
      }),
      isFalse,
    );
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'completed',
        'depositStatus': 'unpaid',
        'totalPrice': 1000,
        'paidAmount': 0,
      }),
      isFalse,
    );
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'cancelled',
        'depositStatus': 'unpaid',
        'totalPrice': 1000,
        'paidAmount': 0,
      }),
      isFalse,
    );
    expect(
      BookingPaymentStatus.canChangePaymentChoice(<String, dynamic>{
        'status': 'confirmed',
        'depositStatus': 'unpaid',
        'totalPrice': 1000,
        'paidAmount': 1000,
      }),
      isFalse,
    );
  });

  test('一次付清時本次應付為尚餘全額，且不覆寫付款期限', () {
    final DateTime expire = DateTime(2026, 9, 8, 12);
    final Map<String, dynamic> data = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'pending',
      'totalPrice': 1000,
      'paidAmount': 0,
      'depositAmount': 300,
      'payAmountType': 'full',
      'depositExpireAt': expire,
    };
    expect(BookingPaymentStatus.resolveDueNow(data), 1000);
    expect(data['depositExpireAt'], expire);
    data['payAmountType'] = 'deposit';
    expect(BookingPaymentStatus.resolveDueNow(data), 300);
    expect(data['depositExpireAt'], expire);
  });
}
