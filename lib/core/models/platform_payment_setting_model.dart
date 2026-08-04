// lib/core/models/platform_payment_setting_model.dart
// 💳 PetNest 全平台金流控制模型
// 功能：管理全平台線上付款、綠界維護與緊急暫停狀態。
// 注意：此模型不保存任何店家的 MerchantID、HashKey 或 HashIV。

import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformPaymentSettingModel {
  const PlatformPaymentSettingModel({
    required this.onlinePaymentEnabled,
    required this.ecpayEnabled,
    required this.maintenanceMode,
    required this.onSitePaymentEnabled,
    required this.bankTransferEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.maintenanceMessage = '',
    this.disabledReason = '',
    this.updatedBy = '',
  });

  /// 全平台線上付款總開關
  ///
  /// false 時，所有店家的信用卡、ATM、超商代碼都不可使用。
  final bool onlinePaymentEnabled;

  /// 全平台綠界金流開關
  ///
  /// 未來如果增加其他金流服務商，
  /// 可以分別控制不同 Gateway。
  final bool ecpayEnabled;

  /// 是否進入金流維護模式
  final bool maintenanceMode;

  /// 維護期間顯示給會員的訊息
  final String maintenanceMessage;

  /// 平台停用金流的原因
  ///
  /// 主要供平台後台與操作紀錄使用。
  final String disabledReason;

  /// 是否保留現場付款
  ///
  /// 一般情況下，即使綠界暫停也可以維持現場付款。
  final bool onSitePaymentEnabled;

  /// 是否保留人工銀行轉帳
  ///
  /// 此欄位控制目前既有的人工轉帳流程，
  /// 不代表綠界 ATM 虛擬帳號。
  final bool bankTransferEnabled;

  /// 最後修改人 UID
  final String updatedBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 全平台目前是否可以使用綠界線上付款
  bool get canUseEcpay {
    return onlinePaymentEnabled && ecpayEnabled && !maintenanceMode;
  }

  /// 全平台線上付款不可用時的顯示訊息
  String get unavailableMessage {
    final String customMessage = maintenanceMessage.trim();

    if (maintenanceMode && customMessage.isNotEmpty) {
      return customMessage;
    }

    if (maintenanceMode) {
      return '線上付款系統目前維護中，請稍後再試。';
    }

    if (!onlinePaymentEnabled) {
      return '平台目前暫停線上付款功能。';
    }

    if (!ecpayEnabled) {
      return '綠界線上付款目前暫停使用。';
    }

    return '';
  }

  factory PlatformPaymentSettingModel.fromMap(Map<String, dynamic> data) {
    return PlatformPaymentSettingModel(
      onlinePaymentEnabled: data['onlinePaymentEnabled'] != false,
      ecpayEnabled: data['ecpayEnabled'] != false,
      maintenanceMode: data['maintenanceMode'] == true,
      maintenanceMessage: (data['maintenanceMessage'] ?? '').toString(),
      disabledReason: (data['disabledReason'] ?? '').toString(),
      onSitePaymentEnabled: data['onSitePaymentEnabled'] != false,
      bankTransferEnabled: data['bankTransferEnabled'] != false,
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'onlinePaymentEnabled': onlinePaymentEnabled,
      'ecpayEnabled': ecpayEnabled,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage.trim(),
      'disabledReason': disabledReason.trim(),
      'onSitePaymentEnabled': onSitePaymentEnabled,
      'bankTransferEnabled': bankTransferEnabled,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PlatformPaymentSettingModel copyWith({
    bool? onlinePaymentEnabled,
    bool? ecpayEnabled,
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? disabledReason,
    bool? onSitePaymentEnabled,
    bool? bankTransferEnabled,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlatformPaymentSettingModel(
      onlinePaymentEnabled: onlinePaymentEnabled ?? this.onlinePaymentEnabled,
      ecpayEnabled: ecpayEnabled ?? this.ecpayEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      disabledReason: disabledReason ?? this.disabledReason,
      onSitePaymentEnabled: onSitePaymentEnabled ?? this.onSitePaymentEnabled,
      bankTransferEnabled: bankTransferEnabled ?? this.bankTransferEnabled,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 尚未建立平台金流設定文件時使用的預設值
  factory PlatformPaymentSettingModel.initial() {
    final DateTime now = DateTime.now();

    return PlatformPaymentSettingModel(
      onlinePaymentEnabled: true,
      ecpayEnabled: true,
      maintenanceMode: false,
      maintenanceMessage: '',
      disabledReason: '',
      onSitePaymentEnabled: true,
      bankTransferEnabled: true,
      updatedBy: '',
      createdAt: now,
      updatedAt: now,
    );
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
