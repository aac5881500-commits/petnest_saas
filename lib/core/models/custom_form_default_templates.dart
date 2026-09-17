// 檔案名稱：lib/core/models/custom_form_default_templates.dart
// 功能說明：送出訂單與手動訂單表單的系統建議初版範本。

import 'package:petnest_saas/core/models/custom_form_model.dart';

class CustomFormDefaultTemplates {
  const CustomFormDefaultTemplates._();

  static CustomFormModel create({
    required String shopId,
    required CustomFormType formType,
  }) {
    return CustomFormModel(
      id: formType.storageId,
      shopId: shopId,
      formType: formType,
      title: formType.defaultTitle,
      description: formType.defaultDescription,
      enabled: false,
      sections: sectionsFor(formType),
    );
  }

  static List<CustomFormSection> sectionsFor(CustomFormType formType) {
    switch (formType) {
      case CustomFormType.petProfile:
        return List<CustomFormSection>.from(_petProfileSections);
      case CustomFormType.bookingSubmit:
        return List<CustomFormSection>.from(_bookingSubmitSections);
      case CustomFormType.adminCreate:
        return List<CustomFormSection>.from(_adminCreateSections);
    }
  }

  static List<CustomFormSection> modulesFor(CustomFormType formType) {
    return sectionsFor(formType);
  }

  static bool hasModule(CustomFormModel form, String moduleId) {
    return form.sections.any(
      (CustomFormSection section) => section.id == moduleId,
    );
  }

  static CustomFormModel mergeMissingModules({
    required CustomFormModel current,
    required Iterable<String> moduleIds,
  }) {
    final Set<String> want = moduleIds.toSet();
    final List<CustomFormSection> next = List<CustomFormSection>.from(
      current.sections,
    );
    for (final CustomFormSection module in modulesFor(current.formType)) {
      if (!want.contains(module.id) || hasModule(current, module.id)) {
        continue;
      }
      next.add(module.copyWith(sortOrder: next.length));
    }
    return current.copyWith(sections: next);
  }

  static CustomFormModel replaceWithRecommended(CustomFormModel current) {
    return current.copyWith(sections: sectionsFor(current.formType));
  }

