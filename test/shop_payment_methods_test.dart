// 檔案名稱：test/shop_payment_methods_test.dart
// 功能說明：到店付款可關、至少一種有效方式、五種選項住宿／安親一致

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';

Map<String, dynamic> _shop({
  bool? cash,
  bool bank = true,
  bool ecpay = true,
  bool credit = true,
  bool atm = true,
  bool cvs = true,
  bool bankComplete = true,
  bool approved = true,
  bool depositEnabled = false,
}) {
  return <String, dynamic>{
    if (bankComplete) ...<String, String>{
      'bankName': '台灣銀行',
      'accountName': '毛孩旅館',
      'accountNumber': '123456789',
    } else ...<String, String>{
      'bankName': '',
      'accountName': '',
      'accountNumber': '',
    },
    'depositEnabled': depositEnabled,
    'paymentSetting': <String, dynamic>{
      'reviewStatus': approved ? 'approved' : 'pending',
      'creditCardEnabled': true,
      'atmEnabled': true,
      'cvsCodeEnabled': true,
      'enabledMethods': <String, dynamic>{
        'creditCard': true,
        'atm': true,
        'cvsCode': true,
      },
      'operationSettings': <String, dynamic>{
        if (cash != null) 'cashPaymentEnabled': cash,
        'bankTransferEnabled': bank,
        'ecpayEnabled': ecpay,
        'creditCardEnabled': credit,
        'atmEnabled': atm,
        'cvsCodeEnabled': cvs,
      },
    },
  };
}

