// 檔案名稱：lib/core/models/payment_setting_model.dart
// 功能說明：記錄 Flutter 可以安全讀取的付款方式、審核狀態與平台控制狀態。
// 💳 店家共用金流公開設定模型
// 注意：此模型不得保存 MerchantID、HashKey、HashIV 或綠界登入資料。

import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_gateway_status.dart';

class PaymentSettingModel {
  const PaymentSettingModel({
    required this.shopId,
    required this.gateway,
    required this.reviewStatus,
    required this.onlinePaymentEnabled,
    required this.creditCardEnabled,
    required this.atmEnabled,
    required this.convenienceStoreCodeEnabled,
    required this.depositPaymentEnabled,
    required this.fullPaymentEnabled,
    required this.onSitePaymentEnabled,
    required this.settingLocked,
    required this.shopDisabled,
    required this.platformSuspended,
    required this.productionEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.reviewMessage = '',
    this.updatedBy = '',
    this.approvedAt,
    this.approvedBy = '',
  });

  /// 所屬店家 ID
  final String shopId;

  /// 金流服務商
  ///
  /// 目前第一階段固定為 ecpay。
  final String gateway;

  /// 平台審核狀態
  ///
  /// 狀態定義放在 PaymentGatewayReviewStatus。
  final String reviewStatus;

  /// 是否開放線上付款總開關
  final bool onlinePaymentEnabled;

  /// 是否開放信用卡付款
  final bool creditCardEnabled;

  /// 是否開放 ATM 虛擬帳號付款
  final bool atmEnabled;

  /// 是否開放超商代碼付款
  final bool convenienceStoreCodeEnabled;

  /// 是否允許收取訂金
  final bool depositPaymentEnabled;

  /// 是否允許收取全額
  final bool fullPaymentEnabled;

  /// 是否允許現場付款
  final bool onSitePaymentEnabled;

  /// 重要金流資料是否已鎖定
  ///
  /// 首次設定送審或核准後，敏感資料不可直接修改。
  final bool settingLocked;

  /// 店家是否自行停用金流
  final bool shopDisabled;

  /// 平台是否暫停此店家金流
  final bool platformSuspended;

  /// 是否已啟用正式環境
  ///
  /// false 代表尚未啟用正式收款。
  final bool productionEnabled;

  /// 平台審核或退回說明
  final String reviewMessage;

  /// 最後修改人 UID
  final String updatedBy;

  /// 平台核准時間
  final DateTime? approvedAt;

  /// 平台核准人 UID
  final String approvedBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否已通過平台審核
  bool get isApproved {
    return reviewStatus == PaymentGatewayReviewStatus.approved;
  }

  /// 是否正在等待平台審核
  bool get isPendingReview {
    return reviewStatus == PaymentGatewayReviewStatus.pending;
  }

  /// 是否被平台暫停
  bool get isSuspended {
    return reviewStatus == PaymentGatewayReviewStatus.suspended ||
        platformSuspended;
  }

  /// 是否至少開啟一種線上付款方式
  bool get hasOnlinePaymentMethod {
    return creditCardEnabled || atmEnabled || convenienceStoreCodeEnabled;
  }

  /// 是否至少開啟一種收款金額模式
  bool get hasPaymentAmountType {
    return depositPaymentEnabled || fullPaymentEnabled;
  }

  /// 店家目前是否可以建立線上付款
  bool get canCreateOnlinePayment {
    return onlinePaymentEnabled &&
        isApproved &&
        productionEnabled &&
        !shopDisabled &&
        !platformSuspended &&
        hasOnlinePaymentMethod &&
        hasPaymentAmountType;
  }

  /// 店家是否可以使用現場付款
  bool get canUseOnSitePayment {
    return onSitePaymentEnabled && !shopDisabled && !platformSuspended;
  }

