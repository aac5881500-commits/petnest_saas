import '../models/payment_gateway_status.dart';
import '../models/payment_model.dart';
import '../models/store_order_model.dart';

enum StorePaymentRecoveryAction {
  confirmZeroTotal,
  alreadyPaid,
  showPayment,
  createPayment,
  chooseMethod,
  unavailable,
}

class StorePaymentRecoveryPlan {
  const StorePaymentRecoveryPlan(
    this.action, {
    this.payment,
    this.method = '',
    this.message = '',
    this.resetRequest = false,
  });

  final StorePaymentRecoveryAction action;
  final PaymentModel? payment;
  final String method;
  final String message;
  final bool resetRequest;
}

/// 同一商城訂單優先恢復原交易，不以目前付款選項覆蓋原交易方式。
abstract final class StorePaymentRecovery {
  static const _active = {
    'creating',
    'pending',
    'awaiting_payment',
    'processing',
  };
  static const _retryable = {'failed', 'cancelled', 'expired', 'superseded'};

  static bool matchesOrder(PaymentModel payment, StoreOrderModel order) =>
      payment.matchesSource(shopId: order.shopId, storeOrderId: order.id) &&
      payment.userId == order.userId;

  static PaymentModel? selectExisting(
    List<PaymentModel> payments,
    StoreOrderModel order,
  ) {
    final matching = payments.where((p) => matchesOrder(p, order)).toList();
    int priority(PaymentModel p) =>
        p.isPaid ? 2 : (_active.contains(p.status) ? 1 : 0);
    matching.sort((a, b) {
      final rank = priority(b).compareTo(priority(a));
      return rank != 0 ? rank : b.createdAt.compareTo(a.createdAt);
    });
    return matching.isEmpty ? null : matching.first;
  }

  static StorePaymentRecoveryPlan resolve({
    required StoreOrderModel order,
    PaymentModel? payment,
    List<String>? availableMethods,
    String preferredMethod = '',
    DateTime? now,
  }) {
    if (order.isPaid) {
      return const StorePaymentRecoveryPlan(
        StorePaymentRecoveryAction.alreadyPaid,
      );
    }
    if (!order.isPendingPayment) {
      return const StorePaymentRecoveryPlan(
        StorePaymentRecoveryAction.unavailable,
        message: '訂單目前無法付款，請重新確認訂單狀態。',
      );
    }
    if (order.totalAmount == 0) {
      return const StorePaymentRecoveryPlan(
        StorePaymentRecoveryAction.confirmZeroTotal,
      );
    }
    if (payment != null) {
      if (!matchesOrder(payment, order)) {
        return const StorePaymentRecoveryPlan(
          StorePaymentRecoveryAction.unavailable,
          message: '付款資料與訂單不符，請重新載入後再試。',
        );
      }
      if (payment.isPaid) {
        return StorePaymentRecoveryPlan(
          StorePaymentRecoveryAction.alreadyPaid,
          payment: payment,
        );
      }
      if (_active.contains(payment.status)) {
        if (payment.amount != order.totalAmount || !payment.isOnlinePayment) {
          return const StorePaymentRecoveryPlan(
            StorePaymentRecoveryAction.unavailable,
            message: '原付款資料尚待確認，請重新載入訂單或聯絡店家。',
          );
        }
        if (payment.expireAt != null &&
            !payment.expireAt!.isAfter(now ?? DateTime.now())) {
          return const StorePaymentRecoveryPlan(
            StorePaymentRecoveryAction.unavailable,
            message: '原付款已超過期限，請重新載入訂單確認狀態。',
          );
        }
        if (payment.hasOfflinePaymentInfo ||
            payment.paymentHtml.trim().isNotEmpty ||
            payment.status == PaymentTransactionStatus.processing) {
          return StorePaymentRecoveryPlan(
            StorePaymentRecoveryAction.showPayment,
            payment: payment,
            method: payment.paymentMethod,
          );
        }
        return StorePaymentRecoveryPlan(
          StorePaymentRecoveryAction.createPayment,
          payment: payment,
          method: payment.paymentMethod,
        );
      }
      if (!_retryable.contains(payment.status)) {
        return const StorePaymentRecoveryPlan(
          StorePaymentRecoveryAction.unavailable,
          message: '付款狀態尚待確認，請重新載入訂單後再試。',
        );
      }
    }
    if (availableMethods == null) {
      return const StorePaymentRecoveryPlan(
        StorePaymentRecoveryAction.chooseMethod,
      );
    }
    final online = availableMethods
        .where(PaymentMethodType.isOnlinePayment)
        .toList();
    if (online.isEmpty) {
      return const StorePaymentRecoveryPlan(
        StorePaymentRecoveryAction.unavailable,
        message: '店家目前沒有可用的線上付款方式。',
      );
    }
    return StorePaymentRecoveryPlan(
      StorePaymentRecoveryAction.createPayment,
      method: online.contains(preferredMethod) ? preferredMethod : online.first,
      resetRequest: payment != null,
    );
  }
}
