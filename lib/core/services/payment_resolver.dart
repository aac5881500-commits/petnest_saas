// lib/core/services/payment_resolver.dart
// 💳 共用付款方式解析器
// 功能：依店家金流設定、平台狀態與本次收款類型，
// 統一判斷會員目前可以使用哪些付款方式。

import '../models/payment_gateway_status.dart';
import '../models/payment_setting_model.dart';
import '../models/platform_payment_setting_model.dart';

class PaymentResolver {
  PaymentResolver._();

  /// 取得會員目前可以使用的付款方式
  ///
  /// [setting] 店家金流公開設定。
  /// [amountType] 本次要收訂金或全額。
  /// [platformSetting] PetNest 平台全域金流設定。
  ///
  /// 回傳值可能包含：
  /// cash、credit_card、atm、cvs_code。
  static List<String> resolveAvailableMethods({
    required PaymentSettingModel setting,
    required String amountType,
    PlatformPaymentSettingModel? platformSetting,
  }) {
    final PlatformPaymentSettingModel resolvedPlatformSetting =
        platformSetting ?? PlatformPaymentSettingModel.initial();

    final List<String> methods = <String>[];

    if (!_isAmountTypeEnabled(setting: setting, amountType: amountType)) {
      return methods;
    }

    /// 現場付款不依賴綠界，
    /// 但仍需同時通過店家與平台開關。
    if (setting.canUseOnSitePayment &&
        resolvedPlatformSetting.onSitePaymentEnabled) {
      methods.add(PaymentMethodType.cash);
    }

    /// 平台暫停線上付款或綠界維護時，
    /// 保留已加入的現場付款，不再加入線上付款方式。
    if (!resolvedPlatformSetting.canUseEcpay) {
      return methods;
    }

    /// 店家本身未通過審核、未啟用或被暫停時，
    /// 不加入任何線上付款方式。
    if (!setting.canCreateOnlinePayment) {
      return methods;
    }

    if (setting.creditCardEnabled) {
      methods.add(PaymentMethodType.creditCard);
    }

    if (setting.atmEnabled) {
      methods.add(PaymentMethodType.atm);
    }

    if (setting.convenienceStoreCodeEnabled) {
      methods.add(PaymentMethodType.convenienceStoreCode);
    }

    return methods;
  }

  /// 判斷指定付款方式目前是否可用
  static bool canUseMethod({
    required PaymentSettingModel setting,
    required String paymentMethod,
    required String amountType,
    PlatformPaymentSettingModel? platformSetting,
  }) {
    return resolveAvailableMethods(
      setting: setting,
      amountType: amountType,
      platformSetting: platformSetting,
    ).contains(paymentMethod);
  }

  /// 店家目前是否可以建立線上付款
  static bool canCreateOnlinePayment({
    required PaymentSettingModel setting,
    required String amountType,
    PlatformPaymentSettingModel? platformSetting,
  }) {
    final PlatformPaymentSettingModel resolvedPlatformSetting =
        platformSetting ?? PlatformPaymentSettingModel.initial();

    if (!resolvedPlatformSetting.canUseEcpay) {
      return false;
    }

    if (!_isAmountTypeEnabled(setting: setting, amountType: amountType)) {
      return false;
    }

    return setting.canCreateOnlinePayment;
  }

  /// 店家目前是否至少有一種付款方式可用
  static bool hasAvailablePaymentMethod({
    required PaymentSettingModel setting,
    required String amountType,
    PlatformPaymentSettingModel? platformSetting,
  }) {
    return resolveAvailableMethods(
      setting: setting,
      amountType: amountType,
      platformSetting: platformSetting,
    ).isNotEmpty;
  }

  /// 判斷本次收款類型是否已啟用
  static bool isAmountTypeEnabled({
    required PaymentSettingModel setting,
    required String amountType,
  }) {
    return _isAmountTypeEnabled(setting: setting, amountType: amountType);
  }

