// 檔案名稱：lib/core/models/custom_form_model.dart
// 功能說明：店家自訂表單資料模型
// 用途：新增寵物表單、送出訂單表單的結構定義與 Firestore 解析。

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
        return '會員新增或編輯寵物時填寫。答案歸屬於該隻寵物，作為店家照護資料。';
      case CustomFormType.bookingSubmit:
        return '只有 APP 會員從客戶端自己送出住宿／安親預約時填寫。答案只歸屬該筆訂單。';
      case CustomFormType.adminCreate:
        return '只有店家後台手動建立住宿／安親訂單時填寫。幫 APP 會員或非會員建立皆使用此表單。僅店家內部使用，客戶端永遠看不到。';
    }
  }

  String get whenToUse {
    switch (this) {
      case CustomFormType.petProfile:
        return '會員新增或編輯寵物資料時';
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
        return '歸屬於該隻寵物，作為店家照護資料';
      case CustomFormType.bookingSubmit:
        return '只歸屬該筆訂單';
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

  factory CustomFormQuestion.fromMap(Map<String, dynamic> map) {
    final List<CustomFormOption> options = CustomFormModel.parseMapList(
      map['options'],
    ).map(CustomFormOption.fromMap).toList();
    options.sort(
      (CustomFormOption a, CustomFormOption b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );

    return CustomFormQuestion(
      id: (map['id'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      type: CustomFormQuestionType.fromStorage(map['type']?.toString()),
      required: CustomFormModel.parseBool(map['required']),
      enabled: CustomFormModel.parseBool(map['enabled'], fallback: true),
      sortOrder: CustomFormModel.parseInt(map['sortOrder']),
      options: options,
      placeholder: (map['placeholder'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'description': description,
      'type': type.storageValue,
      'required': required,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'options': options.map((CustomFormOption item) => item.toMap()).toList(),
      'placeholder': placeholder,
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

  int get requiredCount =>
      questions.where((CustomFormQuestion item) => item.required).length;

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
    final List<(CustomFormSection, CustomFormQuestion)> result =
        <(CustomFormSection, CustomFormQuestion)>[];
    for (final CustomFormSection section in sections) {
      if (!section.enabled) {
        continue;
      }
      for (final CustomFormQuestion question in section.questions) {
        if (!question.enabled || question.id.trim().isEmpty) {
          continue;
        }
        result.add((section, question));
      }
    }
    return result;
  }

  bool get hasEnabledQuestions => enabledQuestionEntries.isNotEmpty;

  int get sectionCount => sections.length;

  int get questionCount => sections.fold<int>(
    0,
    (int sum, CustomFormSection section) => sum + section.questionCount,
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
