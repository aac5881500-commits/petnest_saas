// lib/core/services/platform_payment_setting_service.dart
// 💳 PetNest 全平台金流設定 Service
// 功能：讀取並監聽平台金流總開關、綠界狀態與維護狀態。
// 注意：目前僅提供讀取功能，平台設定寫入之後由平台管理權限處理。

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/platform_payment_setting_model.dart';

class PlatformPaymentSettingService {
  PlatformPaymentSettingService._();

  static final PlatformPaymentSettingService instance =
      PlatformPaymentSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 平台全域金流設定文件
  ///
  /// Firestore 路徑：
  /// platform_payment_settings/global
  DocumentReference<Map<String, dynamic>> get _settingReference {
    return _firestore.collection('platform_payment_settings').doc('global');
  }

  /// 一次取得平台金流設定
  ///
  /// 尚未建立文件時回傳預設設定，
  /// 不會由 Flutter 自動寫入 Firestore。
  Future<PlatformPaymentSettingModel> getSetting() async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _settingReference.get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return PlatformPaymentSettingModel.initial();
    }

    return PlatformPaymentSettingModel.fromMap(data);
  }

  /// 即時監聽平台金流設定
  ///
  /// 尚未建立文件時回傳預設設定。
  Stream<PlatformPaymentSettingModel> streamSetting() {
    return _settingReference.snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return PlatformPaymentSettingModel.initial();
      }

      return PlatformPaymentSettingModel.fromMap(data);
    });
  }

  /// 一次判斷全平台目前是否可使用綠界
  Future<bool> canUseEcpay() async {
    final PlatformPaymentSettingModel setting = await getSetting();

    return setting.canUseEcpay;
  }

  /// 即時監聽全平台是否可使用綠界
  Stream<bool> streamCanUseEcpay() {
    return streamSetting().map((PlatformPaymentSettingModel setting) {
      return setting.canUseEcpay;
    });
  }

  /// 一次取得平台線上付款不可用原因
  ///
  /// 回傳空字串代表平台目前允許使用綠界。
  Future<String> getUnavailableMessage() async {
    final PlatformPaymentSettingModel setting = await getSetting();

    return setting.unavailableMessage;
  }

  /// 即時監聽平台線上付款不可用原因
  Stream<String> streamUnavailableMessage() {
    return streamSetting().map((PlatformPaymentSettingModel setting) {
      return setting.unavailableMessage;
    });
  }

  /// 一次判斷平台是否允許現場付款
  Future<bool> canUseOnSitePayment() async {
    final PlatformPaymentSettingModel setting = await getSetting();

    return setting.onSitePaymentEnabled;
  }

  /// 即時監聽平台是否允許現場付款
  Stream<bool> streamCanUseOnSitePayment() {
    return streamSetting().map((PlatformPaymentSettingModel setting) {
      return setting.onSitePaymentEnabled;
    });
  }

  /// 一次判斷平台是否允許人工銀行轉帳
  ///
  /// 這裡指既有人工上傳轉帳證明流程，
  /// 不包含綠界 ATM 虛擬帳號。
  Future<bool> canUseBankTransfer() async {
    final PlatformPaymentSettingModel setting = await getSetting();

    return setting.bankTransferEnabled;
  }

  /// 即時監聽平台是否允許人工銀行轉帳
  Stream<bool> streamCanUseBankTransfer() {
    return streamSetting().map((PlatformPaymentSettingModel setting) {
      return setting.bankTransferEnabled;
    });
  }
}
