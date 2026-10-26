// 檔案名稱：lib/features/payment/pages/ecpay_payment_page.dart
// 功能說明：依執行平台自動使用 Android／iOS WebView 或 Web iframe
// 🌐 綠界付款頁
// 載入 Cloud Function 回傳的綠界付款 HTML，
// 並即時監聽目前 Payment 的付款狀態。
// 當付款成功、失敗、取消或逾期時，自動導回對應的訂單詳情。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/payment_model.dart';
import 'package:petnest_saas/core/services/payment_service.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/payment/widgets/ecpay_payment_view.dart';
import 'package:petnest_saas/features/payment/widgets/ecpay_payment_information.dart';
import 'package:petnest_saas/features/shop/pages/storefront/my_store_order_detail_page.dart';

class EcpayPaymentPage extends StatefulWidget {
  const EcpayPaymentPage({
    super.key,
    required this.paymentHtml,
    required this.paymentId,
    this.bookingId = '',
    this.shopId = '',
    this.storeOrderId = '',
    this.initialPayment,
  });

  /// Cloud Function 回傳的綠界付款表單 HTML
  final String paymentHtml;

  /// 對應 payments/{paymentId}
  ///
  /// 用來即時監聽這筆 Payment 的付款狀態。
  final String paymentId;

  /// 對應 bookings/{bookingId}
  ///
  /// 住宿付款完成、失敗、取消或逾期後，
  /// 用來導回正確的訂單詳情。
  final String bookingId;

  /// 商城付款所屬店家
  final String shopId;

  /// 商城訂單 ID。有值時付款完成導向商城訂單詳情。
  final String storeOrderId;

  final PaymentModel? initialPayment;

  @override
  State<EcpayPaymentPage> createState() => _EcpayPaymentPageState();
}

class _EcpayPaymentPageState extends State<EcpayPaymentPage> {
  StreamSubscription<PaymentModel?>? _paymentSubscription;

  /// 避免 Firestore 連續更新時重複觸發 Navigator。
  bool _leavingPaymentPage = false;
  PaymentModel? _payment;
  String? _paymentError;
  bool _loadingPayment = true;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialPayment;
    if (initial != null && _matchesPayment(initial)) {
      _payment = initial;
      _loadingPayment = false;
    }
    _listenToPayment();
  }

  bool _matchesPayment(PaymentModel payment) =>
      payment.id == widget.paymentId &&
      payment.matchesSource(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        storeOrderId: widget.storeOrderId,
      );

  void _listenToPayment() {
    _paymentSubscription?.cancel();
    _paymentSubscription = PaymentService.instance
        .streamPayment(widget.paymentId)
        .listen(
          (payment) {
            if (!mounted) return;
            if (payment == null || !_matchesPayment(payment)) {
              setState(() {
                _loadingPayment = false;
                _payment = null;
                _paymentError = payment == null
                    ? '找不到付款資料，請重新讀取或返回訂單確認。'
                    : '付款資料與訂單不符，請返回訂單確認。';
              });
              return;
            }
            setState(() {
              _payment = payment;
              _paymentError = null;
              _loadingPayment = false;
            });
            _handlePaymentChanged(payment);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            setState(() {
              _loadingPayment = false;
              _paymentError = '付款資料讀取失敗，請重新讀取或返回訂單確認。';
            });
          },
        );
  }

  void _retryPayment() {
    setState(() {
      _loadingPayment = true;
      _paymentError = null;
    });
    _listenToPayment();
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    super.dispose();
  }

  /// Payment 狀態改變時執行。
  ///
  /// 成功、失敗、取消或逾期，
  /// 都會離開綠界付款頁並回到該張訂單詳情。
  void _handlePaymentChanged(PaymentModel? payment) {
    if (!mounted || payment == null || _leavingPaymentPage) {
      return;
    }

    switch (payment.status) {
      case PaymentTransactionStatus.paid:
        debugPrint(
          '✅ 綠界付款成功 '
          'paymentId=${payment.id} '
          'bookingId=${widget.bookingId}',
        );

        _leavePaymentPage();
        return;

      case PaymentTransactionStatus.failed:
        debugPrint(
          '❌ 綠界付款失敗 '
          'paymentId=${payment.id} '
          'bookingId=${widget.bookingId}',
        );

        _leavePaymentPage();
        return;

      case PaymentTransactionStatus.cancelled:
        debugPrint(
          '🚫 綠界付款取消 '
          'paymentId=${payment.id} '
          'bookingId=${widget.bookingId}',
        );

        _leavePaymentPage();
        return;

      case PaymentTransactionStatus.expired:
        debugPrint(
          '⌛ 綠界付款逾期 '
          'paymentId=${payment.id} '
          'bookingId=${widget.bookingId}',
        );

        _leavePaymentPage();
        return;

      default:
        return;
    }
  }

  Future<void> _leavePaymentPage() async {
    if (widget.storeOrderId.trim().isNotEmpty &&
        widget.shopId.trim().isNotEmpty) {
      await _openStoreOrderDetail();
      return;
    }

    await _openBookingDetail();
  }

  Future<void> _openStoreOrderDetail() async {
    if (!mounted || _leavingPaymentPage) {
      return;
    }

    _leavingPaymentPage = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MyStoreOrderDetailPage(
          shopId: widget.shopId,
          orderId: widget.storeOrderId,
        ),
      ),
      (Route<dynamic> route) => route.isFirst,
    );
  }

  /// 讀取最新 Booking 資料並開啟訂單詳情。
  ///
  /// 使用 pushAndRemoveUntil 清除付款流程中間頁面，
  /// 避免會員返回綠界付款頁或「我要預約」頁。
  Future<void> _openBookingDetail() async {
    if (!mounted || _leavingPaymentPage) {
      return;
    }

    _leavingPaymentPage = true;

    try {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnapshot =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .get();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>? bookingData = bookingSnapshot.data();

      if (!bookingSnapshot.exists || bookingData == null) {
        _leavingPaymentPage = false;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('找不到訂單資料，請回到我的訂單重新查看。')));

        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              BookingDetailPage(docId: widget.bookingId, data: bookingData),
        ),
        (Route<dynamic> route) => route.isFirst,
      );
    } catch (error) {
      _leavingPaymentPage = false;

      if (!mounted) {
        return;
      }

      debugPrint('❌ 開啟訂單詳情失敗：$error');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('開啟訂單詳情失敗：$error')));
    }
  }

  Future<void> _handleManualBack() async {
    if (_leavingPaymentPage) {
      return;
    }

    await _leavePaymentPage();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }

        _handleManualBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('綠界線上付款'),

          /// 不使用 Navigator.pop()，
          /// 避免返回付款前的預約流程。
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleManualBack,
          ),
        ),
        body: widget.paymentHtml.trim().isNotEmpty
            ? EcpayPaymentView(paymentHtml: widget.paymentHtml)
            : EcpayPaymentInformation(
                payment: _payment,
                loading: _loadingPayment,
                error: _paymentError,
                onRetry: _retryPayment,
              ),
      ),
    );
  }
}
