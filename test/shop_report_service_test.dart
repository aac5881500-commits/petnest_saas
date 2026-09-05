// 檔案名稱：test/shop_report_service_test.dart
// 功能說明：店家報表服務的單元測試

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

void main() {
  test('cancelled and pending bookings are not revenue', () {
    expect(ShopReportService.isBookingRevenueStatus('cancelled'), isFalse);
    expect(ShopReportService.isBookingRevenueStatus('pending'), isFalse);
    expect(ShopReportService.isBookingRevenueStatus('confirmed'), isTrue);
    expect(ShopReportService.isBookingRevenueStatus('checked_in'), isTrue);
    expect(ShopReportService.isBookingRevenueStatus('completed'), isTrue);
  });

  test('store pending_payment and cancelled are not revenue', () {
    expect(
      ShopReportService.isStoreRevenueStatus(
        StoreConstants.statusPendingPayment,
      ),
      isFalse,
    );
    expect(
      ShopReportService.isStoreRevenueStatus(StoreConstants.statusCancelled),
      isFalse,
    );
    expect(
      ShopReportService.isStoreRevenueStatus(StoreConstants.statusPaid),
      isTrue,
    );
    expect(
      ShopReportService.isStoreRevenueStatus(StoreConstants.statusCompleted),
      isTrue,
    );
  });

  test('missing surcharge discount coupon are 0', () {
    final money = ShopReportService.bookingMoneyForTest(<String, dynamic>{
      'totalPrice': 1200,
    });
    expect(money.surcharge, 0);
    expect(money.discount, 0);
    expect(money.coupon, 0);
    expect(money.orderAmount, 1200);
  });

  test('room type name uses booking snapshot', () {
    expect(
      ShopReportService.roomTypeNameForTest(<String, dynamic>{
        'roomTypeName': '舊名豪華房',
        'roomType': '新名',
      }),
      '舊名豪華房',
    );
    expect(ShopReportService.roomTypeNameForTest(<String, dynamic>{}), '未指定房型');
  });

  test('addon type labels cover official types', () {
    expect(ShopReportService.addonTypeLabel('time'), '時間加購');
    expect(ShopReportService.addonTypeLabel('value'), '加值服務');
    expect(ShopReportService.addonTypeLabel('custom'), '客製服務');
    expect(ShopReportService.addonTypeLabel('daily_timed'), '每日分時段服務');
    expect(ShopReportService.addonTypeLabel('unknown'), '其他');
  });

  test('finalAmount is preferred over extraFee', () {
    final withFinal = ShopReportService.bookingMoneyForTest(<String, dynamic>{
      'finalAmount': 2000,
      'extraFee': 300,
    });
    expect(withFinal.orderAmount, 2000);

    final withTotal = ShopReportService.bookingMoneyForTest(<String, dynamic>{
      'totalPrice': 2000,
      'extraFee': 300,
    });
    expect(withTotal.orderAmount, 2300);
  });

  test('money and percent format', () {
    expect(ShopReportFormat.money(1234567), 'NT\$ 1,234,567');
    expect(ShopReportFormat.percent(0.25), '25.0%');
  });
}
