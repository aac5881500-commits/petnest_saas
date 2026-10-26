import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/payment_model.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/services/store_payment_recovery.dart';

final _now = DateTime(2026, 10, 24, 12);

StoreOrderModel order([Map<String, dynamic> overrides = const {}]) =>
    StoreOrderModel.fromMap(
      id: 'order-1',
      data: {
        'shopId': 'shop-1',
        'userId': 'user-1',
        'status': 'pending_payment',
        'paymentStatus': 'unpaid',
        'totalAmount': 180,
        'createdAt': _now,
        ...overrides,
      },
    );

PaymentModel payment([Map<String, dynamic> overrides = const {}]) =>
    PaymentModel.fromMap(
      id: 'payment-1',
      data: {
        'shopId': 'shop-1',
        'userId': 'user-1',
        'sourceType': 'store_order',
        'sourceId': 'order-1',
        'storeOrderId': 'order-1',
        'paymentMethod': 'atm',
        'amount': 180,
        'status': 'awaiting_payment',
        'createdAt': _now,
        'updatedAt': _now,
        ...overrides,
      },
    );

StorePaymentRecoveryPlan resolve(
  PaymentModel? existing, {
  StoreOrderModel? target,
  List<String>? methods,
  String preferred = '',
}) => StorePaymentRecovery.resolve(
  order: target ?? order(),
  payment: existing,
  availableMethods: methods,
  preferredMethod: preferred,
  now: _now,
);