  /// 是否允許店家直接修改重要金流資料
  bool get canEditProtectedSetting {
    return !settingLocked &&
        reviewStatus != PaymentGatewayReviewStatus.pending &&
        reviewStatus != PaymentGatewayReviewStatus.approved &&
        reviewStatus != PaymentGatewayReviewStatus.suspended;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'gateway': gateway,
      'reviewStatus': reviewStatus,
      'onlinePaymentEnabled': onlinePaymentEnabled,
      'creditCardEnabled': creditCardEnabled,
      'atmEnabled': atmEnabled,
      'convenienceStoreCodeEnabled': convenienceStoreCodeEnabled,
      'depositPaymentEnabled': depositPaymentEnabled,
      'fullPaymentEnabled': fullPaymentEnabled,
      'onSitePaymentEnabled': onSitePaymentEnabled,
      'settingLocked': settingLocked,
      'shopDisabled': shopDisabled,
      'platformSuspended': platformSuspended,
      'productionEnabled': productionEnabled,
      'reviewMessage': reviewMessage.trim(),
      'updatedBy': updatedBy,
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PaymentSettingModel.fromMap({
    required String shopId,
    required Map<String, dynamic> data,
  }) {
    final String rawReviewStatus =
        (data['reviewStatus'] ?? PaymentGatewayReviewStatus.notConfigured)
            .toString();

    return PaymentSettingModel(
      shopId: shopId,
      gateway: (data['gateway'] ?? PaymentGateway.ecpay).toString(),
      reviewStatus: _normalizeReviewStatus(rawReviewStatus),
      onlinePaymentEnabled: data['onlinePaymentEnabled'] == true,
      creditCardEnabled: data['creditCardEnabled'] == true,
      atmEnabled: data['atmEnabled'] == true,
      convenienceStoreCodeEnabled: data['convenienceStoreCodeEnabled'] == true,
      depositPaymentEnabled: data['depositPaymentEnabled'] == true,
      fullPaymentEnabled: data['fullPaymentEnabled'] == true,
      onSitePaymentEnabled: data['onSitePaymentEnabled'] != false,
      settingLocked: data['settingLocked'] == true,
      shopDisabled: data['shopDisabled'] == true,
      platformSuspended: data['platformSuspended'] == true,
      productionEnabled: data['productionEnabled'] == true,
      reviewMessage: (data['reviewMessage'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      approvedAt: _dateTimeFromValue(data['approvedAt']),
      approvedBy: (data['approvedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  PaymentSettingModel copyWith({
    String? shopId,
    String? gateway,
    String? reviewStatus,
    bool? onlinePaymentEnabled,
    bool? creditCardEnabled,
    bool? atmEnabled,
    bool? convenienceStoreCodeEnabled,
    bool? depositPaymentEnabled,
    bool? fullPaymentEnabled,
    bool? onSitePaymentEnabled,
    bool? settingLocked,
    bool? shopDisabled,
    bool? platformSuspended,
    bool? productionEnabled,
    String? reviewMessage,
    String? updatedBy,
    DateTime? approvedAt,
    bool clearApprovedAt = false,
    String? approvedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentSettingModel(
      shopId: shopId ?? this.shopId,
      gateway: gateway ?? this.gateway,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      onlinePaymentEnabled: onlinePaymentEnabled ?? this.onlinePaymentEnabled,
      creditCardEnabled: creditCardEnabled ?? this.creditCardEnabled,
      atmEnabled: atmEnabled ?? this.atmEnabled,
      convenienceStoreCodeEnabled:
          convenienceStoreCodeEnabled ?? this.convenienceStoreCodeEnabled,
      depositPaymentEnabled:
          depositPaymentEnabled ?? this.depositPaymentEnabled,
      fullPaymentEnabled: fullPaymentEnabled ?? this.fullPaymentEnabled,
      onSitePaymentEnabled: onSitePaymentEnabled ?? this.onSitePaymentEnabled,
      settingLocked: settingLocked ?? this.settingLocked,
      shopDisabled: shopDisabled ?? this.shopDisabled,
      platformSuspended: platformSuspended ?? this.platformSuspended,
      productionEnabled: productionEnabled ?? this.productionEnabled,
      reviewMessage: reviewMessage ?? this.reviewMessage,
      updatedBy: updatedBy ?? this.updatedBy,
      approvedAt: clearApprovedAt ? null : approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 建立尚未設定金流時的預設資料
  factory PaymentSettingModel.initial({
    required String shopId,
    String updatedBy = '',
  }) {
    final DateTime now = DateTime.now();

    return PaymentSettingModel(
      shopId: shopId,
      gateway: PaymentGateway.ecpay,
      reviewStatus: PaymentGatewayReviewStatus.notConfigured,
      onlinePaymentEnabled: false,
      creditCardEnabled: false,
      atmEnabled: false,
      convenienceStoreCodeEnabled: false,
      depositPaymentEnabled: false,
      fullPaymentEnabled: false,
      onSitePaymentEnabled: true,
      settingLocked: false,
      shopDisabled: false,
      platformSuspended: false,
      productionEnabled: false,
      reviewMessage: '',
      updatedBy: updatedBy,
      approvedAt: null,
      approvedBy: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _normalizeReviewStatus(String value) {
    const Set<String> supportedStatuses = <String>{
      PaymentGatewayReviewStatus.notConfigured,
      PaymentGatewayReviewStatus.draft,
      PaymentGatewayReviewStatus.pending,
      PaymentGatewayReviewStatus.approved,
      PaymentGatewayReviewStatus.rejected,
      PaymentGatewayReviewStatus.suspended,
      PaymentGatewayReviewStatus.disabled,
    };

    if (supportedStatuses.contains(value)) {
      return value;
    }

    return PaymentGatewayReviewStatus.notConfigured;
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
