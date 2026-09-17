// 檔案名稱：test/custom_form_order_pet_scope_test.dart
// 功能說明：訂單／寵物題目範圍、顯示條件與每隻寵物答案互不覆蓋。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_order_form_answers.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/features/custom_form/widgets/order_custom_form_fill.dart';

void main() {
  const CustomFormQuestion generalPet = CustomFormQuestion(
    id: 'q_care',
    label: '日常備註',
    answerScope: CustomFormAnswerScope.pet,
  );
  const CustomFormQuestion diseasePet = CustomFormQuestion(
    id: 'q_med',
    label: '藥物名稱',
    required: true,
    answerScope: CustomFormAnswerScope.pet,
    displayCondition: CustomFormDisplayCondition(
      field: 'medicalStatus',
      value: '有疾病',
    ),
  );

  CustomFormModel fillForm() {
    return CustomFormModel(
      id: 'booking_submit',
      shopId: 'shop-a',
      formType: CustomFormType.bookingSubmit,
      title: '送出訂單表單',
      enabled: true,
      version: 1,
      sections: <CustomFormSection>[
        CustomFormSection(
          id: 'sec',
          title: '照護',
          questions: <CustomFormQuestion>[
            const CustomFormQuestion(
              id: 'q_note',
              label: '接送需求',
              required: true,
            ),
            generalPet,
            diseasePet,
          ],
        ),
      ],
    );
  }

  CustomFormModel form() {
    return CustomFormModel(
      id: 'booking_submit',
      shopId: 'shop-a',
      formType: CustomFormType.bookingSubmit,
      title: '送出訂單表單',
      enabled: true,
      version: 1,
      sections: <CustomFormSection>[
        CustomFormSection(
          id: 'sec',
          title: '照護',
          questions: <CustomFormQuestion>[
            const CustomFormQuestion(
              id: 'q_note',
              label: '接送需求',
              required: true,
            ),
            diseasePet,
          ],
        ),
      ],
    );
  }

  test('缺欄位的題目視為訂單資訊', () {
    final CustomFormQuestion question = CustomFormQuestion.fromMap(
      <String, dynamic>{'id': 'q1', 'label': '備註', 'required': true},
    );
    expect(question.answerScope, CustomFormAnswerScope.order);
    expect(question.toMap()['required'], isTrue);
    expect(question.toMap()['petRequired'], isFalse);
  });

  test('寵物必填寫入 petRequired 且 Cloud Function 看到 required false', () {
    const CustomFormQuestion question = CustomFormQuestion(
      id: 'q_med',
      label: '藥',
      required: true,
      answerScope: CustomFormAnswerScope.pet,
    );
    expect(question.toMap()['required'], isFalse);
    expect(question.toMap()['petRequired'], isTrue);
    expect(question.collectsRequired, isTrue);
  });

  test('vaccine = 無：一般題可見、疾病題不可見', () {
    final Map<String, dynamic> pet = <String, dynamic>{
      'petId': 'a',
      'name': '毛毛',
      'vaccine': '無',
    };
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: generalPet,
        pet: pet,
      ),
      isTrue,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: diseasePet,
        pet: pet,
      ),
      isFalse,
    );
    expect(PetSnapshot.hasRecordedDisease(pet), isFalse);
  });

  test('vaccine = 心臟病：一般題與疾病題都可見', () {
    final Map<String, dynamic> pet = <String, dynamic>{
      'petId': 'b',
      'name': '喵喵',
      'vaccine': '心臟病',
    };
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: generalPet,
        pet: pet,
      ),
      isTrue,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: diseasePet,
        pet: pet,
      ),
      isTrue,
    );
    expect(PetSnapshot.medicalStatusText(pet), '心臟病');
    expect(
      PetSnapshot.safetyRows(pet).any(
        (MapEntry<String, String> row) =>
            row.key == '疾病／醫療' && row.value == '心臟病',
      ),
      isTrue,
    );
    expect(PetSnapshot.hasDiseaseAlert(pet), isTrue);
  });

  test('medicalStatus 優先於 vaccine', () {
    expect(
      PetSnapshot.medicalStatusText(<String, dynamic>{
        'medicalStatus': '無',
        'vaccine': '心臟病',
      }),
      '無',
    );
    expect(
      PetSnapshot.hasRecordedDisease(<String, dynamic>{
        'medicalStatus': '無',
        'vaccine': '心臟病',
      }),
      isFalse,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: diseasePet,
        pet: <String, dynamic>{
          'petId': 'x',
          'medicalStatus': '無',
          'vaccine': '心臟病',
        },
      ),
      isFalse,
    );
    expect(
      PetSnapshot.medicalStatusText(<String, dynamic>{
        'medicalStatus': '',
        'vaccine': '心臟病',
      }),
      '心臟病',
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: diseasePet,
        pet: <String, dynamic>{
          'petId': 'y',
          'medicalStatus': '',
          'vaccine': '心臟病',
        },
      ),
      isTrue,
    );
  });

  test('疾病條件只對有疾病的寵物顯示', () {
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: diseasePet,
        pet: <String, dynamic>{'petId': 'c', 'name': '舊資料'},
      ),
      isFalse,
    );
    expect(
      CustomFormDisplayCondition(
        field: 'medicalStatus',
        value: '有疾病',
      ).cardSummary,
      '疾病狀況：有疾病時顯示',
    );
  });

  test('allergy / canMedicate 舊條件仍解析，但不出現在新增條件清單', () {
    expect(
      CustomFormPetConditionField.fromStorage('allergy'),
      CustomFormPetConditionField.allergy,
    );
    expect(
      CustomFormPetConditionField.fromStorage('canMedicate'),
      CustomFormPetConditionField.canMedicate,
    );
    expect(
      CustomFormPetConditionField.selectableInEditor,
      isNot(contains(CustomFormPetConditionField.allergy)),
    );
    expect(
      CustomFormPetConditionField.selectableInEditor,
      isNot(contains(CustomFormPetConditionField.canMedicate)),
    );
    expect(
      CustomFormPetConditionField.selectableInEditor,
      containsAll(<CustomFormPetConditionField>[
        CustomFormPetConditionField.none,
        CustomFormPetConditionField.isNeutered,
        CustomFormPetConditionField.medicalStatus,
      ]),
    );
    const CustomFormQuestion allergyQuestion = CustomFormQuestion(
      id: 'q_allergy',
      label: '過敏說明',
      answerScope: CustomFormAnswerScope.pet,
      displayCondition: CustomFormDisplayCondition(
        field: 'allergy',
        value: '有',
      ),
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: allergyQuestion,
        pet: <String, dynamic>{'petId': '1', 'allergy': '海鮮'},
      ),
      isTrue,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: allergyQuestion,
        pet: <String, dynamic>{'petId': '2', 'allergy': '無'},
      ),
      isFalse,
    );
    const CustomFormQuestion medicateQuestion = CustomFormQuestion(
      id: 'q_fix',
      label: '用藥時間',
      answerScope: CustomFormAnswerScope.pet,
      displayCondition: CustomFormDisplayCondition(
        field: 'canMedicate',
        value: '是',
      ),
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: medicateQuestion,
        pet: <String, dynamic>{'petId': '3', 'canMedicate': true},
      ),
      isTrue,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: medicateQuestion,
        pet: <String, dynamic>{'petId': '4', 'canMedicate': false},
      ),
      isFalse,
    );
    expect(
      CustomFormPetConditionField.editorItemsFor(
        CustomFormPetConditionField.allergy,
      ),
      contains(CustomFormPetConditionField.allergy),
    );
  });

  test('每隻寵物答案以 petId 分開且驗證指出寵物名稱', () {
    final CustomFormModel current = form();
    final List<Map<String, dynamic>> pets = <Map<String, dynamic>>[
      <String, dynamic>{'petId': 'a', 'name': '毛毛', 'vaccine': '無'},
      <String, dynamic>{'petId': 'b', 'name': '喵喵', 'vaccine': '心臟病'},
    ];
    expect(
      BookingOrderFormAnswers.validatePet(
        form: current,
        pet: pets.first,
        answersByQuestionId: const <String, dynamic>{},
      ).isValid,
      isTrue,
    );
    final result = BookingOrderFormAnswers.validatePet(
      form: current,
      pet: pets.last,
      answersByQuestionId: const <String, dynamic>{},
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('喵喵'));
    final Map<String, dynamic> encoded = BookingOrderFormAnswers.encodeByPetId(
      form: current,
      pets: pets,
      answersByPetId: <String, Map<String, dynamic>>{
        'b': <String, dynamic>{'q_med': '早午各一顆'},
      },
    );
    expect(encoded.containsKey('a'), isFalse);
    expect(encoded['b']['petName'], '喵喵');
    expect(encoded['b']['petId'], 'b');
  });

  testWidgets('選擇寵物填寫：一次只顯示一隻，疾病寵物同時有一般與疾病題', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Map<String, Map<String, dynamic>> answers =
        <String, Map<String, dynamic>>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderCustomFormFill(
              form: fillForm(),
              orderAnswers: const <String, dynamic>{},
              petAnswersByPetId: answers,
              pets: const <Map<String, dynamic>>[
                <String, dynamic>{'petId': 'a', 'name': '毛毛', 'vaccine': '無'},
                <String, dynamic>{'petId': 'b', 'name': '喵喵', 'vaccine': '心臟病'},
              ],
              onOrderChanged: (_) {},
              onPetChanged: (String petId, Map<String, dynamic> next) {
                answers[petId] = next;
              },
              theme: HomeThemeModel.classicDefault,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('選擇寵物填寫'), findsOneWidget);
    expect(find.text('日常備註'), findsOneWidget);
    expect(find.text('藥物名稱 *'), findsOneWidget);
    expect(find.text('喵喵的照護資訊'), findsOneWidget);
    expect(find.text('毛毛的照護資訊'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('毛毛・已完成').last);
    await tester.pumpAndSettle();

    expect(find.text('毛毛的照護資訊'), findsOneWidget);
    expect(find.text('日常備註'), findsOneWidget);
    expect(find.text('藥物名稱 *'), findsNothing);
    expect(find.text('喵喵的照護資訊'), findsNothing);
  });
}
