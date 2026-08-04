// lib/core/models/create_payment_result_model.dart
// 💳 建立付款結果模型
// 功能：解析 Cloud Functions 建立付款後回傳的付款網址、
// ATM 虛擬帳號、超商代碼與付款期限等資料。

class CreatePaymentResultModel {
  const CreatePaymentResultModel({
    required this.success,
    required this.paymentId,
    required this.paymentMethod,
    required this.amountType,
    required this.amount,
    required this.status,
    this.message = '',
    this.merchantTradeNo = '',
    this.paymentUrl = '',

    /// 🌐 綠界付款表單 HTML
    /// 功能：由 Cloud Function 產生，Flutter 不接觸綠界密鑰。
    this.paymentHtml = '',

    this.atmBankCode = '',
    this.atmAccount = '',
    this.atmExpireAt,
    this.cvsPaymentCode = '',
    this.cvsExpireAt,
  });

  /// 是否成功建立付款
  final bool success;

  /// PetNest 付款紀錄 ID
  ///
  /// 對應：
  /// payments/{paymentId}
  final String paymentId;

  /// 本次付款方式
  ///
  /// credit_card、atm、cvs_code
  final String paymentMethod;

  /// 收款類型
  ///
  /// deposit、full
  final String amountType;

  /// 本次付款金額
  final int amount;

  /// 付款目前狀態
  ///
  /// 例如：
  /// pending、waiting_payment、paid、failed
  final String status;

  /// Functions 回傳訊息
  final String message;

  /// 綠界商店交易編號
  final String merchantTradeNo;

  /// 信用卡或其他付款導向網址
  final String paymentUrl;

  /// 🌐 綠界付款表單 HTML
  /// 功能：內含自動送出的綠界付款表單。
  final String paymentHtml;

  /// ATM 銀行代碼
  final String atmBankCode;

  /// ATM 虛擬繳款帳號
  final String atmAccount;

  /// ATM 繳款期限
  final DateTime? atmExpireAt;

  /// 超商繳費代碼
  final String cvsPaymentCode;

  /// 超商繳費期限
  final DateTime? cvsExpireAt;

  /// 是否有付款導向網址
  bool get hasPaymentUrl {
    return paymentUrl.trim().isNotEmpty;
  }

  /// 是否有綠界付款表單
  bool get hasPaymentHtml {
    return paymentHtml.trim().isNotEmpty;
  }

  /// 是否有 ATM 繳款資料
  bool get hasAtmPaymentInfo {
    return atmBankCode.trim().isNotEmpty && atmAccount.trim().isNotEmpty;
  }

  /// 是否有超商繳費資料
  bool get hasCvsPaymentInfo {
    return cvsPaymentCode.trim().isNotEmpty;
  }

  factory CreatePaymentResultModel.fromMap(Map<String, dynamic> data) {
    return CreatePaymentResultModel(
      success: data['success'] == true,
      paymentId: (data['paymentId'] ?? '').toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      amountType: (data['amountType'] ?? '').toString(),
      amount: _intFromValue(data['amount']),
      status: (data['status'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      merchantTradeNo: (data['merchantTradeNo'] ?? '').toString(),
      paymentUrl: (data['paymentUrl'] ?? '').toString(),

      /// 🌐 接收 createEcpayPayment 回傳的付款表單
      paymentHtml: (data['paymentHtml'] ?? '').toString(),

      atmBankCode: (data['atmBankCode'] ?? '').toString(),
      atmAccount: (data['atmAccount'] ?? '').toString(),
      atmExpireAt: _dateTimeFromValue(data['atmExpireAt']),
      cvsPaymentCode: (data['cvsPaymentCode'] ?? '').toString(),
      cvsExpireAt: _dateTimeFromValue(data['cvsExpireAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'success': success,
      'paymentId': paymentId.trim(),
      'paymentMethod': paymentMethod,
      'amountType': amountType,
      'amount': amount,
      'status': status,
      'message': message.trim(),
      'merchantTradeNo': merchantTradeNo.trim(),
      'paymentUrl': paymentUrl.trim(),
      'paymentHtml': paymentHtml.trim(),
      'atmBankCode': atmBankCode.trim(),
      'atmAccount': atmAccount.trim(),
      'atmExpireAt': atmExpireAt?.toIso8601String(),
      'cvsPaymentCode': cvsPaymentCode.trim(),
      'cvsExpireAt': cvsExpireAt?.toIso8601String(),
    };
  }

  CreatePaymentResultModel copyWith({
    bool? success,
    String? paymentId,
    String? paymentMethod,
    String? amountType,
    int? amount,
    String? status,
    String? message,
    String? merchantTradeNo,
    String? paymentUrl,
    String? paymentHtml,
    String? atmBankCode,
    String? atmAccount,
    DateTime? atmExpireAt,
    bool clearAtmExpireAt = false,
    String? cvsPaymentCode,
    DateTime? cvsExpireAt,
    bool clearCvsExpireAt = false,
  }) {
    return CreatePaymentResultModel(
      success: success ?? this.success,
      paymentId: paymentId ?? this.paymentId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountType: amountType ?? this.amountType,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      message: message ?? this.message,
      merchantTradeNo: merchantTradeNo ?? this.merchantTradeNo,
      paymentUrl: paymentUrl ?? this.paymentUrl,
      paymentHtml: paymentHtml ?? this.paymentHtml,
      atmBankCode: atmBankCode ?? this.atmBankCode,
      atmAccount: atmAccount ?? this.atmAccount,
      atmExpireAt: clearAtmExpireAt ? null : atmExpireAt ?? this.atmExpireAt,
      cvsPaymentCode: cvsPaymentCode ?? this.cvsPaymentCode,
      cvsExpireAt: clearCvsExpireAt ? null : cvsExpireAt ?? this.cvsExpireAt,
    );
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
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is Map) {
      final dynamic secondsValue = value['_seconds'] ?? value['seconds'];

      if (secondsValue is num) {
        return DateTime.fromMillisecondsSinceEpoch(secondsValue.toInt() * 1000);
      }
    }

    return DateTime.tryParse(value.toString());
  }
}
