// 檔案名稱：lib/core/models/custom_form_model.dart
// 功能說明：店家自訂表單資料模型
// 用途：送出訂單表單、手動訂單表單的結構定義與 Firestore 解析。

import 'package:cloud_firestore/cloud_firestore.dart';

enum CustomFormType {
  petProfile,
  bookingSubmit,
  adminCreate;

  String get storageId {
    switch (this) {
      case CustomFormType.petProfile:
        return 'pet_profile';
      case CustomFormType.bookingSubmit:
        return 'booking_submit';
      case CustomFormType.adminCreate:
        return 'admin_create';
    }
  }

  String get defaultTitle {
    switch (this) {
      case CustomFormType.petProfile:
        return '新增寵物表單';
      case CustomFormType.bookingSubmit:
        return '送出訂單表單';
      case CustomFormType.adminCreate:
        return '手動訂單表單';
    }
  }

  String get defaultDescription {
    switch (this) {
      case CustomFormType.petProfile:
        return '已停用：不再於新增或編輯寵物時填寫店家自訂題目。';
      case CustomFormType.bookingSubmit:
        return 'APP 會員自行送出住宿／安親預約時填寫。可設定訂單資訊（每筆一次）或寵物資訊（每隻各填一次）。答案只歸屬該筆訂單，不會寫回共用寵物檔案。';
      case CustomFormType.adminCreate:
        return '店員／店主後台手動建立住宿／安親訂單時填寫。可設定訂單資訊或寵物資訊。答案只歸屬該筆訂單，僅店家後台可見。';
    }
  }

  String get whenToUse {
    switch (this) {
      case CustomFormType.petProfile:
        return '已不再使用';
      case CustomFormType.bookingSubmit:
        return 'APP 會員從客戶端自行送出住宿／安親預約時';
      case CustomFormType.adminCreate:
        return '店家後台手動建立住宿／安親訂單時';
    }
  }

  String get whoFills {
    switch (this) {
      case CustomFormType.petProfile:
        return '會員（飼主）';
      case CustomFormType.bookingSubmit:
        return 'APP 會員（客戶端自助下單）';
      case CustomFormType.adminCreate:
        return '店員／店主（後台）';
    }
  }

  String get answerLocation {
    switch (this) {
      case CustomFormType.petProfile:
        return '不再寫入寵物檔案';
      case CustomFormType.bookingSubmit:
        return '只歸屬該筆訂單（含每隻寵物的照護答案快照）';
      case CustomFormType.adminCreate:
        return '只歸屬該筆訂單，且僅店家後台可見';
    }
  }

  static CustomFormType fromStorage(String? value) {
    final String id = (value ?? '').trim();
    if (id == CustomFormType.bookingSubmit.storageId) {
      return CustomFormType.bookingSubmit;
    }
    if (id == CustomFormType.adminCreate.storageId) {
      return CustomFormType.adminCreate;
    }
    return CustomFormType.petProfile;
  }

  static const List<CustomFormType> shopSettingTypes = <CustomFormType>[
    CustomFormType.bookingSubmit,
    CustomFormType.adminCreate,
  ];
}

enum CustomFormAnswerScope {
  order,
  pet;

  String get storageValue {
    switch (this) {
      case CustomFormAnswerScope.order:
        return 'order';
      case CustomFormAnswerScope.pet:
        return 'pet';
    }
  }

  String get shortLabel {
    switch (this) {
      case CustomFormAnswerScope.order:
        return '訂單資訊';
      case CustomFormAnswerScope.pet:
        return '寵物資訊';
    }
  }

  String get editorLabel {
    switch (this) {
      case CustomFormAnswerScope.order:
        return '訂單資訊（每筆訂單填一次）';
      case CustomFormAnswerScope.pet:
        return '寵物資訊（每隻寵物各填一次）';
    }
  }

  static CustomFormAnswerScope fromStorage(String? value) {
    final String id = (value ?? '').trim().toLowerCase();
    if (id == CustomFormAnswerScope.pet.storageValue ||
        id == 'pet_info' ||
        id == 'pets') {
      return CustomFormAnswerScope.pet;
    }
    return CustomFormAnswerScope.order;
  }
}

class CustomFormDisplayCondition {
  const CustomFormDisplayCondition({this.field = '', this.value = ''});

