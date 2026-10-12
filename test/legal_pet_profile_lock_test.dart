// 檔案名稱：test/legal_pet_profile_lock_test.dart
// 功能說明：確認首次地址鎖定與查核結果失效條件。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/legal_pet/shop_profile_lock.dart';

void main() {
  test('已填地址不會因電話空白或尚未認證而解鎖', () {
    final shop = {
      'address': '公正街1號',
      'phone': '',
      'licenseVerified': false,
    };
    expect(isAddressSetupCompleted(shop), isTrue);
    expect(isPhoneSetupCompleted(shop), isFalse);
  });

  test('只有縣市、尚未填詳細地址時仍可首次確認', () {
    expect(
      isAddressSetupCompleted({'city': '新北市', 'district': '三芝區', 'address': ''}),
      isFalse,
    );
  });

  test('字號或地址一改，舊查核結果就失效', () {
    const saved = LegalPetLookupInputs(
      license: '特寵業字第A1號',
      city: '新北市',
      district: '三芝區',
      address: '公正街1號',
    );
    expect(
      saved.matches(
        const LegalPetLookupInputs(
          license: '特寵業字第A1號',
          city: '新北市',
          district: '三芝區',
          address: '公正街1號',
        ),
      ),
      isTrue,
    );
    expect(
      saved.matches(
        const LegalPetLookupInputs(
          license: '特寵業字第B2號',
          city: '新北市',
          district: '三芝區',
          address: '公正街1號',
        ),
      ),
      isFalse,
    );
    expect(
      saved.matches(
        const LegalPetLookupInputs(
          license: '特寵業字第A1號',
          city: '新北市',
          district: '三芝區',
          address: '公正街2號',
        ),
      ),
      isFalse,
    );
  });
}