void main() {
  test('ATM 後端新欄位與舊欄位皆可讀取，原帳號不被空白欄位覆蓋', () {
    final expiry = _now.add(const Duration(days: 1));
    final current = payment({
      'atmBankCode': '812',
      'atmVirtualAccount': '',
      'atmAccount': '1234567890123456',
      'atmExpireAt': expiry,
      'paymentHtml': '<form>original</form>',
    });
    expect(current.hasOfflinePaymentInfo, isTrue);
    expect(current.atmVirtualAccount, '1234567890123456');
    expect(current.expireAt, expiry);
    expect(
      current.copyWith(status: 'pending').paymentHtml,
      '<form>original</form>',
    );
    final legacy = payment({
      'atmBankCode': '812',
      'atmVirtualAccount': 'legacy-account',
      'atmAccount': 'new-account',
      'expireAt': expiry,
    });
    expect(legacy.atmVirtualAccount, 'legacy-account');
    expect(legacy.expireAt, expiry);
  });

  test('超商新舊欄位與期限都能解析', () {
    for (final field in ['cvsPaymentCode', 'convenienceStorePaymentCode']) {
      final record = payment({
        'paymentMethod': 'cvs_code',
        field: 'CVS-12345678',
        'cvsExpireAt': _now.add(const Duration(days: 2)),
      });
      expect(record.hasOfflinePaymentInfo, isTrue);
      expect(record.convenienceStorePaymentCode, 'CVS-12345678');
      expect(record.expireAt, _now.add(const Duration(days: 2)));
    }
  });

  for (final method in ['atm', 'cvs_code']) {
    test('原 $method 繳費資訊優先於目前信用卡選項，不重建交易', () {
      final record = payment({
        'paymentMethod': method,
        'atmBankCode': '812',
        'atmAccount': '1234567890123456',
        'cvsPaymentCode': 'CVS-12345678',
        'paymentHtml': '<form>already-submitted</form>',
      });
      final result = resolve(
        record,
        methods: ['credit_card'],
        preferred: 'credit_card',
      );
      expect(result.action, StorePaymentRecoveryAction.showPayment);
      expect(result.method, method);
      expect(result.payment, same(record));
    });
    test('原 $method 尚未取得表單時仍使用原方法恢復', () {
      final result = resolve(
        payment({'paymentMethod': method}),
        methods: ['credit_card'],
      );
      expect(result.action, StorePaymentRecoveryAction.createPayment);
      expect(result.method, method);
      expect(result.resetRequest, isFalse);
    });
  }

  test('尚未送出的信用卡原表單沿用，不重建正常線上付款', () {
    final original = payment({
      'paymentMethod': 'credit_card',
      'paymentHtml': '<form>original</form>',
    });
    final result = resolve(original);
    expect(result.action, StorePaymentRecoveryAction.showPayment);
    expect(result.payment?.paymentHtml, '<form>original</form>');
  });

  test('處理中交易只查看狀態，不能重送表單', () {
    expect(
      resolve(payment({'status': 'processing'})).action,
      StorePaymentRecoveryAction.showPayment,
    );
  });

  for (final invalid in [
    {'shopId': 'another-shop'},
    {'sourceId': 'another-order'},
    {'storeOrderId': 'another-order'},
    {'sourceType': 'booking'},
    {'bookingId': 'another-booking'},
    {'userId': 'another-member'},
  ]) {
    test('不同付款範圍不可被沿用：$invalid', () {
      final result = resolve(payment(invalid), methods: ['credit_card']);
      expect(result.action, StorePaymentRecoveryAction.unavailable);
      expect(result.payment, isNull);
    });
  }

  test('來源只有單一正確別名可以恢復；兩個非空別名必須一致', () {
    expect(
      resolve(payment({'sourceId': ''})).action,
      StorePaymentRecoveryAction.createPayment,
    );
    expect(
      resolve(payment({'storeOrderId': ''})).action,
      StorePaymentRecoveryAction.createPayment,
    );
    expect(
      resolve(payment({'storeOrderId': '', 'sourceId': ''})).action,
      StorePaymentRecoveryAction.unavailable,
    );
  });

  test('既有住宿付款與 sourceId-only 日托都能匹配原來源', () {
    final booking = payment({
      'sourceType': 'booking',
      'bookingId': 'booking-1',
      'sourceId': 'booking-1',
      'storeOrderId': '',
    });
    expect(booking.matchesSource(bookingId: 'booking-1'), isTrue);
    final daycare = booking.copyWith(sourceType: 'daycare', bookingId: '');
    expect(daycare.matchesSource(bookingId: 'booking-1'), isTrue);
    expect(
      daycare
          .copyWith(bookingId: 'other-booking')
          .matchesSource(bookingId: 'booking-1'),
      isFalse,
    );
    expect(
      daycare
          .copyWith(storeOrderId: 'order-1')
          .matchesSource(bookingId: 'booking-1'),
      isFalse,
    );
    expect(daycare.matchesSource(bookingId: 'other-booking'), isFalse);
    expect(
      daycare.matchesSource(shopId: 'another-shop', bookingId: 'booking-1'),
      isFalse,
    );
  });

  for (final status in ['failed', 'expired', 'cancelled', 'superseded']) {
    test('終態 $status 可重新選擇可用方法並重置付款請求', () {
      final result = resolve(
        payment({'status': status}),
        methods: ['credit_card', 'cvs_code'],
        preferred: 'cvs_code',
      );
      expect(result.action, StorePaymentRecoveryAction.createPayment);
      expect(result.method, 'cvs_code');
      expect(result.resetRequest, isTrue);
    });
  }

  test('沒有既有交易時使用結帳偏好；偏好停用才退回第一個線上方法', () {
    expect(resolve(null).action, StorePaymentRecoveryAction.chooseMethod);
    expect(
      resolve(
        null,
        methods: ['cash', 'credit_card', 'atm'],
        preferred: 'atm',
      ).method,
      'atm',
    );
    expect(
      resolve(null, methods: ['cash', 'credit_card'], preferred: 'atm').method,
      'credit_card',
    );
    expect(
      resolve(null, methods: []).action,
      StorePaymentRecoveryAction.unavailable,
    );
  });

  test('付款已成功但訂單串流還未更新時不再要求付款', () {
    expect(
      resolve(payment({'status': 'paid'})).action,
      StorePaymentRecoveryAction.alreadyPaid,
    );
    expect(
      resolve(null, target: order({'paymentStatus': 'paid'})).action,
      StorePaymentRecoveryAction.alreadyPaid,
    );
  });

  test('零元仍走伺服器確認；已取消不可送零元確認', () {
    expect(
      resolve(null, target: order({'totalAmount': 0}), methods: []).action,
      StorePaymentRecoveryAction.confirmZeroTotal,
    );
    expect(
      resolve(
        null,
        target: order({'totalAmount': 0, 'status': 'cancelled'}),
      ).action,
      StorePaymentRecoveryAction.unavailable,
    );
  });

  test('未知狀態、已退款、錯誤金額和逾期的原交易不當作可新增付款', () {
    for (final data in [
      {'status': 'unknown'},
      {'status': 'refunded'},
      {'amount': 1},
      {'expireAt': _now.subtract(const Duration(minutes: 1))},
    ]) {
      expect(
        resolve(payment(data), methods: ['credit_card']).action,
        StorePaymentRecoveryAction.unavailable,
      );
    }
  });

  test('lastPaymentId 空白時挑同來源交易：成功優先、其次原待付款，避開別店', () {
    final terminal = payment({
      'status': 'failed',
      'createdAt': _now.add(const Duration(minutes: 1)),
    });
    final pending = payment({'status': 'pending'});
    final foreign = payment({'shopId': 'other-shop', 'status': 'paid'});
    expect(
      StorePaymentRecovery.selectExisting([
        terminal,
        foreign,
        pending,
      ], order()),
      same(pending),
    );
    final paid = payment({'status': 'paid'});
    expect(
      StorePaymentRecovery.selectExisting([pending, paid], order()),
      same(paid),
    );
    expect(StorePaymentRecovery.selectExisting([foreign], order()), isNull);
  });
}
