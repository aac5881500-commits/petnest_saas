// 檔案名稱：lib/core/services/shop_payment_methods.dart
// 功能說明：店家客戶可用付款方式的唯一解析來源（住宿／安親共用）

import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';

class ShopPaymentMethodOption {
  const ShopPaymentMethodOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class ShopPaymentCatalog {
  const ShopPaymentCatalog({
    required this.methods,
    required this.isDepositMode,
    required this.serviceType,
  });

  final List<ShopPaymentMethodOption> methods;
  final bool isDepositMode;
  final String serviceType;

  bool get isEmpty => methods.isEmpty;

  List<String> get methodIds =>
      methods.map((ShopPaymentMethodOption e) => e.id).toList();

  bool isEnabled(String paymentMethod) => methodIds.contains(paymentMethod);

  ShopPaymentMethodOption? optionFor(String paymentMethod) {
    for (final ShopPaymentMethodOption item in methods) {
      if (item.id == paymentMethod) {
        return item;
      }
    }
    return null;
  }
}

class ShopPaymentSettingsValidation {
  const ShopPaymentSettingsValidation({required this.ok, this.message = ''});

  final bool ok;
  final String message;
}

class ShopPaymentMethods {
  ShopPaymentMethods._();

  static const String noMethodsMessage = '店家目前未提供可用付款方式，請聯絡店家';
  static const String keepOneMessage = '請至少保留一種收款方式。';
  static const String bankAccountIncompleteMessage = '請先補齊銀行名稱、戶名與帳號。';
  static const String cashDepositNoteSettings = '到店支付訂金，剩餘款項於退房／接回時結清。';
  static const String cashDepositNoteStay = '到店支付訂金，剩餘款項於退房時結清。';
  static const String cashDepositNoteDaycare = '到店支付訂金，剩餘款項於接回時結清。';

