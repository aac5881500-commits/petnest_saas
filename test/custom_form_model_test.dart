// 檔案名稱：test/custom_form_model_test.dart
// 功能說明：自訂表單資料模型的單元測試（bool 維持原值）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';

void main() {
  group('CustomFormModel.parseBool', () {
    test('bool 維持原值', () {
      expect(CustomFormModel.parseBool(true), isTrue);
      expect(CustomFormModel.parseBool(false), isFalse);
    });

    test('num 0 為 false、非 0 為 true', () {
      expect(CustomFormModel.parseBool(0), isFalse);
      expect(CustomFormModel.parseBool(1), isTrue);
    });

    test('字串與缺漏欄位', () {
      expect(CustomFormModel.parseBool('true'), isTrue);
      expect(CustomFormModel.parseBool('0'), isFalse);
      expect(CustomFormModel.parseBool(null), isFalse);
      expect(CustomFormModel.parseBool(null, fallback: true), isTrue);
    });
  });

  test('文件不存在時使用空表單且不混用 formType', () {
    final CustomFormModel pet = CustomFormModel.empty(
      shopId: 'shop1',
      formType: CustomFormType.petProfile,
    );
    final CustomFormModel booking = CustomFormModel.empty(
      shopId: 'shop1',
      formType: CustomFormType.bookingSubmit,
    );
    expect(pet.id, 'pet_profile');
    expect(booking.id, 'booking_submit');
    expect(pet.enabled, isFalse);
    expect(pet.sections, isEmpty);
  });

  test('int 0/1 的 enabled、required 可解析', () {
    final CustomFormQuestion question =
        CustomFormQuestion.fromMap(<String, dynamic>{
          'id': 'q1',
          'label': '姓名',
          'required': 1,
          'enabled': 0,
          'type': 'shortText',
          'sortOrder': 0,
        });
    expect(question.required, isTrue);
    expect(question.enabled, isFalse);
  });
}
