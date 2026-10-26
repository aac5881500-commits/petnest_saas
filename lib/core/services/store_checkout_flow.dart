import '../models/create_payment_result_model.dart';

/// The server-confirmed order must survive a later cart or payment failure.
class StoreCheckoutOrder {
  const StoreCheckoutOrder({required this.id, required this.totalAmount});

  final String id;
  final int totalAmount;

  factory StoreCheckoutOrder.fromMap(Map<String, dynamic> data) {
    final id = (data['orderId'] ?? '').toString().trim();
    final amount = data['totalAmount'];
    final total = amount is int ? amount : int.tryParse('$amount');
    if (id.isEmpty || total == null || total < 0) {
      throw const FormatException('商城訂單回傳資料不完整，請先至我的訂單確認。');
    }
    return StoreCheckoutOrder(id: id, totalAmount: total);
  }
}

class StoreCheckoutOutcome {
  const StoreCheckoutOutcome({
    required this.order,
    this.payment,
    this.paymentError,
    this.cartError,
    this.zeroTotalConfirmed = false,
  });

  final StoreCheckoutOrder order;
  final CreatePaymentResultModel? payment;
  final Object? paymentError;
  final Object? cartError;
  final bool zeroTotalConfirmed;
}

/// One checkout page owns one flow. Re-entrancy and payment recovery reuse its
/// confirmed order; cart cleanup cannot turn a confirmed purchase into a retry
/// of createStoreOrder. A stable creation request ID also lets the server return
/// the original order when a committed creation response was lost.
class StoreCheckoutFlow {
  String? _orderRequestId;
  Future<StoreCheckoutOrder> Function(String requestId)? _createOrder;
  bool get hasUnresolvedCreation => _createOrder != null && _order == null;
  StoreCheckoutOrder? _order;
  StoreCheckoutOrder? get order => _order;
  String? _paymentRequestId;
  bool _cartCleared = false;
  CreatePaymentResultModel? _payment;
  bool _zeroTotalConfirmed = false;
  Future<StoreCheckoutOutcome>? _pending;

  Future<StoreCheckoutOutcome> run({
    required String Function() newOrderRequestId,
    required Future<StoreCheckoutOrder> Function(String requestId) createOrder,
    bool Function(Object error)? canEditAfterCreationFailure,
    required Future<void> Function() clearCart,
    required Future<void> Function(StoreCheckoutOrder order) confirmZeroTotal,
    required String Function() newPaymentRequestId,
    required Future<CreatePaymentResultModel> Function(
      StoreCheckoutOrder order,
      String requestId,
    )
    createPayment,
  }) => _pending ??= _run(
    newOrderRequestId: newOrderRequestId,
    createOrder: createOrder,
    canEditAfterCreationFailure: canEditAfterCreationFailure,
    clearCart: clearCart,
    confirmZeroTotal: confirmZeroTotal,
    newPaymentRequestId: newPaymentRequestId,
    createPayment: createPayment,
  );

  Future<StoreCheckoutOutcome> _run({
    required String Function() newOrderRequestId,
    required Future<StoreCheckoutOrder> Function(String requestId) createOrder,
    bool Function(Object error)? canEditAfterCreationFailure,
    required Future<void> Function() clearCart,
    required Future<void> Function(StoreCheckoutOrder order) confirmZeroTotal,
    required String Function() newPaymentRequestId,
    required Future<CreatePaymentResultModel> Function(
      StoreCheckoutOrder order,
      String requestId,
    )
    createPayment,
  }) async {
    try {
      final orderRequestId = _orderRequestId ??= newOrderRequestId();
      if (_order == null) {
        final attempt = _createOrder ??= createOrder;
        try {
          _order = await attempt(orderRequestId);
        } catch (error) {
          if (canEditAfterCreationFailure?.call(error) == true) {
            _createOrder = null;
          }
          rethrow;
        }
      }
      final confirmed = _order!;
      Object? cartError;
      if (!_cartCleared) {
        try {
          await clearCart();
          _cartCleared = true;
        } catch (error) {
          cartError = error;
        }
      }

      Object? paymentError;
      try {
        if (confirmed.totalAmount == 0) {
          if (!_zeroTotalConfirmed) {
            await confirmZeroTotal(confirmed);
            _zeroTotalConfirmed = true;
          }
        } else {
          final requestId = _paymentRequestId ??= newPaymentRequestId();
          _payment ??= await createPayment(confirmed, requestId);
          if (!_payment!.success) {
            final message = _payment!.message;
            _payment = null;
            throw StateError(message.isEmpty ? '付款建立失敗' : message);
          }
        }
      } catch (error) {
        paymentError = error;
      }
      return StoreCheckoutOutcome(
        order: confirmed,
        payment: _payment,
        paymentError: paymentError,
        cartError: cartError,
        zeroTotalConfirmed: _zeroTotalConfirmed,
      );
    } finally {
      _pending = null;
    }
  }
}