  /// 取得線上付款目前不可用的原因
  ///
  /// 回傳空字串代表線上付款可以正常使用。
  static String resolveOnlinePaymentUnavailableReason({
    required PaymentSettingModel setting,
    required String amountType,
    PlatformPaymentSettingModel? platformSetting,
  }) {
    final PlatformPaymentSettingModel resolvedPlatformSetting =
        platformSetting ?? PlatformPaymentSettingModel.initial();

    /// 先檢查平台總開關。
    if (!resolvedPlatformSetting.canUseEcpay) {
      final String platformMessage = resolvedPlatformSetting.unavailableMessage
          .trim();

      return platformMessage.isNotEmpty ? platformMessage : '平台目前暫停線上付款功能。';
    }

    if (setting.shopDisabled) {
      return '店家目前已關閉線上付款。';
    }

    if (setting.platformSuspended) {
      return '此店家的線上付款目前已被平台暫停。';
    }

    if (setting.reviewStatus == PaymentGatewayReviewStatus.notConfigured) {
      return '店家尚未完成線上付款設定。';
    }

    if (setting.reviewStatus == PaymentGatewayReviewStatus.draft) {
      return '店家的線上付款設定尚未送出審核。';
    }

    if (setting.reviewStatus == PaymentGatewayReviewStatus.pending) {
      return '店家的線上付款設定正在等待平台審核。';
    }

    if (setting.reviewStatus == PaymentGatewayReviewStatus.rejected) {
      return setting.reviewMessage.trim().isNotEmpty
          ? setting.reviewMessage.trim()
          : '店家的線上付款設定未通過平台審核。';
    }

    if (setting.reviewStatus == PaymentGatewayReviewStatus.suspended) {
      return '此店家的線上付款目前已被平台暫停。';
    }

    if (setting.reviewStatus == PaymentGatewayReviewStatus.disabled) {
      return '店家的線上付款目前已停用。';
    }

    if (!setting.isApproved) {
      return '店家的線上付款尚未通過平台審核。';
    }

    if (!setting.productionEnabled) {
      return '店家的正式金流環境尚未啟用。';
    }

    if (!setting.onlinePaymentEnabled) {
      return '店家目前未開啟線上付款。';
    }

    if (!setting.hasOnlinePaymentMethod) {
      return '店家目前未開啟任何線上付款方式。';
    }

    if (!_isAmountTypeEnabled(setting: setting, amountType: amountType)) {
      if (amountType == PaymentAmountType.deposit) {
        return '店家目前未開放線上收取訂金。';
      }

      if (amountType == PaymentAmountType.full) {
        return '店家目前未開放線上收取全額。';
      }

      return '目前不支援這個收款類型。';
    }

    return '';
  }

  /// 取得會員付款方式顯示名稱
  static String resolveMethodLabel(String paymentMethod) {
    switch (paymentMethod) {
      case PaymentMethodType.cash:
        return '現場付款';

      case PaymentMethodType.bankTransfer:
        return '銀行轉帳';

      case PaymentMethodType.creditCard:
        return '信用卡';

      case PaymentMethodType.atm:
        return 'ATM 虛擬帳號';

      case PaymentMethodType.convenienceStoreCode:
        return '超商代碼';

      default:
        return '其他付款方式';
    }
  }

  /// 取得收款類型顯示名稱
  static String resolveAmountTypeLabel(String amountType) {
    switch (amountType) {
      case PaymentAmountType.deposit:
        return '訂金';

      case PaymentAmountType.full:
        return '全額';

      default:
        return '付款金額';
    }
  }

  static bool _isAmountTypeEnabled({
    required PaymentSettingModel setting,
    required String amountType,
  }) {
    switch (amountType) {
      case PaymentAmountType.deposit:
        return setting.depositPaymentEnabled;

      case PaymentAmountType.full:
        return setting.fullPaymentEnabled;

      default:
        return false;
    }
  }
}