void main() {
  test('舊資料沒有到店開關係視為開啟', () {
    final ShopPaymentCatalog catalog = ShopPaymentMethods.resolve(
      shopData: _shop(),
      serviceType: PolicyApplicableService.accommodation,
    );
    expect(catalog.isEnabled(PaymentMethodType.cash), isTrue);
  });

  test('到店付款可關閉', () {
    final ShopPaymentCatalog catalog = ShopPaymentMethods.resolve(
      shopData: _shop(cash: false),
      serviceType: PolicyApplicableService.accommodation,
    );
    expect(catalog.isEnabled(PaymentMethodType.cash), isFalse);
    expect(catalog.isEnabled(PaymentMethodType.bankTransfer), isTrue);
  });

  test('最後一種有效付款方式不能關閉', () {
    final ShopPaymentSettingsValidation result =
        ShopPaymentMethods.validateOperationSettings(
          shopData: _shop(
            cash: true,
            bank: false,
            ecpay: false,
            approved: false,
          ),
          cashPaymentEnabled: false,
          bankTransferEnabled: false,
          ecpayEnabled: false,
          creditCardEnabled: false,
          atmEnabled: false,
          cvsCodeEnabled: false,
        );
    expect(result.ok, isFalse);
    expect(result.message, ShopPaymentMethods.keepOneMessage);
  });

  test('綠界總開但三子方式全關不算可用', () {
    final Set<String> ids = ShopPaymentMethods.effectiveMethodIds(
      shopData: _shop(
        cash: false,
        bank: false,
        credit: false,
        atm: false,
        cvs: false,
      ),
    );
    expect(ids.contains(PaymentMethodType.creditCard), isFalse);
    expect(ids.contains(PaymentMethodType.atm), isFalse);
    expect(ids.contains(PaymentMethodType.convenienceStoreCode), isFalse);
  });

  test('銀行資料不完整時銀行轉帳不算可用', () {
    final Set<String> ids = ShopPaymentMethods.effectiveMethodIds(
      shopData: _shop(bankComplete: false),
    );
    expect(ids.contains(PaymentMethodType.bankTransfer), isFalse);
    final ShopPaymentSettingsValidation result =
        ShopPaymentMethods.validateOperationSettings(
          shopData: _shop(bankComplete: false),
          cashPaymentEnabled: true,
          bankTransferEnabled: true,
          ecpayEnabled: false,
          creditCardEnabled: false,
          atmEnabled: false,
          cvsCodeEnabled: false,
        );
    expect(result.ok, isFalse);
    expect(result.message, ShopPaymentMethods.bankAccountIncompleteMessage);
  });

  test('五種付款方式住宿與安親填寫頁清單一致', () {
    final Map<String, dynamic> shop = _shop();
    final ShopPaymentCatalog stay = ShopPaymentMethods.resolve(
      shopData: shop,
      serviceType: PolicyApplicableService.accommodation,
    );
    final ShopPaymentCatalog daycare = ShopPaymentMethods.resolve(
      shopData: shop,
      serviceType: PolicyApplicableService.daycare,
      daycareDepositType: 'none',
    );
    expect(stay.methodIds, daycare.methodIds);
    expect(stay.methodIds, <String>[
      PaymentMethodType.cash,
      PaymentMethodType.bankTransfer,
      PaymentMethodType.creditCard,
      PaymentMethodType.atm,
      PaymentMethodType.convenienceStoreCode,
    ]);
  });

  test('結算補款不含超商', () {
    final ShopPaymentCatalog catalog = ShopPaymentMethods.settlementTopUpCatalog(
      shopData: _shop(),
      serviceType: PolicyApplicableService.accommodation,
    );
    expect(catalog.methodIds.contains(PaymentMethodType.convenienceStoreCode), isFalse);
    expect(catalog.methodIds.contains(PaymentMethodType.cash), isTrue);
    expect(catalog.methodIds.contains(PaymentMethodType.creditCard), isTrue);
  });

  test('變更付款方式與填寫頁使用同一 resolver 結果', () {
    final Map<String, dynamic> shop = _shop(cash: false, cvs: false);
    final List<String> form = ShopPaymentMethods.resolve(
      shopData: shop,
      serviceType: PolicyApplicableService.accommodation,
    ).methodIds;
    final List<String> change = ShopPaymentMethods.resolve(
      shopData: shop,
      serviceType: PolicyApplicableService.daycare,
      daycareDepositType: 'fixed',
    ).methodIds;
    expect(form, change);
    expect(form.contains(PaymentMethodType.cash), isFalse);
    expect(form.contains(PaymentMethodType.convenienceStoreCode), isFalse);
  });

  test('已關閉方式舊訂單仍可顯示歷史值但不能再選', () {
    expect(ShopPaymentMethods.historyLabel('cash'), '到店付款');
    final ShopPaymentCatalog catalog = ShopPaymentMethods.resolve(
      shopData: _shop(cash: false),
      serviceType: PolicyApplicableService.accommodation,
    );
    expect(catalog.isEnabled(PaymentMethodType.cash), isFalse);
  });

  test('訂金模式到店付款有備註，非訂金模式沒有該句', () {
    final ShopPaymentCatalog stayDeposit = ShopPaymentMethods.resolve(
      shopData: _shop(depositEnabled: true),
      serviceType: PolicyApplicableService.accommodation,
    );
    final ShopPaymentCatalog stayFull = ShopPaymentMethods.resolve(
      shopData: _shop(depositEnabled: false),
      serviceType: PolicyApplicableService.accommodation,
    );
    final ShopPaymentCatalog daycareDeposit = ShopPaymentMethods.resolve(
      shopData: _shop(),
      serviceType: PolicyApplicableService.daycare,
      daycareDepositType: 'percent',
    );
    final ShopPaymentCatalog daycareNone = ShopPaymentMethods.resolve(
      shopData: _shop(),
      serviceType: PolicyApplicableService.daycare,
      daycareDepositType: 'none',
    );
    expect(
      stayDeposit.optionFor(PaymentMethodType.cash)?.subtitle,
      ShopPaymentMethods.cashDepositNoteStay,
    );
    expect(
      stayFull.optionFor(PaymentMethodType.cash)?.subtitle.contains('到店支付訂金'),
      isFalse,
    );
    expect(
      daycareDeposit.optionFor(PaymentMethodType.cash)?.subtitle,
      ShopPaymentMethods.cashDepositNoteDaycare,
    );
    expect(
      daycareNone
          .optionFor(PaymentMethodType.cash)
          ?.subtitle
          .contains('到店支付訂金'),
      isFalse,
    );
  });

  test('僅明確銀行轉帳才視為人工轉帳憑證', () {
    expect(ShopPaymentMethods.isManualBankTransferPayment('transfer'), isTrue);
    expect(
      ShopPaymentMethods.isManualBankTransferPayment('bank_transfer'),
      isTrue,
    );
    expect(
      ShopPaymentMethods.isManualBankTransferPayment('credit_card'),
      isFalse,
    );
    expect(ShopPaymentMethods.isManualBankTransferPayment('atm'), isFalse);
    expect(ShopPaymentMethods.isManualBankTransferPayment('cvs_code'), isFalse);
    expect(ShopPaymentMethods.isManualBankTransferPayment(''), isFalse);
    expect(ShopPaymentMethods.isManualBankTransferPayment(null), isFalse);
    expect(ShopPaymentMethods.isManualBankTransferPayment('銀行轉帳'), isFalse);
  });

  test('手動建單可提交僅到店與轉帳，並清掉綠界選取值', () {
    final ShopPaymentCatalog catalog = ShopPaymentMethods.resolve(
      shopData: _shop(),
      serviceType: PolicyApplicableService.accommodation,
    );
    expect(
      ShopPaymentMethods.isAdminCreateSelectable(PaymentMethodType.cash),
      isTrue,
    );
    expect(
      ShopPaymentMethods.isAdminCreateSelectable(
        PaymentMethodType.bankTransfer,
      ),
      isTrue,
    );
    expect(
      ShopPaymentMethods.isAdminCreateSelectable(PaymentMethodType.creditCard),
      isFalse,
    );
    expect(
      ShopPaymentMethods.adminCreateOnlineInfoCatalog(catalog).methodIds,
      containsAll(<String>[
        PaymentMethodType.creditCard,
        PaymentMethodType.atm,
        PaymentMethodType.convenienceStoreCode,
      ]),
    );
    expect(
      ShopPaymentMethods.coerceAdminCreateMethod(
        catalog: catalog,
        selected: PaymentMethodType.creditCard,
      ),
      PaymentMethodType.cash,
    );
  });
}
