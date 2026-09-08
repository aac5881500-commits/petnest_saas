// 檔案名稱：test/pet_shop_form_answers_test.dart
// 功能說明：寵物店家表單答案子集合路徑、舊 nested map 相容讀取，以及不互相覆蓋。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';

void main() {
  test('答案路徑依 shopId 獨立，不用固定店家', () {
    expect(
      PetShopFormAnswers.path(
        userId: 'user-1',
        petId: 'pet-1',
        shopId: 'shop-a',
      ),
      'user_profiles/user-1/pets/pet-1/shop_form_answers/shop-a',
    );
    expect(
      PetShopFormAnswers.path(
        userId: 'user-1',
        petId: 'pet-1',
        shopId: 'shop-b',
      ),
      'user_profiles/user-1/pets/pet-1/shop_form_answers/shop-b',
    );
    expect(
      PetShopFormAnswers.path(
        userId: 'user-1',
        petId: 'pet-1',
        shopId: 'shop-a',
      ).contains('SHOP0001'),
      isFalse,
    );
  });

  test('表單未啟用或沒有答案時不應寫入空文件', () {
    expect(PetShopFormAnswers.shouldWrite(null), isFalse);
    expect(PetShopFormAnswers.shouldWrite(<String, dynamic>{}), isFalse);
    expect(
      PetShopFormAnswers.shouldWrite(<String, dynamic>{'answers': <dynamic>[]}),
      isFalse,
    );
    expect(
      PetShopFormAnswers.shouldWrite(<String, dynamic>{
        'formId': 'pet_profile',
        'answers': <Map<String, dynamic>>[
          <String, dynamic>{'questionId': 'q1'},
        ],
      }),
      isTrue,
    );
  });

  test('子集合資料優先，舊 customFormAnswersByShop 只讀目前店家', () {
    final Map<String, dynamic> pet = <String, dynamic>{
      'customFormAnswersByShop': <String, dynamic>{
        'shop-a': <String, dynamic>{'formId': 'legacy-a', 'formTitle': 'A'},
        'shop-b': <String, dynamic>{'formId': 'legacy-b', 'formTitle': 'B'},
      },
    };
    final Map<String, dynamic>? fromLegacy = PetShopFormAnswers.resolve(
      shopId: 'shop-a',
      petData: pet,
    );
    expect(fromLegacy?['formId'], 'legacy-a');
    expect(fromLegacy?.containsValue('legacy-b'), isFalse);

    final Map<String, dynamic>? fromSub = PetShopFormAnswers.resolve(
      shopId: 'shop-a',
      subcollectionData: <String, dynamic>{
        'shopId': 'shop-a',
        'formId': 'sub-a',
      },
      petData: pet,
    );
    expect(fromSub?['formId'], 'sub-a');
    expect(fromSub?['shopId'], 'shop-a');
  });

  test('寫入文件帶目前 shopId，不把其他店答案放在同一 map', () {
    final Map<String, dynamic> data = PetShopFormAnswers.documentData(
      shopId: 'shop-a',
      snapshot: <String, dynamic>{
        'formId': 'pet_profile',
        'formType': 'pet_profile',
        'answers': <dynamic>[],
      },
    );
    expect(data['shopId'], 'shop-a');
    expect(data.containsKey('customFormAnswersByShop'), isFalse);
    expect(data['shop-b'], isNull);
  });
}