  static const List<CustomFormSection> _petProfileSections =
      <CustomFormSection>[
        CustomFormSection(
          id: 'pet_diet',
          title: '飲食與過敏',
          description: '請填寫毛孩平常的飲食習慣，方便店家安排照護。',
          sortOrder: 0,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'pet_main_food',
              label: '平常食用的主食或飼料',
              description: '請填寫品牌、口味或種類。',
              type: CustomFormQuestionType.shortText,
              required: true,
              sortOrder: 0,
              placeholder: '例如：皇家腸胃配方乾糧',
            ),
            CustomFormQuestion(
              id: 'pet_feeding_habit',
              label: '平常的餵食方式與份量',
              description: '請填寫每日次數、每次份量及餵食時間。',
              type: CustomFormQuestionType.longText,
              required: true,
              sortOrder: 1,
              placeholder: '例如：每日早晚各一次，每次40克',
            ),
            CustomFormQuestion(
              id: 'pet_has_food_allergy',
              label: '是否有食物過敏',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 2,
            ),
            CustomFormQuestion(
              id: 'pet_food_allergy_note',
              label: '食物過敏或禁止食用的內容',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 3,
              placeholder: '沒有可留空',
            ),
          ],
        ),
        CustomFormSection(
          id: 'pet_health_care',
          title: '健康與用藥',
          description: '請提供照護期間需要注意的健康資訊。',
          sortOrder: 1,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'pet_has_regular_medication',
              label: '目前是否需要固定用藥',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 0,
            ),
            CustomFormQuestion(
              id: 'pet_medication_instruction',
              label: '藥物名稱與服用方式',
              description: '如需用藥，請填寫藥名、劑量及時間。',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 1,
              placeholder: '例如：早晚各半顆，拌入主食',
            ),
            CustomFormQuestion(
              id: 'pet_recent_health_note',
              label: '近期是否有身體不適或特殊狀況',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 2,
              placeholder: '沒有可留空',
            ),
          ],
        ),
        CustomFormSection(
          id: 'pet_personality',
          title: '個性與照護提醒',
          description: '協助照護人員更快了解毛孩。',
          sortOrder: 2,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'pet_personality_traits',
              label: '毛孩的個性',
              type: CustomFormQuestionType.multipleChoice,
              required: true,
              sortOrder: 0,
              options: <CustomFormOption>[
                CustomFormOption(id: 'friendly', label: '親人', sortOrder: 0),
                CustomFormOption(id: 'slow_warm', label: '慢熟', sortOrder: 1),
                CustomFormOption(id: 'shy', label: '膽小', sortOrder: 2),
                CustomFormOption(id: 'active', label: '活潑', sortOrder: 3),
                CustomFormOption(id: 'alert', label: '較有警戒心', sortOrder: 4),
                CustomFormOption(id: 'nervous', label: '容易緊張', sortOrder: 5),
              ],
            ),
            CustomFormQuestion(
              id: 'pet_dislike_note',
              label: '不喜歡或需要避開的事情',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 1,
              placeholder: '例如：不喜歡摸肚子、害怕吹風機',
            ),
            CustomFormQuestion(
              id: 'pet_bite_risk',
              label: '緊張時是否可能抓咬或攻擊',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 2,
            ),
          ],
        ),
      ];

  static const List<CustomFormOption> _broughtItemOptions = <CustomFormOption>[
    CustomFormOption(id: 'food', label: '主食或飼料', sortOrder: 0),
    CustomFormOption(id: 'snack', label: '零食', sortOrder: 1),
    CustomFormOption(id: 'medicine', label: '藥品', sortOrder: 2),
    CustomFormOption(id: 'toy', label: '玩具', sortOrder: 3),
    CustomFormOption(id: 'bed', label: '睡墊或毯子', sortOrder: 4),
    CustomFormOption(id: 'carrier', label: '外出籠', sortOrder: 5),
    CustomFormOption(id: 'other', label: '其他', sortOrder: 6),
  ];

  static const CustomFormDisplayCondition _hasMedicalCondition =
      CustomFormDisplayCondition(field: 'medicalStatus', value: '有疾病');

  static List<CustomFormSection> _orderFormSections({
    required String idPrefix,
    required bool staffWording,
  }) {
    final String diseaseNote = staffWording
        ? '系統偵測到此寵物有疾病狀況；請依會員提供資訊補充本次照護重點，沒有可留白。'
        : '系統偵測到此寵物有疾病狀況；如本次有需特別留意、觀察或照護的事項，請填寫。';
    return <CustomFormSection>[
      CustomFormSection(
        id: '${idPrefix}_care',
        title: '本次照護與交代',
        description: staffWording
            ? '請依會員提供的本次照護需求填寫；沒有特殊情況可留白選填題。'
            : '請填寫這次住宿或安親期間的照護需求。',
        sortOrder: 0,
        questions: <CustomFormQuestion>[
          CustomFormQuestion(
            id: '${idPrefix}_feeding_changed',
            label: '本次飲食安排是否與平常不同？',
            type: CustomFormQuestionType.yesNo,
            required: true,
            sortOrder: 0,
          ),
          CustomFormQuestion(
            id: '${idPrefix}_feeding_instruction',
            label: '本次飲食說明',
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 1,
            placeholder: '沒有不同可留白',
          ),
          CustomFormQuestion(
            id: '${idPrefix}_pet_disease_care',
            label: '疾病照護補充',
            description: diseaseNote,
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 2,
            placeholder: '沒有可留白',
            answerScope: CustomFormAnswerScope.pet,
            displayCondition: _hasMedicalCondition,
          ),
          CustomFormQuestion(
            id: '${idPrefix}_pet_special_care',
            label: '此寵物本次需要特別照顧或注意事項嗎？',
            description: '例如飲食、活動、情緒、環境、接觸方式或其他本次需要注意的內容；沒有可留白。',
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 3,
            placeholder: '沒有可留白',
            answerScope: CustomFormAnswerScope.pet,
          ),
          CustomFormQuestion(
            id: '${idPrefix}_pet_diet_note',
            label: '此寵物本次飲食／餵食注意事項',
            description: '如每隻寵物的飲食安排不同，可分別填寫；沒有可留白。',
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 4,
            placeholder: '沒有可留白',
            answerScope: CustomFormAnswerScope.pet,
          ),
        ],
      ),
      CustomFormSection(
        id: '${idPrefix}_items',
        title: '攜帶物品',
        description: staffWording
            ? '請核對或代填本次攜帶物品。'
            : '方便入住與離店時核對物品。',
        sortOrder: 1,
        questions: <CustomFormQuestion>[
          CustomFormQuestion(
            id: '${idPrefix}_brought_items',
            label: '本次攜帶的物品',
            type: CustomFormQuestionType.multipleChoice,
            required: false,
            sortOrder: 0,
            options: _broughtItemOptions,
          ),
          CustomFormQuestion(
            id: '${idPrefix}_other_item',
            label: '其他攜帶物品',
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 1,
            placeholder: '沒有可留白',
          ),
        ],
      ),
      CustomFormSection(
        id: '${idPrefix}_other_request',
        title: '接送與其他需求',
        description: staffWording
            ? '請依會員說明填寫接送與其他需求。'
            : '若本次有特殊狀況，請提前告知店家。',
        sortOrder: 2,
        questions: <CustomFormQuestion>[
          CustomFormQuestion(
            id: '${idPrefix}_special_care',
            label: '本次需要特別注意或協助的事項',
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 0,
            placeholder: '沒有可留白',
          ),
          CustomFormQuestion(
            id: '${idPrefix}_different_pickup_person',
            label: '接回人是否與會員本人不同？',
            type: CustomFormQuestionType.yesNo,
            required: true,
            sortOrder: 1,
          ),
          CustomFormQuestion(
            id: '${idPrefix}_pickup_person',
            label: '其他接回人的姓名與電話',
            type: CustomFormQuestionType.longText,
            required: false,
            sortOrder: 2,
            placeholder: '接回人相同可留白',
          ),
        ],
      ),
    ];
  }

  static List<CustomFormSection> get _bookingSubmitSections =>
      _orderFormSections(idPrefix: 'booking', staffWording: false);

  static List<CustomFormSection> get _adminCreateSections =>
      _orderFormSections(idPrefix: 'admin', staffWording: true);
}