  final String field;
  final String value;

  bool get isEmpty => field.trim().isEmpty || value.trim().isEmpty;

  String get cardSummary {
    if (isEmpty) {
      return '';
    }
    final CustomFormPetConditionField parsed =
        CustomFormPetConditionField.fromStorage(field);
    if (parsed == CustomFormPetConditionField.none) {
      return '';
    }
    return '${parsed.label}：${value.trim()}時顯示';
  }

  factory CustomFormDisplayCondition.fromMap(dynamic raw) {
    if (raw is! Map) {
      return const CustomFormDisplayCondition();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return CustomFormDisplayCondition(
      field: (map['field'] ?? '').toString().trim(),
      value: (map['value'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'field': field, 'value': value};
  }

  CustomFormDisplayCondition copyWith({String? field, String? value}) {
    return CustomFormDisplayCondition(
      field: field ?? this.field,
      value: value ?? this.value,
    );
  }
}

enum CustomFormPetConditionField {
  none,
  isNeutered,
  medicalStatus,
  allergy,
  canMedicate;

  String get storageValue {
    switch (this) {
      case CustomFormPetConditionField.none:
        return '';
      case CustomFormPetConditionField.isNeutered:
        return 'isNeutered';
      case CustomFormPetConditionField.medicalStatus:
        return 'medicalStatus';
      case CustomFormPetConditionField.allergy:
        return 'allergy';
      case CustomFormPetConditionField.canMedicate:
        return 'canMedicate';
    }
  }

  String get label {
    switch (this) {
      case CustomFormPetConditionField.none:
        return '不設定條件';
      case CustomFormPetConditionField.isNeutered:
        return '結紮狀況';
      case CustomFormPetConditionField.medicalStatus:
        return '疾病狀況';
      case CustomFormPetConditionField.allergy:
        return '飲食／食物過敏狀況';
      case CustomFormPetConditionField.canMedicate:
        return '是否需要固定用藥';
    }
  }

  List<String> get valueOptions {
    switch (this) {
      case CustomFormPetConditionField.none:
        return const <String>[];
      case CustomFormPetConditionField.isNeutered:
        return const <String>['有結紮', '未結紮'];
      case CustomFormPetConditionField.medicalStatus:
        return const <String>[
          '無',
          '有疾病',
          '慢性腎臟病',
          '心臟病',
          '糖尿病',
          '術後照護',
          '皮膚疾病',
          '其他',
        ];
      case CustomFormPetConditionField.allergy:
        return const <String>['有', '無'];
      case CustomFormPetConditionField.canMedicate:
        return const <String>['是', '否'];
    }
  }

  static CustomFormPetConditionField fromStorage(String? value) {
    final String id = (value ?? '').trim();
    for (final CustomFormPetConditionField field
        in CustomFormPetConditionField.values) {
      if (field != CustomFormPetConditionField.none &&
          field.storageValue == id) {
        return field;
      }
    }
    return CustomFormPetConditionField.none;
  }

  /// 新增條件時可選；allergy / canMedicate 僅保留舊題目解析。
  static const List<CustomFormPetConditionField> selectableInEditor =
      <CustomFormPetConditionField>[
        CustomFormPetConditionField.none,
        CustomFormPetConditionField.isNeutered,
        CustomFormPetConditionField.medicalStatus,
      ];

  static List<CustomFormPetConditionField> editorItemsFor(
    CustomFormPetConditionField current,
  ) {
    final List<CustomFormPetConditionField> items =
        List<CustomFormPetConditionField>.from(selectableInEditor);
    if (!items.contains(current)) {
      items.add(current);
    }
    return items;
  }
}

enum CustomFormQuestionType {
  shortText,
  longText,
  singleChoice,
  multipleChoice,
  yesNo,
  dropdown,
  yearMonth,
  date,
  number;

  String get storageValue {
    switch (this) {
      case CustomFormQuestionType.shortText:
        return 'shortText';
      case CustomFormQuestionType.longText:
        return 'longText';
      case CustomFormQuestionType.singleChoice:
        return 'singleChoice';
      case CustomFormQuestionType.multipleChoice:
        return 'multipleChoice';
      case CustomFormQuestionType.yesNo:
        return 'yesNo';
      case CustomFormQuestionType.dropdown:
        return 'dropdown';
      case CustomFormQuestionType.yearMonth:
        return 'yearMonth';
      case CustomFormQuestionType.date:
        return 'date';
      case CustomFormQuestionType.number:
        return 'number';
    }
  }

  String get label {
    switch (this) {
      case CustomFormQuestionType.shortText:
        return '單行文字';
      case CustomFormQuestionType.longText:
        return '多行文字';
      case CustomFormQuestionType.singleChoice:
        return '單選';
      case CustomFormQuestionType.multipleChoice:
        return '複選';
      case CustomFormQuestionType.yesNo:
        return '是／否';
      case CustomFormQuestionType.dropdown:
        return '下拉選單';
      case CustomFormQuestionType.yearMonth:
        return '年份＋月份';
      case CustomFormQuestionType.date:
        return '日期';
      case CustomFormQuestionType.number:
        return '數字';
    }
  }

  String get hint {
    switch (this) {
      case CustomFormQuestionType.singleChoice:
        return '只能選一個';
      case CustomFormQuestionType.multipleChoice:
        return '可選多個';
      case CustomFormQuestionType.yesNo:
        return '簡單判斷';
      case CustomFormQuestionType.shortText:
        return '輸入內容';
      case CustomFormQuestionType.longText:
        return '輸入內容';
      case CustomFormQuestionType.date:
      case CustomFormQuestionType.yearMonth:
      case CustomFormQuestionType.number:
        return '固定格式';
      case CustomFormQuestionType.dropdown:
        return '只能選一個';
    }
  }

  String get labelWithHint => '$label（$hint）';

  bool get hasOptions {
    return this == CustomFormQuestionType.singleChoice ||
        this == CustomFormQuestionType.multipleChoice ||
        this == CustomFormQuestionType.dropdown;
  }

  static CustomFormQuestionType fromStorage(String? value) {
    final String normalized = (value ?? '').trim();
    for (final CustomFormQuestionType type in CustomFormQuestionType.values) {
      if (type.storageValue == normalized) {
        return type;
      }
    }
    return CustomFormQuestionType.shortText;
  }
}

class CustomFormOption {
  const CustomFormOption({
    required this.id,
    required this.label,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final int sortOrder;

  factory CustomFormOption.fromMap(Map<String, dynamic> map) {
    return CustomFormOption(
      id: (map['id'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString(),
      sortOrder: CustomFormModel.parseInt(map['sortOrder']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'id': id, 'label': label, 'sortOrder': sortOrder};
  }

  CustomFormOption copyWith({String? id, String? label, int? sortOrder}) {
    return CustomFormOption(
      id: id ?? this.id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class CustomFormQuestion {
  const CustomFormQuestion({
    required this.id,
    required this.label,
    this.description = '',
    this.type = CustomFormQuestionType.shortText,
    this.required = false,
    this.enabled = true,
    this.sortOrder = 0,
    this.options = const <CustomFormOption>[],
    this.placeholder = '',
    this.answerScope = CustomFormAnswerScope.order,
    this.displayCondition = const CustomFormDisplayCondition(),
  });

  final String id;
  final String label;
  final String description;
  final CustomFormQuestionType type;
  final bool required;
  final bool enabled;
  final int sortOrder;
  final List<CustomFormOption> options;
  final String placeholder;
  final CustomFormAnswerScope answerScope;
  final CustomFormDisplayCondition displayCondition;

  bool get collectsRequired => required;

  String get scopeCardLabel => answerScope.shortLabel;

  String get conditionCardLabel => displayCondition.cardSummary;

  factory CustomFormQuestion.fromMap(Map<String, dynamic> map) {
    final List<CustomFormOption> options = CustomFormModel.parseMapList(
      map['options'],
    ).map(CustomFormOption.fromMap).toList();
    options.sort(
      (CustomFormOption a, CustomFormOption b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );
    final CustomFormAnswerScope scope = CustomFormAnswerScope.fromStorage(
      map['answerScope']?.toString(),
    );
    final bool storedRequired = CustomFormModel.parseBool(map['required']);
    final bool petRequired = map.containsKey('petRequired')
        ? CustomFormModel.parseBool(map['petRequired'])
        : storedRequired;
    return CustomFormQuestion(
      id: (map['id'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      type: CustomFormQuestionType.fromStorage(map['type']?.toString()),
      required: scope == CustomFormAnswerScope.pet
          ? petRequired
          : storedRequired,
      enabled: CustomFormModel.parseBool(map['enabled'], fallback: true),
      sortOrder: CustomFormModel.parseInt(map['sortOrder']),
      options: options,
      placeholder: (map['placeholder'] ?? '').toString(),
      answerScope: scope,
      displayCondition: CustomFormDisplayCondition.fromMap(
        map['displayCondition'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final bool cfRequired =
        answerScope == CustomFormAnswerScope.order && required;
    return <String, dynamic>{
      'id': id,
      'label': label,
      'description': description,
      'type': type.storageValue,
      'required': cfRequired,
      'petRequired': answerScope == CustomFormAnswerScope.pet && required,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'options': options.map((CustomFormOption item) => item.toMap()).toList(),
      'placeholder': placeholder,
      'answerScope': answerScope.storageValue,
      'displayCondition': displayCondition.isEmpty
          ? <String, dynamic>{}
          : displayCondition.toMap(),
    };
  }

  CustomFormQuestion copyWith({
    String? id,
    String? label,
    String? description,
    CustomFormQuestionType? type,
    bool? required,
    bool? enabled,
    int? sortOrder,
    List<CustomFormOption>? options,
    String? placeholder,
    CustomFormAnswerScope? answerScope,
    CustomFormDisplayCondition? displayCondition,
  }) {
    return CustomFormQuestion(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      type: type ?? this.type,
      required: required ?? this.required,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      options: options ?? this.options,
      placeholder: placeholder ?? this.placeholder,
      answerScope: answerScope ?? this.answerScope,
      displayCondition: displayCondition ?? this.displayCondition,
    );
  }
}

class CustomFormSection {
  const CustomFormSection({
    required this.id,
    required this.title,
    this.description = '',
    this.sortOrder = 0,
    this.enabled = true,
    this.questions = const <CustomFormQuestion>[],
  });

  final String id;
  final String title;
  final String description;
  final int sortOrder;
  final bool enabled;
  final List<CustomFormQuestion> questions;

  factory CustomFormSection.fromMap(Map<String, dynamic> map) {
    final List<CustomFormQuestion> questions = CustomFormModel.parseMapList(
      map['questions'],
    ).map(CustomFormQuestion.fromMap).toList();
    questions.sort(
      (CustomFormQuestion a, CustomFormQuestion b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );

    return CustomFormSection(
      id: (map['id'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      sortOrder: CustomFormModel.parseInt(map['sortOrder']),
      enabled: CustomFormModel.parseBool(map['enabled'], fallback: true),
      questions: questions,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'sortOrder': sortOrder,
      'enabled': enabled,
      'questions': questions
          .map((CustomFormQuestion item) => item.toMap())
          .toList(),
    };
  }

  int get questionCount => questions.length;

  int get requiredCount => questions
      .where((CustomFormQuestion item) => item.collectsRequired)
      .length;

  CustomFormSection copyWith({
    String? id,
    String? title,
    String? description,
    int? sortOrder,
    bool? enabled,
    List<CustomFormQuestion>? questions,
  }) {
    return CustomFormSection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      enabled: enabled ?? this.enabled,
      questions: questions ?? this.questions,
    );
  }
}

class CustomFormModel {
  const CustomFormModel({
    required this.id,
    required this.shopId,
    required this.formType,
    required this.title,
    this.description = '',
    this.enabled = false,
    this.version = 0,
    this.sections = const <CustomFormSection>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final CustomFormType formType;
  final String title;
  final String description;
  final bool enabled;
  final int version;
  final List<CustomFormSection> sections;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CustomFormModel.empty({
    required String shopId,
    required CustomFormType formType,
  }) {
    return CustomFormModel(
      id: formType.storageId,
      shopId: shopId,
      formType: formType,
      title: formType.defaultTitle,
      description: formType.defaultDescription,
    );
  }

  factory CustomFormModel.fromMap({
    required String shopId,
    required CustomFormType formType,
    required String id,
    Map<String, dynamic>? data,
  }) {
    if (data == null) {
      return CustomFormModel.empty(shopId: shopId, formType: formType);
    }

    final List<CustomFormSection> sections = parseMapList(data['sections'])
        .map(CustomFormSection.fromMap)
        .where((CustomFormSection section) => section.id.isNotEmpty)
        .toList();
    sections.sort(
      (CustomFormSection a, CustomFormSection b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );

    return CustomFormModel(
      id: (data['id'] ?? id).toString().trim().isEmpty
          ? formType.storageId
          : (data['id'] ?? id).toString().trim(),
      shopId: (data['shopId'] ?? shopId).toString().trim(),
      formType: CustomFormType.fromStorage(
        (data['formType'] ?? formType.storageId).toString(),
      ),
      title: (data['title'] ?? formType.defaultTitle).toString(),
      description: (data['description'] ?? formType.defaultDescription)
          .toString(),
      enabled: parseBool(data['enabled']),
      version: parseInt(data['version']),
      sections: sections,
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({required int version}) {
    return <String, dynamic>{
      'id': id,
      'shopId': shopId,
      'formType': formType.storageId,
      'title': title.trim(),
      'description': description.trim(),
      'enabled': enabled,
      'version': version,
      'sections': sections
          .map((CustomFormSection section) => section.toMap())
          .toList(),
    };
  }

  Map<String, dynamic> contentSnapshot() {
    return toFirestoreMap(version: 0);
  }

  /// 前台只收集已啟用分類中的已啟用題目。
  List<(CustomFormSection, CustomFormQuestion)> get enabledQuestionEntries {
    return enabledQuestionEntriesWhere((CustomFormQuestion _) => true);
  }

  List<(CustomFormSection, CustomFormQuestion)> enabledQuestionEntriesWhere(
    bool Function(CustomFormQuestion question) test,
  ) {
    final List<(CustomFormSection, CustomFormQuestion)> result =
        <(CustomFormSection, CustomFormQuestion)>[];
    for (final CustomFormSection section in sections) {
      if (!section.enabled) {
        continue;
      }
      for (final CustomFormQuestion question in section.questions) {
        if (!question.enabled ||
            question.id.trim().isEmpty ||
            !test(question)) {
          continue;
        }
        result.add((section, question));
      }
    }
    return result;
  }

  CustomFormModel whereQuestions(
    bool Function(CustomFormQuestion question) test,
  ) {
    return copyWith(
      sections: sections
          .map(
            (CustomFormSection section) => section.copyWith(
              questions: section.questions.where(test).toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  bool get hasEnabledQuestions => enabledQuestionEntries.isNotEmpty;

  int get sectionCount => sections.length;

  int get questionCount => sections.fold<int>(
    0,
    (int sum, CustomFormSection section) => sum + section.questionCount,
  );

  int get orderQuestionCount => sections.fold<int>(
    0,
    (int sum, CustomFormSection section) =>
        sum +
        section.questions
            .where(
              (CustomFormQuestion question) =>
                  question.answerScope == CustomFormAnswerScope.order,
            )
            .length,
  );

  int get petQuestionCount => sections.fold<int>(
    0,
    (int sum, CustomFormSection section) =>
        sum +
        section.questions
            .where(
              (CustomFormQuestion question) =>
                  question.answerScope == CustomFormAnswerScope.pet,
            )
            .length,
  );

  int get requiredQuestionCount => sections.fold<int>(
    0,
    (int sum, CustomFormSection section) => sum + section.requiredCount,
  );

  bool get hasCustomQuestions => questionCount > 0;

  /// 表單已開啟且至少有一題可填時，前台才顯示。
  bool get shouldCollectAnswers => enabled && hasEnabledQuestions;

  CustomFormModel copyWith({
    String? id,
    String? shopId,
    CustomFormType? formType,
    String? title,
    String? description,
    bool? enabled,
    int? version,
    List<CustomFormSection>? sections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomFormModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      formType: formType ?? this.formType,
      title: title ?? this.title,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      version: version ?? this.version,
      sections: sections ?? this.sections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _idCounter = 0;

  static String createStableId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  static bool parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized.isEmpty) {
        return false;
      }
    }
    return fallback;
  }

  static int parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static List<Map<String, dynamic>> parseMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final dynamic item in value) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result;
  }
}
