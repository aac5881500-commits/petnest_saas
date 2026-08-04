// lib/core/models/create_payment_request_model.dart
// 💳 建立付款請求模型
// 功能：統一 Flutter 呼叫 Cloud Functions 建立綠界付款時的參數格式。
// 注意：此模型不得包含 MerchantID、HashKey、HashIV 或 CheckMacValue。

import 'payment_gateway_status.dart';

class CreatePaymentRequestModel {
  const CreatePaymentRequestModel({
    required this.shopId,
    required this.bookingId,
    required this.paymentMethod,
    required this.amountType,
    required this.amount,
    required this.requestId,
  });

  /// 店家 ID
  final String shopId;

  /// 預約訂單 ID
  final String bookingId;

  /// 付款方式
  ///
  /// 支援：
  /// credit_card、atm、cvs_code
  final String paymentMethod;

  /// 收款類型
  ///
  /// 支援：
  /// deposit、full
  final String amountType;

  /// 本次付款金額
  final int amount;

  /// 前端建立的防重複請求 ID
  ///
  /// 使用者重複點擊付款按鈕時，
  /// Cloud Functions 應使用此欄位避免建立重複付款。
  final String requestId;

  /// 是否為有效的線上付款方式
  bool get hasValidPaymentMethod {
    return paymentMethod == PaymentMethodType.creditCard ||
        paymentMethod == PaymentMethodType.atm ||
        paymentMethod == PaymentMethodType.convenienceStoreCode;
  }

  /// 是否為有效的收款類型
  bool get hasValidAmountType {
    return amountType == PaymentAmountType.deposit ||
        amountType == PaymentAmountType.full;
  }

  /// 基本資料是否有效
  bool get isValid {
    return shopId.trim().isNotEmpty &&
        bookingId.trim().isNotEmpty &&
        requestId.trim().isNotEmpty &&
        amount > 0 &&
        hasValidPaymentMethod &&
        hasValidAmountType;
  }

  /// 轉成 Cloud Functions callable 參數
  Map<String, dynamic> toCallableMap() {
    return <String, dynamic>{
      'shopId': shopId.trim(),
      'bookingId': bookingId.trim(),
      'paymentMethod': paymentMethod,
      'amountType': amountType,
      'amount': amount,
      'requestId': requestId.trim(),
    };
  }

  CreatePaymentRequestModel copyWith({
    String? shopId,
    String? bookingId,
    String? paymentMethod,
    String? amountType,
    int? amount,
    String? requestId,
  }) {
    return CreatePaymentRequestModel(
      shopId: shopId ?? this.shopId,
      bookingId: bookingId ?? this.bookingId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountType: amountType ?? this.amountType,
      amount: amount ?? this.amount,
      requestId: requestId ?? this.requestId,
    );
  }
}
