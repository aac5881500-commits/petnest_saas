// 檔案名稱：lib/core/models/payment_model.dart
// 功能說明：記錄店家向會員收款的每一筆付款交易。
// 💳 共用付款交易資料模型
// 注意：此模型不得保存 MerchantID、HashKey、HashIV 等敏感金流資料。

import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_gateway_status.dart';

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.shopId,
    required this.bookingId,
    required this.bookingCode,
    required this.userId,
    this.sourceType = PaymentSourceType.booking,
    this.sourceId = '',
    this.storeOrderId = '',
    this.storeOrderCode = '',
    this.customerName = '',
    required this.gateway,
    required this.paymentMethod,
    required this.amountType,
    required this.paymentPurpose,
    required this.amount,
    required this.status,
    required this.requestId,
    required this.merchantTradeNo,
    required this.createdAt,
    required this.updatedAt,
    this.gatewayTradeNo = '',
    this.currency = 'TWD',
    this.description = '',
    this.gatewayResultCode = '',
    this.gatewayResultMessage = '',
    this.atmBankCode = '',
    this.atmVirtualAccount = '',
    this.convenienceStorePaymentCode = '',
    this.paymentUrl = '',
    this.expireAt,
    this.paidAt,
    this.failedAt,
    this.cancelledAt,
    this.refundedAt,
    this.refundedAmount = 0,
    this.createdBy = '',
    this.updatedBy = '',
  });

  /// Firestore 文件 ID
  final String id;

  /// 所屬店家 ID
  final String shopId;

  /// 對應的預約訂單 ID
  final String bookingId;

  /// 對應的預約訂單編號
  ///
  /// 例如：SHOP0001-B000079
  final String bookingCode;

  /// 付款來源：booking 或 store_order。舊資料沒有此欄位時視為 booking。
  final String sourceType;

  /// 來源文件 ID。住宿為 bookingId，商城為 storeOrderId。
  final String sourceId;

  /// 商城訂單 ID
  final String storeOrderId;

  /// 商城訂單編號
  final String storeOrderCode;

  /// 付款會員 UID
  final String userId;

  /// 會員姓名
  final String customerName;

  /// 金流服務商
  ///
  /// 第一階段固定為 ecpay。
  final String gateway;

  /// 付款方式
  ///
  /// credit_card、atm、cvs_code、cash、transfer。
  final String paymentMethod;

  /// 本次收款類型
  ///
  /// deposit：訂金。
  /// full：全額。
  final String amountType;

  /// 本次付款用途
  ///
  /// deposit：訂金
  /// balance：尾款
  /// full：全額付款
  /// additional：加購、延長住宿或補款
  /// other：其他付款
  final String paymentPurpose;

  /// 本次應付金額，單位為新臺幣元
  final int amount;

  /// 幣別
  ///
  /// 目前固定使用 TWD。
  final String currency;

  /// 付款交易狀態
  final String status;

  /// 防止重複建立付款的請求識別碼
  ///
  /// 同一個 requestId 不得建立兩筆付款。
  final String requestId;

  /// PetNest 傳送給金流服務商的交易編號
  ///
  /// 綠界對應 MerchantTradeNo。
  final String merchantTradeNo;

  /// 金流服務商回傳的交易編號
  ///
  /// 綠界對應 TradeNo。
  final String gatewayTradeNo;

  /// 付款項目說明
  final String description;

  /// 金流回傳結果代碼
  final String gatewayResultCode;

  /// 金流回傳結果訊息
  final String gatewayResultMessage;

  /// ATM 銀行代碼
  final String atmBankCode;

  /// ATM 虛擬帳號
  final String atmVirtualAccount;

  /// 超商繳費代碼
  final String convenienceStorePaymentCode;

  /// 導向付款頁面的網址
  ///
  /// 正式串接時只能保存短期有效或可安全公開的付款網址。
  final String paymentUrl;

  /// 付款期限
  final DateTime? expireAt;

  /// 付款成功時間
  final DateTime? paidAt;

  /// 付款失敗時間
  final DateTime? failedAt;

  /// 付款取消時間
  final DateTime? cancelledAt;

  /// 完成退款時間
  final DateTime? refundedAt;

  /// 已退款金額
  final int refundedAmount;

  /// 建立付款的人員 UID
  ///
  /// 會員自行付款時通常為會員 UID。
  final String createdBy;

  /// 最後修改人員 UID
  ///
  /// Cloud Functions 更新時可填入 system。
  final String updatedBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否為商城付款
  bool get isStoreOrderPayment {
    return PaymentSourceType.isStoreOrder(sourceType);
  }

  /// 列表顯示用訂單編號
  String get displayOrderCode {
    if (isStoreOrderPayment) {
      return storeOrderCode.isNotEmpty ? storeOrderCode : sourceId;
    }
    return bookingCode;
  }

  /// 來源顯示：住宿付款 / 商城付款
  String get sourceTypeLabel {
    return isStoreOrderPayment ? '商城付款' : '住宿付款';
  }

  bool get isOnlinePayment {
    return PaymentMethodType.isOnlinePayment(paymentMethod);
  }

  /// 是否為訂金
  bool get isDeposit {
    return amountType == PaymentAmountType.deposit;
  }

  /// 是否為全額付款
  bool get isFullPayment {
    return amountType == PaymentAmountType.full;
  }

  /// 是否為尾款
  bool get isBalancePayment {
    return paymentPurpose == PaymentPurpose.balance;
  }

  /// 是否為加購或補款
  bool get isAdditionalPayment {
    return paymentPurpose == PaymentPurpose.additional;
  }

  /// 是否付款成功
  bool get isPaid {
    return status == PaymentTransactionStatus.paid;
  }

  /// 是否等待付款
  bool get isAwaitingPayment {
    return status == PaymentTransactionStatus.awaitingPayment;
  }

  /// 是否付款失敗
  bool get isFailed {
    return status == PaymentTransactionStatus.failed;
  }

  /// 是否已取消
  bool get isCancelled {
    return status == PaymentTransactionStatus.cancelled;
  }

  /// 是否已逾期
  bool get isExpired {
    if (status == PaymentTransactionStatus.expired) {
      return true;
    }

    final DateTime? end = expireAt;
    if (end == null || isPaid) {
      return false;
    }

    return DateTime.now().isAfter(end);
  }

  /// 是否已有退款
  bool get hasRefund {
    return refundedAmount > 0;
  }

  /// 尚可退款金額
  int get refundableAmount {
    final int remaining = amount - refundedAmount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  factory PaymentModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return PaymentModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      bookingId: (data['bookingId'] ?? '').toString(),
      bookingCode: (data['bookingCode'] ?? '').toString(),
      sourceType: PaymentSourceType.resolve(
        data['sourceType'],
        bookingId: (data['bookingId'] ?? '').toString(),
      ),
      sourceId:
          (data['sourceId'] ?? data['bookingId'] ?? data['storeOrderId'] ?? '')
              .toString(),
      storeOrderId: (data['storeOrderId'] ?? '').toString(),
      storeOrderCode: (data['storeOrderCode'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      customerName: (data['customerName'] ?? '').toString(),
      gateway: (data['gateway'] ?? PaymentGateway.ecpay).toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      amountType: (data['amountType'] ?? '').toString(),
      paymentPurpose: _resolvePaymentPurpose(data),
      amount: _intFromValue(data['amount']),
      currency: (data['currency'] ?? 'TWD').toString(),
      status: (data['status'] ?? PaymentTransactionStatus.pending).toString(),
      requestId: (data['requestId'] ?? '').toString(),
      merchantTradeNo: (data['merchantTradeNo'] ?? '').toString(),
      gatewayTradeNo: (data['gatewayTradeNo'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      gatewayResultCode: (data['gatewayResultCode'] ?? '').toString(),
      gatewayResultMessage: (data['gatewayResultMessage'] ?? '').toString(),
      atmBankCode: (data['atmBankCode'] ?? '').toString(),
      atmVirtualAccount: (data['atmVirtualAccount'] ?? '').toString(),
      convenienceStorePaymentCode: (data['convenienceStorePaymentCode'] ?? '')
          .toString(),
      paymentUrl: (data['paymentUrl'] ?? '').toString(),
      expireAt: _dateTimeFromValue(data['expireAt']),
      paidAt: _dateTimeFromValue(data['paidAt']),
      failedAt: _dateTimeFromValue(data['failedAt']),
      cancelledAt: _dateTimeFromValue(data['cancelledAt']),
      refundedAt: _dateTimeFromValue(data['refundedAt']),
      refundedAmount: _intFromValue(data['refundedAmount']),
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'bookingCode': bookingCode,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'storeOrderId': storeOrderId,
      'storeOrderCode': storeOrderCode,
      'userId': userId,
      'customerName': customerName,
      'gateway': gateway,
      'paymentMethod': paymentMethod,
      'amountType': amountType,
      'paymentPurpose': paymentPurpose,
      'amount': amount,
      'currency': currency,
      'status': status,
      'requestId': requestId,
      'merchantTradeNo': merchantTradeNo,
      'gatewayTradeNo': gatewayTradeNo,
      'description': description.trim(),
      'gatewayResultCode': gatewayResultCode,
      'gatewayResultMessage': gatewayResultMessage,
      'atmBankCode': atmBankCode,
      'atmVirtualAccount': atmVirtualAccount,
      'convenienceStorePaymentCode': convenienceStorePaymentCode,
      'paymentUrl': paymentUrl,
      'expireAt': expireAt == null ? null : Timestamp.fromDate(expireAt!),
      'paidAt': paidAt == null ? null : Timestamp.fromDate(paidAt!),
      'failedAt': failedAt == null ? null : Timestamp.fromDate(failedAt!),
      'cancelledAt': cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
      'refundedAt': refundedAt == null ? null : Timestamp.fromDate(refundedAt!),
      'refundedAmount': refundedAmount,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? shopId,
    String? bookingId,
    String? bookingCode,
    String? sourceType,
    String? sourceId,
    String? storeOrderId,
    String? storeOrderCode,
    String? userId,
    String? customerName,
    String? gateway,
    String? paymentMethod,
    String? amountType,
    String? paymentPurpose,
    int? amount,
    String? currency,
    String? status,
    String? requestId,
    String? merchantTradeNo,
    String? gatewayTradeNo,
    String? description,
    String? gatewayResultCode,
    String? gatewayResultMessage,
    String? atmBankCode,
    String? atmVirtualAccount,
    String? convenienceStorePaymentCode,
    String? paymentUrl,
    DateTime? expireAt,
    bool clearExpireAt = false,
    DateTime? paidAt,
    bool clearPaidAt = false,
    DateTime? failedAt,
    bool clearFailedAt = false,
    DateTime? cancelledAt,
    bool clearCancelledAt = false,
    DateTime? refundedAt,
    bool clearRefundedAt = false,
    int? refundedAmount,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      bookingId: bookingId ?? this.bookingId,
      bookingCode: bookingCode ?? this.bookingCode,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      storeOrderId: storeOrderId ?? this.storeOrderId,
      storeOrderCode: storeOrderCode ?? this.storeOrderCode,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      gateway: gateway ?? this.gateway,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountType: amountType ?? this.amountType,
      paymentPurpose: paymentPurpose ?? this.paymentPurpose,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      requestId: requestId ?? this.requestId,
      merchantTradeNo: merchantTradeNo ?? this.merchantTradeNo,
      gatewayTradeNo: gatewayTradeNo ?? this.gatewayTradeNo,
      description: description ?? this.description,
      gatewayResultCode: gatewayResultCode ?? this.gatewayResultCode,
      gatewayResultMessage: gatewayResultMessage ?? this.gatewayResultMessage,
      atmBankCode: atmBankCode ?? this.atmBankCode,
      atmVirtualAccount: atmVirtualAccount ?? this.atmVirtualAccount,
      convenienceStorePaymentCode:
          convenienceStorePaymentCode ?? this.convenienceStorePaymentCode,
      paymentUrl: paymentUrl ?? this.paymentUrl,
      expireAt: clearExpireAt ? null : expireAt ?? this.expireAt,
      paidAt: clearPaidAt ? null : paidAt ?? this.paidAt,
      failedAt: clearFailedAt ? null : failedAt ?? this.failedAt,
      cancelledAt: clearCancelledAt ? null : cancelledAt ?? this.cancelledAt,
      refundedAt: clearRefundedAt ? null : refundedAt ?? this.refundedAt,
      refundedAmount: refundedAmount ?? this.refundedAmount,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _resolvePaymentPurpose(Map<String, dynamic> data) {
    final String purpose = (data['paymentPurpose'] ?? '').toString().trim();

    if (PaymentPurpose.isValid(purpose)) {
      return purpose;
    }

    final String amountType = (data['amountType'] ?? '').toString().trim();

    return amountType == PaymentAmountType.deposit
        ? PaymentPurpose.deposit
        : PaymentPurpose.full;
  }

  static int _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