  static bool flag(dynamic value, {required bool fallback}) {
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value == 1;
    }
    final String raw = value.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes' || raw == 'enabled') {
      return true;
    }
    if (raw == 'false' || raw == '0' || raw == 'no' || raw == 'disabled') {
      return false;
    }
    return fallback;
  }

  static Map<String, dynamic> mapOf(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  static bool isBankAccountComplete(Map<String, dynamic> shopData) {
    final String bankName = (shopData['bankName'] ?? '').toString().trim();
    final String accountName = (shopData['accountName'] ?? '')
        .toString()
        .trim();
    final String accountNumber = (shopData['accountNumber'] ?? '')
        .toString()
        .trim();
    return bankName.isNotEmpty &&
        accountName.isNotEmpty &&
        accountNumber.isNotEmpty;
  }

  static bool isCashEnabled(Map<String, dynamic> operationSettings) {
    return flag(operationSettings['cashPaymentEnabled'], fallback: true);
  }

  static bool isBankTransferSwitchOn(Map<String, dynamic> operationSettings) {
    return flag(operationSettings['bankTransferEnabled'], fallback: true);
  }

  static bool isStayDepositMode(Map<String, dynamic> shopData) {
    return flag(shopData['depositEnabled'], fallback: false);
  }

  static bool isDaycareDepositMode(String? daycareDepositType) {
    return daycareDepositType == 'fixed' || daycareDepositType == 'percent';
  }

  static String cashDepositNoteForService(String serviceType) {
    return serviceType == PolicyApplicableService.daycare
        ? cashDepositNoteDaycare
        : cashDepositNoteStay;
  }

  static String historyLabel(String paymentMethod) {
    switch (paymentMethod) {
      case PaymentMethodType.cash:
      case 'pay_at_store':
      case 'onsite':
        return '到店付款';
      case PaymentMethodType.bankTransfer:
      case 'bank_transfer':
        return '銀行轉帳';
      case PaymentMethodType.creditCard:
      case 'ecpay_credit':
        return '信用卡';
      case PaymentMethodType.atm:
      case 'ecpay_atm':
        return 'ATM 虛擬帳號';
      case PaymentMethodType.convenienceStoreCode:
      case 'ecpay_cvs':
        return '超商代碼';
      default:
        return paymentMethod.trim().isEmpty ? '未設定' : paymentMethod;
    }
  }

  /// 僅銀行轉帳（正規化值 `transfer`／`bank_transfer`）才顯示付款憑證。
  /// 付款方式缺失或無法判定時不顯示。
  static bool isManualBankTransferPayment(dynamic value) {
    final String id = normalizeMethodId((value ?? '').toString());
    return id == PaymentMethodType.bankTransfer;
  }

  static String bookingPaymentMethodId(Map<String, dynamic> data) {
    return normalizeMethodId(
      (data['lastPaymentMethod'] ?? data['paymentMethod'] ?? '').toString(),
    );
  }

  /// 手機版「查看完整交易」：僅第三方金流（信用卡／ATM／超商）才有綠界交易可看。
  static bool hasThirdPartyGatewayTransaction(Map<String, dynamic> data) {
    if (isManualBankTransferPayment(data['paymentMethod']) ||
        isManualBankTransferPayment(data['lastPaymentMethod'])) {
      return false;
    }
    final String method = bookingPaymentMethodId(data);
    if (PaymentMethodType.isOnlinePayment(method)) {
      return true;
    }
    final String tradeNo = (data['merchantTradeNo'] ??
            data['ecpayTradeNo'] ??
            data['TradeNo'] ??
            '')
        .toString()
        .trim();
    return tradeNo.isNotEmpty;
  }

  static String normalizeMethodId(String paymentMethod) {
    switch (paymentMethod.trim().toLowerCase()) {
      case 'pay_at_store':
      case 'onsite':
      case PaymentMethodType.cash:
        return PaymentMethodType.cash;
      case 'bank_transfer':
      case PaymentMethodType.bankTransfer:
        return PaymentMethodType.bankTransfer;
      case 'ecpay_credit':
      case PaymentMethodType.creditCard:
        return PaymentMethodType.creditCard;
      case 'ecpay_atm':
      case PaymentMethodType.atm:
        return PaymentMethodType.atm;
      case 'ecpay_cvs':
      case PaymentMethodType.convenienceStoreCode:
        return PaymentMethodType.convenienceStoreCode;
      default:
        return paymentMethod.trim().toLowerCase();
    }
  }

  static bool ecpayMasterUsable({
    required Map<String, dynamic> paymentSetting,
    required Map<String, dynamic> operationSettings,
  }) {
    final String reviewStatus = (paymentSetting['reviewStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (reviewStatus != 'approved') {
      return false;
    }
    if (flag(paymentSetting['platformSuspended'], fallback: false) ||
        flag(paymentSetting['shopDisabled'], fallback: false)) {
      return false;
    }
    return flag(operationSettings['ecpayEnabled'], fallback: false);
  }

  static bool _approvedOnlineMethod({
    required Map<String, dynamic> paymentSetting,
    required String enabledMethodsKey,
    required String settingKey,
    String? altSettingKey,
  }) {
    final Map<String, dynamic> approved = mapOf(
      paymentSetting['enabledMethods'],
    );
    return flag(approved[enabledMethodsKey], fallback: false) ||
        flag(paymentSetting[settingKey], fallback: false) ||
        (altSettingKey == null
            ? false
            : flag(paymentSetting[altSettingKey], fallback: false));
  }

  static Set<String> effectiveMethodIds({
    required Map<String, dynamic> shopData,
    Map<String, dynamic>? operationOverride,
    bool? cashOverride,
    bool? bankTransferOverride,
    bool? ecpayOverride,
    bool? creditCardOverride,
    bool? atmOverride,
    bool? cvsOverride,
    bool? bankCompleteOverride,
  }) {
    final Map<String, dynamic> paymentSetting = mapOf(
      shopData['paymentSetting'],
    );
    final Map<String, dynamic> operationSettings =
        operationOverride ?? mapOf(paymentSetting['operationSettings']);
    final bool cashOn = cashOverride ?? isCashEnabled(operationSettings);
    final bool bankOn =
        bankTransferOverride ?? isBankTransferSwitchOn(operationSettings);
    final bool bankComplete =
        bankCompleteOverride ?? isBankAccountComplete(shopData);
    final bool ecpayOn =
        ecpayOverride ??
        ecpayMasterUsable(
          paymentSetting: paymentSetting,
          operationSettings: operationSettings,
        );
    final bool creditOn =
        creditCardOverride ??
        flag(operationSettings['creditCardEnabled'], fallback: false);
    final bool atmOn =
        atmOverride ?? flag(operationSettings['atmEnabled'], fallback: false);
    final bool cvsOn =
        cvsOverride ??
        flag(operationSettings['cvsCodeEnabled'], fallback: false);

    final Set<String> ids = <String>{};
    if (cashOn) {
      ids.add(PaymentMethodType.cash);
    }
    if (bankOn && bankComplete) {
      ids.add(PaymentMethodType.bankTransfer);
    }
    if (ecpayOn) {
      if (creditOn &&
          _approvedOnlineMethod(
            paymentSetting: paymentSetting,
            enabledMethodsKey: 'creditCard',
            settingKey: 'creditCardEnabled',
          )) {
        ids.add(PaymentMethodType.creditCard);
      }
      if (atmOn &&
          _approvedOnlineMethod(
            paymentSetting: paymentSetting,
            enabledMethodsKey: 'atm',
            settingKey: 'atmEnabled',
          )) {
        ids.add(PaymentMethodType.atm);
      }
      if (cvsOn &&
          _approvedOnlineMethod(
            paymentSetting: paymentSetting,
            enabledMethodsKey: 'cvsCode',
            settingKey: 'cvsCodeEnabled',
            altSettingKey: 'convenienceStoreCodeEnabled',
          )) {
        ids.add(PaymentMethodType.convenienceStoreCode);
      }
    }
    return ids;
  }

  /// 設定頁／後端寫入：有效客戶可用方式（綠界未核准時三子方式都不算）
  static ShopPaymentSettingsValidation validateOperationSettings({
    required Map<String, dynamic> shopData,
    required bool cashPaymentEnabled,
    required bool bankTransferEnabled,
    required bool ecpayEnabled,
    required bool creditCardEnabled,
    required bool atmEnabled,
    required bool cvsCodeEnabled,
  }) {
    if (bankTransferEnabled && !isBankAccountComplete(shopData)) {
      return const ShopPaymentSettingsValidation(
        ok: false,
        message: bankAccountIncompleteMessage,
      );
    }
    final Set<String> counted = effectiveMethodIds(
      shopData: shopData,
      cashOverride: cashPaymentEnabled,
      bankTransferOverride: bankTransferEnabled,
      creditCardOverride: creditCardEnabled,
      atmOverride: atmEnabled,
      cvsOverride: cvsCodeEnabled,
      operationOverride: <String, dynamic>{
        'cashPaymentEnabled': cashPaymentEnabled,
        'bankTransferEnabled': bankTransferEnabled,
        'ecpayEnabled': ecpayEnabled,
        'creditCardEnabled': creditCardEnabled,
        'atmEnabled': atmEnabled,
        'cvsCodeEnabled': cvsCodeEnabled,
      },
    );
    if (counted.isEmpty) {
      return const ShopPaymentSettingsValidation(
        ok: false,
        message: keepOneMessage,
      );
    }
    return const ShopPaymentSettingsValidation(ok: true);
  }

  static ShopPaymentCatalog resolve({
    required Map<String, dynamic> shopData,
    required String serviceType,
    String? daycareDepositType,
    bool? stayDepositOverride,
  }) {
    final bool depositMode = serviceType == PolicyApplicableService.daycare
        ? isDaycareDepositMode(daycareDepositType)
        : (stayDepositOverride ?? isStayDepositMode(shopData));
    final Set<String> ids = effectiveMethodIds(shopData: shopData);
    final List<ShopPaymentMethodOption> methods = <ShopPaymentMethodOption>[];
    if (ids.contains(PaymentMethodType.cash)) {
      methods.add(
        ShopPaymentMethodOption(
          id: PaymentMethodType.cash,
          title: '到店付款',
          subtitle: depositMode
              ? cashDepositNoteForService(serviceType)
              : (serviceType == PolicyApplicableService.daycare
                    ? '會員到店付款，可於接回時結清。'
                    : '會員到店付款，可於退房時結清。'),
        ),
      );
    }
    if (ids.contains(PaymentMethodType.bankTransfer)) {
      methods.add(
        const ShopPaymentMethodOption(
          id: PaymentMethodType.bankTransfer,
          title: '銀行轉帳',
          subtitle: '依店家銀行帳戶轉帳',
        ),
      );
    }
    if (ids.contains(PaymentMethodType.creditCard)) {
      methods.add(
        const ShopPaymentMethodOption(
          id: PaymentMethodType.creditCard,
          title: '信用卡',
          subtitle: '透過綠界線上付款',
        ),
      );
    }
    if (ids.contains(PaymentMethodType.atm)) {
      methods.add(
        const ShopPaymentMethodOption(
          id: PaymentMethodType.atm,
          title: 'ATM 虛擬帳號',
          subtitle: '取得專屬帳號後轉帳',
        ),
      );
    }
    if (ids.contains(PaymentMethodType.convenienceStoreCode)) {
      methods.add(
        const ShopPaymentMethodOption(
          id: PaymentMethodType.convenienceStoreCode,
          title: '超商代碼',
          subtitle: '取得繳費代碼後至超商付款',
        ),
      );
    }
    return ShopPaymentCatalog(
      methods: methods,
      isDepositMode: depositMode,
      serviceType: serviceType,
    );
  }

  static bool isSettlementTopUpMethod(String paymentMethod) {
    final String id = normalizeMethodId(paymentMethod);
    return id == PaymentMethodType.cash ||
        id == PaymentMethodType.bankTransfer ||
        id == PaymentMethodType.creditCard ||
        id == PaymentMethodType.atm;
  }

  static ShopPaymentCatalog settlementTopUpCatalog({
    required Map<String, dynamic> shopData,
    required String serviceType,
  }) {
    final ShopPaymentCatalog full = resolve(
      shopData: shopData,
      serviceType: serviceType,
    );
    return ShopPaymentCatalog(
      methods: full.methods
          .where(
            (ShopPaymentMethodOption item) =>
                isSettlementTopUpMethod(item.id),
          )
          .map((ShopPaymentMethodOption item) {
            if (item.id == PaymentMethodType.cash) {
              return const ShopPaymentMethodOption(
                id: PaymentMethodType.cash,
                title: '店內付款',
                subtitle: '店員確認已收到款項後才入帳，選擇此方式不代表已收款。',
              );
            }
            return item;
          })
          .toList(),
      isDepositMode: false,
      serviceType: serviceType,
    );
  }

  static bool isAdminCreateSelectable(String paymentMethod) {
    final String id = normalizeMethodId(paymentMethod);
    return id == PaymentMethodType.cash || id == PaymentMethodType.bankTransfer;
  }

  static ShopPaymentCatalog adminCreateSelectableCatalog(
    ShopPaymentCatalog catalog,
  ) {
    return ShopPaymentCatalog(
      methods: catalog.methods
          .where(
            (ShopPaymentMethodOption item) => isAdminCreateSelectable(item.id),
          )
          .toList(),
      isDepositMode: catalog.isDepositMode,
      serviceType: catalog.serviceType,
    );
  }

  static ShopPaymentCatalog adminCreateOnlineInfoCatalog(
    ShopPaymentCatalog catalog,
  ) {
    return ShopPaymentCatalog(
      methods: catalog.methods
          .where(
            (ShopPaymentMethodOption item) =>
                PaymentMethodType.isOnlinePayment(item.id),
          )
          .toList(),
      isDepositMode: catalog.isDepositMode,
      serviceType: catalog.serviceType,
    );
  }

  static String? firstAdminCreateMethod(ShopPaymentCatalog catalog) {
    final List<String> ids = adminCreateSelectableCatalog(catalog).methodIds;
    return ids.isEmpty ? null : ids.first;
  }

  static String? coerceAdminCreateMethod({
    required ShopPaymentCatalog catalog,
    required String? selected,
  }) {
    final ShopPaymentCatalog selectable = adminCreateSelectableCatalog(catalog);
    if (selected != null && selectable.isEnabled(selected)) {
      return selected;
    }
    return firstAdminCreateMethod(catalog);
  }
}
