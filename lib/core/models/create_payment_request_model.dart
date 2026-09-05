// 檔案名稱：lib/core/models/create_payment_request_model.dart
// 功能說明：統一 Flutter 呼叫 Cloud Functions 建立綠界付款時的參數格式。
// 💳 建立付款請求模型
// 注意：此模型不得包含 MerchantID、HashKey、HashIV 或 CheckMacValue。

import 'payment_gateway_status.dart';

class CreatePaymentRequestModel {
  const CreatePaymentRequestModel({
    required this.shopId,
    required this.paymentMethod,
    required this.amountType,
    required this.amount,
    required this.requestId,
    this.bookingId = '',
    this.sourceType = PaymentSourceType.booking,
    this.sourceId = '',
    this.paymentPurpose,
  });

  /// 店家 ID
  final String shopId;

  /// 預約訂單 ID（住宿付款必填）
  final String bookingId;

  /// 付款來源
  final String sourceType;

  /// 來源 ID。商城付款為 storeOrderId。
  final String sourceId;

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

  /// 本次付款用途
  ///
  /// 支援：
  /// deposit、balance、full、additional、other
  ///
  /// 暫時允許為 null，兼容尚未更新的舊付款入口。
  /// 未傳入時會依 amountType 自動判斷。
  final String? paymentPurpose;

  /// 實際送往 Cloud Functions 的付款用途
  String get resolvedPaymentPurpose {
    final String value = paymentPurpose?.trim() ?? '';

    if (PaymentPurpose.isValid(value)) {
      return value;
    }

    return amountType == PaymentAmountType.deposit
        ? PaymentPurpose.deposit
        : PaymentPurpose.full;
  }

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

  String get resolvedSourceType {
    return PaymentSourceType.resolve(sourceType, bookingId: bookingId);
  }

  String get resolvedSourceId {
    if (resolvedSourceType == PaymentSourceType.storeOrder) {
      return sourceId.trim().isNotEmpty ? sourceId.trim() : bookingId.trim();
    }
    return bookingId.trim();
  }

  /// 基本資料是否有效
  bool get isValid {
    final bool hasSource = resolvedSourceType == PaymentSourceType.storeOrder
        ? resolvedSourceId.isNotEmpty
        : bookingId.trim().isNotEmpty;

    return shopId.trim().isNotEmpty &&
        hasSource &&
        requestId.trim().isNotEmpty &&
        amount > 0 &&
        hasValidPaymentMethod &&
        hasValidAmountType &&
        PaymentPurpose.isValid(resolvedPaymentPurpose);
  }

  /// 轉成 Cloud Functions callable 參數
  Map<String, dynamic> toCallableMap() {
    return <String, dynamic>{
      'shopId': shopId.trim(),
      'bookingId': bookingId.trim(),
      'sourceType': resolvedSourceType,
      'sourceId': resolvedSourceId,
      'paymentMethod': paymentMethod,
      'amountType': amountType,
      'paymentPurpose': resolvedPaymentPurpose,
      'amount': amount,
      'requestId': requestId.trim(),
    };
  }

  CreatePaymentRequestModel copyWith({
    String? shopId,
    String? bookingId,
    String? sourceType,
    String? sourceId,
    String? paymentMethod,
    String? amountType,
    String? paymentPurpose,
    int? amount,
    String? requestId,
  }) {
    return CreatePaymentRequestModel(
      shopId: shopId ?? this.shopId,
      bookingId: bookingId ?? this.bookingId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountType: amountType ?? this.amountType,
      paymentPurpose: paymentPurpose ?? this.paymentPurpose,
      amount: amount ?? this.amount,
      requestId: requestId ?? this.requestId,
    );
  }
}
