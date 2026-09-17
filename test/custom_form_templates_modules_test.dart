// 檔案名稱：test/custom_form_templates_modules_test.dart
// 功能說明：送出訂單與手動訂單建議初版題目範圍。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_order_form_answers.dart';
import 'package:petnest_saas/core/models/custom_form_default_templates.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';

void main() {
  test('送出訂單建議初版含三分類與訂單／寵物題目', () {
    final CustomFormModel form = CustomFormDefaultTemplates.create(
      shopId: 's1',
      formType: CustomFormType.bookingSubmit,
    );
    expect(
      form.sections.map((CustomFormSection item) => item.id).toList(),
      <String>['booking_care', 'booking_items', 'booking_other_request'],
    );
    expect(form.orderQuestionCount, 7);
    expect(form.petQuestionCount, 3);
    expect(
      form.sections
          .expand((CustomFormSection section) => section.questions)
          .any((CustomFormQuestion question) => question.label.contains('餵藥')),
      isFalse,
    );
    final CustomFormQuestion disease = form.sections.first.questions.firstWhere(
      (CustomFormQuestion question) => question.id == 'booking_pet_disease_care',
    );
    expect(disease.required, isFalse);
    expect(disease.answerScope, CustomFormAnswerScope.pet);
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: disease,
        pet: <String, dynamic>{
          'petId': 'a',
          'name': '一般寵物',
          'vaccine': '無',
        },
      ),
      isFalse,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: disease,
        pet: <String, dynamic>{
          'petId': 'b',
          'name': '有疾病寵物',
          'vaccine': '有疾病',
        },
      ),
      isTrue,
    );
  });

  test('手動訂單建議初版與送出訂單同範圍，疾病說明改店員語氣', () {
    final CustomFormModel form = CustomFormDefaultTemplates.create(
      shopId: 's1',
      formType: CustomFormType.adminCreate,
    );
    expect(
      form.sections.map((CustomFormSection item) => item.id).toList(),
      <String>['admin_care', 'admin_items', 'admin_other_request'],
    );
    expect(form.orderQuestionCount, 7);
    expect(form.petQuestionCount, 3);
    final CustomFormQuestion disease = form.sections.first.questions.firstWhere(
      (CustomFormQuestion question) => question.id == 'admin_pet_disease_care',
    );
    expect(disease.description, contains('請依會員提供資訊補充本次照護重點'));
    expect(
      BookingOrderFormAnswers.validatePet(
        form: form.copyWith(enabled: true),
        pet: <String, dynamic>{
          'petId': 'b',
          'name': '喵喵',
          'vaccine': '有疾病',
        },
        answersByQuestionId: const <String, dynamic>{},
      ).isValid,
      isTrue,
    );
  });

  test('只加入尚未有的模組，不重複塞入', () {
    CustomFormModel form = CustomFormModel.empty(
      shopId: 's1',
      formType: CustomFormType.petProfile,
    );
    form = CustomFormDefaultTemplates.mergeMissingModules(
      current: form,
      moduleIds: const <String>['pet_diet'],
    );
    expect(form.sections.length, 1);
    form = CustomFormDefaultTemplates.mergeMissingModules(
      current: form,
      moduleIds: const <String>['pet_diet', 'pet_health_care'],
    );
    expect(form.sections.map((CustomFormSection item) => item.id).toList(), <String>[
      'pet_diet',
      'pet_health_care',
    ]);
  });

  test('題型有簡短說明', () {
    expect(CustomFormQuestionType.singleChoice.labelWithHint, contains('只能選一個'));
    expect(CustomFormQuestionType.multipleChoice.labelWithHint, contains('可選多個'));
  });
}
