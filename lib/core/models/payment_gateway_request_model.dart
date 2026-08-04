// lib/core/models/payment_gateway_request_model.dart
// 💳 店家金流申請資料模型
// 功能：記錄首次設定、修改金流資料、重新啟用，以及平台審核結果。
// 注意：不得保存 HashKey、HashIV、密碼或完整敏感憑證。

import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_gateway_status.dart';

class PaymentGatewayRequestModel {
  const PaymentGatewayRequestModel({
    required this.id,
    required this.shopId,
    required this.gateway,
    required this.requestType,
    required this.status,
    required this.applicantUid,
    required this.createdAt,
    required this.updatedAt,
    this.shopName = '',
    this.merchantIdMasked = '',
    this.ecpayAccountMasked = '',
    this.companyName = '',
    this.taxIdMasked = '',
    this.identityType = '',
    this.productionRequested = true,
    this.requestReason = '',
    this.reviewMessage = '',
    this.reviewedBy = '',
    this.reviewedAt,
    this.secretReference = '',
    this.previousRequestId = '',
  });

  /// Firestore 文件 ID
  final String id;

  /// 申請店家 ID
  final String shopId;

  /// 店家名稱快照
  final String shopName;

  /// 金流服務商
  ///
  /// 第一階段固定為 ecpay。
  final String gateway;

  /// 申請類型
  ///
  /// initial_setup：首次設定。
  /// change_request：修改已鎖定資料。
  /// reactivate：重新啟用。
  final String requestType;

  /// 申請審核狀態
  ///
  /// draft、pending、approved、rejected。
  final String status;

  /// 申請人 UID
  final String applicantUid;

  /// MerchantID 遮罩後內容
  ///
  /// 例如：12****78。
  /// 不得保存完整 MerchantID。
  final String merchantIdMasked;

  /// 綠界帳號遮罩後內容
  final String ecpayAccountMasked;

  /// 公司或商業名稱
  final String companyName;

  /// 統一編號遮罩後內容
  ///
  /// 是否保存完整統編，後續需依 Firestore Rules
  /// 與實際審核需求另外決定。
  final String taxIdMasked;

  /// 公司身分類型
  ///
  /// 例如 company、business、individual。
  final String identityType;

  /// 是否申請使用正式環境
  final bool productionRequested;

  /// 申請修改或重新啟用的原因
  final String requestReason;

  /// 平台核准、退回或補件說明
  final String reviewMessage;

  /// 平台審核人 UID
  final String reviewedBy;

  /// 平台審核時間
  final DateTime? reviewedAt;

  /// 敏感憑證的安全參照名稱
  ///
  /// 只能保存 Secret Manager 參照代號或版本識別，
  /// 不得保存真正的 HashKey、HashIV。
  ///
  /// 這個欄位原則上只應由 Cloud Functions 寫入。
  final String secretReference;

  /// 修改申請所對應的上一筆核准申請 ID
  final String previousRequestId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否為首次設定
  bool get isInitialSetup {
    return requestType == PaymentGatewayRequestType.initialSetup;
  }

  /// 是否為修改申請
  bool get isChangeRequest {
    return requestType == PaymentGatewayRequestType.changeRequest;
  }

  /// 是否為重新啟用申請
  bool get isReactivateRequest {
    return requestType == PaymentGatewayRequestType.reactivate;
  }

  /// 是否正在等待平台審核
  bool get isPending {
    return status == PaymentGatewayReviewStatus.pending;
  }

  /// 是否已核准
  bool get isApproved {
    return status == PaymentGatewayReviewStatus.approved;
  }

  /// 是否已退回
  bool get isRejected {
    return status == PaymentGatewayReviewStatus.rejected;
  }

