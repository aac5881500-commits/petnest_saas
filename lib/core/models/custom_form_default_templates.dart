// 檔案名稱：lib/core/models/custom_form_default_templates.dart
// 功能說明：新增寵物與送出訂單表單的系統預設範本。

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

  static const List<CustomFormSection> _bookingSubmitSections =
      <CustomFormSection>[
        CustomFormSection(
          id: 'booking_care',
          title: '本次照護交代',
          description: '請填寫這次住宿或安親期間的照護需求。',
          sortOrder: 0,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'booking_feeding_changed',
              label: '本次餵食安排是否與平常不同',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 0,
            ),
            CustomFormQuestion(
              id: 'booking_feeding_instruction',
              label: '本次餵食說明',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 1,
              placeholder: '沒有不同可留空',
            ),
            CustomFormQuestion(
              id: 'booking_need_medication',
              label: '本次是否需要協助餵藥',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 2,
            ),
            CustomFormQuestion(
              id: 'booking_medication_instruction',
              label: '本次用藥方式',
              description: '請填寫藥名、劑量及餵藥時間。',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 3,
              placeholder: '不需要餵藥可留空',
            ),
          ],
        ),
        CustomFormSection(
          id: 'booking_items',
          title: '攜帶物品',
          description: '方便入住與離店時核對物品。',
          sortOrder: 1,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'booking_brought_items',
              label: '本次攜帶的物品',
              type: CustomFormQuestionType.multipleChoice,
              required: false,
              sortOrder: 0,
              options: <CustomFormOption>[
                CustomFormOption(id: 'food', label: '主食或飼料', sortOrder: 0),
                CustomFormOption(id: 'snack', label: '零食', sortOrder: 1),
                CustomFormOption(id: 'medicine', label: '藥品', sortOrder: 2),
                CustomFormOption(id: 'toy', label: '玩具', sortOrder: 3),
                CustomFormOption(id: 'bed', label: '睡墊或毯子', sortOrder: 4),
                CustomFormOption(id: 'carrier', label: '外出籠', sortOrder: 5),
                CustomFormOption(id: 'other', label: '其他', sortOrder: 6),
              ],
            ),
            CustomFormQuestion(
              id: 'booking_other_item',
              label: '其他攜帶物品',
              type: CustomFormQuestionType.shortText,
              required: false,
              sortOrder: 1,
              placeholder: '沒有可留空',
            ),
          ],
        ),
        CustomFormSection(
          id: 'booking_other_request',
          title: '接送與其他需求',
          description: '若本次有特殊狀況，請提前告知店家。',
          sortOrder: 2,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'booking_special_care',
              label: '本次需要特別注意或協助的事項',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 0,
              placeholder: '沒有可留空',
            ),
            CustomFormQuestion(
              id: 'booking_different_pickup_person',
              label: '接回人是否與會員本人不同',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 1,
            ),
            CustomFormQuestion(
              id: 'booking_pickup_person',
              label: '其他接回人的姓名與電話',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 2,
              placeholder: '接回人相同可留空',
            ),
          ],
        ),
      ];

  static const List<CustomFormSection> _adminCreateSections =
      <CustomFormSection>[
        CustomFormSection(
          id: 'admin_handover_check',
          title: '現場交接確認',
          description: '店員現場核對飼主與寵物資料。',
          sortOrder: 0,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'admin_owner_pet_verified',
              label: '是否已核對飼主與寵物資料',
              type: CustomFormQuestionType.yesNo,
              required: true,
              sortOrder: 0,
            ),
            CustomFormQuestion(
              id: 'admin_onsite_note',
              label: '現場特殊交代事項',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 1,
              placeholder: '沒有可留空',
            ),
          ],
        ),
        CustomFormSection(
          id: 'admin_items',
          title: '攜帶物品清點',
          description: '現場核對本次攜帶物品。',
          sortOrder: 1,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'admin_brought_items',
              label: '攜帶物品',
              type: CustomFormQuestionType.multipleChoice,
              required: false,
              sortOrder: 0,
              options: <CustomFormOption>[
                CustomFormOption(id: 'food', label: '主食或飼料', sortOrder: 0),
                CustomFormOption(id: 'snack', label: '零食', sortOrder: 1),
                CustomFormOption(id: 'medicine', label: '藥品', sortOrder: 2),
                CustomFormOption(id: 'toy', label: '玩具', sortOrder: 3),
                CustomFormOption(id: 'bed', label: '睡墊或毯子', sortOrder: 4),
                CustomFormOption(id: 'carrier', label: '外出籠', sortOrder: 5),
                CustomFormOption(id: 'other', label: '其他', sortOrder: 6),
              ],
            ),
            CustomFormQuestion(
              id: 'admin_other_item',
              label: '其他物品／數量',
              type: CustomFormQuestionType.shortText,
              required: false,
              sortOrder: 1,
              placeholder: '沒有可留空',
            ),
          ],
        ),
        CustomFormSection(
          id: 'admin_staff_note',
          title: '店員內部備註',
          description: '僅店家內部使用，客戶端看不到。',
          sortOrder: 2,
          questions: <CustomFormQuestion>[
            CustomFormQuestion(
              id: 'admin_next_shift_note',
              label: '本次需提醒下一班的事項',
              type: CustomFormQuestionType.longText,
              required: false,
              sortOrder: 0,
              placeholder: '沒有可留空',
            ),
          ],
        ),
      ];
}
