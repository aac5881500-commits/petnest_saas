import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/create_payment_result_model.dart';
import 'package:petnest_saas/core/services/store_checkout_flow.dart';

const _order = StoreCheckoutOrder(id: 'confirmed-order', totalAmount: 180);
const _payment = CreatePaymentResultModel(
  success: true,
  paymentId: 'payment-1',
  paymentMethod: 'credit_card',
  amountType: 'full',
  paymentPurpose: 'full',
  amount: 180,
  status: 'pending',
  paymentHtml: '<form></form>',
);

void main() {
  test('結果未知時保留原送出資料，明確拒絕後才允許修正資料', () async {
    final flow = StoreCheckoutFlow();
    final inputs = <String>[];
    var originalCalls = 0;
    Future<StoreCheckoutOutcome> submit(String input) => flow.run(
      newOrderRequestId: () => 'same-creation',
      createOrder: (_) async {
        inputs.add(input);
        if (input == '原始資料') {
          if (originalCalls++ == 0) throw TimeoutException('結果未知');
          throw ArgumentError('伺服器明確拒絕');
        }
        return _order;
      },
      canEditAfterCreationFailure: (error) => error is ArgumentError,
      clearCart: () async {},
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newPaymentRequestId: () => 'payment-request',
      createPayment: (_, _) async => _payment,
    );
    await expectLater(submit('原始資料'), throwsA(isA<TimeoutException>()));
    expect(flow.hasUnresolvedCreation, isTrue);
    await expectLater(submit('同步更新後的資料'), throwsArgumentError);
    expect(flow.hasUnresolvedCreation, isFalse);
    expect((await submit('修正資料')).order, same(_order));
    expect(inputs, ['原始資料', '原始資料', '修正資料']);
  });

  test('未收到建單回應時，重試沿用同一請求編號供伺服器找回訂單', () async {
    final flow = StoreCheckoutFlow();
    var requestIdsCreated = 0, creates = 0, payments = 0;
    final sentIds = <String>[];
    Future<StoreCheckoutOutcome> submit() => flow.run(
      newOrderRequestId: () => 'checkout-${++requestIdsCreated}',
      createOrder: (requestId) async {
        sentIds.add(requestId);
        if (creates++ == 0) throw TimeoutException('回應遺失');
        return _order;
      },
      clearCart: () async {},
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newPaymentRequestId: () => 'payment-request',
      createPayment: (_, _) async {
        payments++;
        return _payment;
      },
    );
    await expectLater(submit(), throwsA(isA<TimeoutException>()));
    expect(flow.order, isNull);
    expect(payments, 0);
    expect((await submit()).order, same(_order));
    expect(requestIdsCreated, 1);
    expect(sentIds, ['checkout-1', 'checkout-1']);
    expect(payments, 1);
  });

  test('零元訂單經伺服器確認後才完成，不建立任何金流請求', () async {
    final flow = StoreCheckoutFlow();
    var orders = 0, confirms = 0, clears = 0;
    Future<StoreCheckoutOutcome> submit() => flow.run(
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async {
        orders++;
        return const StoreCheckoutOrder(id: 'free-order', totalAmount: 0);
      },
      clearCart: () async {
        clears++;
      },
      confirmZeroTotal: (order) async {
        expect(order.id, 'free-order');
        confirms++;
      },
      newPaymentRequestId: () => throw StateError('不得建立金流請求'),
      createPayment: (_, _) async => throw StateError('不得送往金流'),
    );
    final result = await submit();
    expect(result.zeroTotalConfirmed, isTrue);
    expect(result.payment, isNull);
    expect(result.paymentError, isNull);
    await submit();
    expect(orders, 1);
    expect(confirms, 1);
    expect(clears, 1);
  });

  test('零元確認失敗或連點保留同一訂單，重試不再次扣點', () async {
    final flow = StoreCheckoutFlow();
    var orders = 0, confirms = 0;
    final confirmation = Completer<void>();
    Future<StoreCheckoutOutcome> submit() => flow.run(
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async {
        orders++;
        return const StoreCheckoutOrder(id: 'free-order', totalAmount: 0);
      },
      clearCart: () async {},
      confirmZeroTotal: (_) async {
        if (confirms++ == 0) await confirmation.future;
      },
      newPaymentRequestId: () => throw StateError('不得建立金流請求'),
      createPayment: (_, _) async => throw StateError('不得送往金流'),
    );
    final first = submit();
    expect(submit(), same(first));
    await Future<void>.delayed(Duration.zero);
    confirmation.completeError(StateError('暫時失敗'));
    final failed = await first;
    expect(failed.zeroTotalConfirmed, isFalse);
    expect(failed.paymentError, isA<StateError>());
    final retried = await submit();
    expect(retried.zeroTotalConfirmed, isTrue);
    expect(retried.paymentError, isNull);
    expect(orders, 1);
    expect(confirms, 2);
  });

  test('金流明確回傳失敗不能當成成功，重試沿用請求編號', () async {
    final flow = StoreCheckoutFlow();
    var calls = 0;
    final requests = <String>[];
    Future<StoreCheckoutOutcome> submit() => flow.run(
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async => _order,
      clearCart: () async {},
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newPaymentRequestId: () => 'same-request',
      createPayment: (_, requestId) async {
        requests.add(requestId);
        return calls++ == 0
            ? _payment.copyWith(success: false, message: '拒絕建立付款')
            : _payment;
      },
    );
    final failed = await submit();
    expect(failed.paymentError, isA<StateError>());
    expect(failed.payment, isNull);
    expect((await submit()).payment, same(_payment));
    expect(requests, ['same-request', 'same-request']);
  });

  test('付款失敗保留已成立訂單；重試不再次建單、扣點或保留庫存', () async {
    final flow = StoreCheckoutFlow();
    var orders = 0, clears = 0, requests = 0, payments = 0;
    final requestIds = <String>[];
    Future<StoreCheckoutOutcome> submit() => flow.run(
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async {
        orders++;
        return _order;
      },
      clearCart: () async => clears++,
      newPaymentRequestId: () => 'request-${++requests}',
      createPayment: (order, requestId) async {
        expect(order.id, _order.id);
        requestIds.add(requestId);
        if (payments++ == 0) throw StateError('payment unavailable');
        return _payment;
      },
    );

    final failed = await submit();
    expect(failed.order.id, _order.id);
    expect(failed.paymentError, isA<StateError>());
    expect(flow.order, same(_order));
    final recovered = await submit();
    expect(recovered.payment, same(_payment));
    expect(recovered.paymentError, isNull);
    expect(orders, 1);
    expect(clears, 1);
    expect(requests, 1);
    expect(requestIds, ['request-1', 'request-1']);
  });

  test('購物車清除失敗不會中斷已成立訂單的付款', () async {
    final flow = StoreCheckoutFlow();
    var paidOrder = '';
    final outcome = await flow.run(
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async => _order,
      clearCart: () async => throw StateError('cart unavailable'),
      newPaymentRequestId: () => 'request',
      createPayment: (order, requestId) async {
        paidOrder = order.id;
        return _payment;
      },
    );
    expect(outcome.cartError, isA<StateError>());
    expect(outcome.paymentError, isNull);
    expect(outcome.payment, same(_payment));
    expect(paidOrder, _order.id);
  });

  test('連點送出只執行一次訂單與付款流程', () async {
    final flow = StoreCheckoutFlow();
    final creation = Completer<StoreCheckoutOrder>();
    var orders = 0, payments = 0;
    Future<StoreCheckoutOutcome> submit() => flow.run(
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) {
        orders++;
        return creation.future;
      },
      clearCart: () async {},
      newPaymentRequestId: () => 'request',
      createPayment: (order, requestId) async {
        payments++;
        return _payment;
      },
    );
    final first = submit();
    final second = submit();
    expect(first, same(second));
    creation.complete(_order);
    final results = await Future.wait([first, second]);
    expect(orders, 1);
    expect(payments, 1);
    expect(results[0], same(results[1]));
  });

  test('建立失敗不執行購物車或付款；可在修正後重新送出', () async {
    final flow = StoreCheckoutFlow();
    var orders = 0, clears = 0, payments = 0;
    Future<StoreCheckoutOutcome> submit() => flow.run(
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async {
        if (orders++ == 0) throw StateError('out of stock');
        return _order;
      },
      clearCart: () async => clears++,
      newPaymentRequestId: () => 'request',
      createPayment: (order, requestId) async {
        payments++;
        return _payment;
      },
    );
    await expectLater(submit(), throwsStateError);
    expect(flow.order, isNull);
    expect(clears, 0);
    expect(payments, 0);
    expect((await submit()).payment, same(_payment));
    expect(orders, 2);
  });

  test('付款建立完成後重複呼叫不重建付款', () async {
    final flow = StoreCheckoutFlow();
    var orders = 0, payments = 0;
    Future<StoreCheckoutOutcome> submit() => flow.run(
      confirmZeroTotal: (_) async => fail('正金額不得走零元確認'),
      newOrderRequestId: () => 'order-request',
      createOrder: (requestId) async {
        orders++;
        return _order;
      },
      clearCart: () async {},
      newPaymentRequestId: () => 'request',
      createPayment: (order, requestId) async {
        payments++;
        return _payment;
      },
    );
    await submit();
    await submit();
    expect(orders, 1);
    expect(payments, 1);
  });

  test('金額與訂單編號解析不得默默把無效回傳當成零元訂單', () {
    expect(
      () => StoreCheckoutOrder.fromMap({'orderId': 'id'}),
      throwsFormatException,
    );
    expect(
      () => StoreCheckoutOrder.fromMap({'totalAmount': 180}),
      throwsFormatException,
    );
    expect(
      () => StoreCheckoutOrder.fromMap({'orderId': 'id', 'totalAmount': -1}),
      throwsFormatException,
    );
    expect(
      StoreCheckoutOrder.fromMap({
        'orderId': 'id',
        'totalAmount': 0,
      }).totalAmount,
      0,
    );
  });
}