  factory PaymentGatewayRequestModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return PaymentGatewayRequestModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      shopName: (data['shopName'] ?? '').toString(),
      gateway: (data['gateway'] ?? PaymentGateway.ecpay).toString(),
      requestType: _normalizeRequestType(
        (data['requestType'] ?? PaymentGatewayRequestType.initialSetup)
            .toString(),
      ),
      status: _normalizeStatus(
        (data['status'] ?? PaymentGatewayReviewStatus.draft).toString(),
      ),
      applicantUid: (data['applicantUid'] ?? '').toString(),
      merchantIdMasked: (data['merchantIdMasked'] ?? '').toString(),
      ecpayAccountMasked: (data['ecpayAccountMasked'] ?? '').toString(),
      companyName: (data['companyName'] ?? '').toString(),
      taxIdMasked: (data['taxIdMasked'] ?? '').toString(),
      identityType: (data['identityType'] ?? '').toString(),
      productionRequested: data['productionRequested'] != false,
      requestReason: (data['requestReason'] ?? '').toString(),
      reviewMessage: (data['reviewMessage'] ?? '').toString(),
      reviewedBy: (data['reviewedBy'] ?? '').toString(),
      reviewedAt: _dateTimeFromValue(data['reviewedAt']),
      secretReference: (data['secretReference'] ?? '').toString(),
      previousRequestId: (data['previousRequestId'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'shopName': shopName.trim(),
      'gateway': gateway,
      'requestType': requestType,
      'status': status,
      'applicantUid': applicantUid,
      'merchantIdMasked': merchantIdMasked.trim(),
      'ecpayAccountMasked': ecpayAccountMasked.trim(),
      'companyName': companyName.trim(),
      'taxIdMasked': taxIdMasked.trim(),
      'identityType': identityType,
      'productionRequested': productionRequested,
      'requestReason': requestReason.trim(),
      'reviewMessage': reviewMessage.trim(),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'secretReference': secretReference,
      'previousRequestId': previousRequestId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PaymentGatewayRequestModel copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? gateway,
    String? requestType,
    String? status,
    String? applicantUid,
    String? merchantIdMasked,
    String? ecpayAccountMasked,
    String? companyName,
    String? taxIdMasked,
    String? identityType,
    bool? productionRequested,
    String? requestReason,
    String? reviewMessage,
    String? reviewedBy,
    DateTime? reviewedAt,
    bool clearReviewedAt = false,
    String? secretReference,
    String? previousRequestId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentGatewayRequestModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      gateway: gateway ?? this.gateway,
      requestType: requestType ?? this.requestType,
      status: status ?? this.status,
      applicantUid: applicantUid ?? this.applicantUid,
      merchantIdMasked: merchantIdMasked ?? this.merchantIdMasked,
      ecpayAccountMasked: ecpayAccountMasked ?? this.ecpayAccountMasked,
      companyName: companyName ?? this.companyName,
      taxIdMasked: taxIdMasked ?? this.taxIdMasked,
      identityType: identityType ?? this.identityType,
      productionRequested: productionRequested ?? this.productionRequested,
      requestReason: requestReason ?? this.requestReason,
      reviewMessage: reviewMessage ?? this.reviewMessage,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: clearReviewedAt ? null : reviewedAt ?? this.reviewedAt,
      secretReference: secretReference ?? this.secretReference,
      previousRequestId: previousRequestId ?? this.previousRequestId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _normalizeRequestType(String value) {
    const Set<String> supportedTypes = <String>{
      PaymentGatewayRequestType.initialSetup,
      PaymentGatewayRequestType.changeRequest,
      PaymentGatewayRequestType.reactivate,
    };

    if (supportedTypes.contains(value)) {
      return value;
    }

    return PaymentGatewayRequestType.initialSetup;
  }

  static String _normalizeStatus(String value) {
    const Set<String> supportedStatuses = <String>{
      PaymentGatewayReviewStatus.draft,
      PaymentGatewayReviewStatus.pending,
      PaymentGatewayReviewStatus.approved,
      PaymentGatewayReviewStatus.rejected,
    };

    if (supportedStatuses.contains(value)) {
      return value;
    }

    return PaymentGatewayReviewStatus.draft;
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
