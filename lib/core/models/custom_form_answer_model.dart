// 檔案名稱：lib/core/models/custom_form_answer_model.dart
// 功能說明：店家自訂表單答案快照。保存當下題目／分類文字與原始答案型別，供寵物與訂單詳細頁顯示，並提供必填驗證。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';

class CustomFormAnswerItem {
  const CustomFormAnswerItem({
    required this.sectionId,
    required this.sectionTitle,
    required this.questionId,
    required this.questionLabel,
    required this.questionType,
    required this.required,
    required this.value,
    required this.displayValue,
  });

  final String sectionId;
  final String sectionTitle;
  final String questionId;
  final String questionLabel;
  final CustomFormQuestionType questionType;
  final bool required;
  final dynamic value;
  final String displayValue;

  factory CustomFormAnswerItem.fromMap(Map<String, dynamic> map) {
    return CustomFormAnswerItem(
      sectionId: (map['sectionId'] ?? '').toString(),
      sectionTitle: (map['sectionTitle'] ?? '').toString(),
      questionId: (map['questionId'] ?? '').toString(),
      questionLabel: (map['questionLabel'] ?? '').toString(),
      questionType: CustomFormQuestionType.fromStorage(
        map['questionType']?.toString(),
      ),
      required: CustomFormModel.parseBool(map['required']),
      value: decodeStoredValue(
        type: CustomFormQuestionType.fromStorage(
          map['questionType']?.toString(),
        ),
        raw: map['value'],
      ),
      displayValue: (map['displayValue'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sectionId': sectionId,
      'sectionTitle': sectionTitle,
      'questionId': questionId,
      'questionLabel': questionLabel,
      'questionType': questionType.storageValue,
      'required': required,
      'value': encodeStoredValue(value),
      'displayValue': displayValue,
    };
  }

  static dynamic decodeStoredValue({
    required CustomFormQuestionType type,
    required dynamic raw,
  }) {
    switch (type) {
      case CustomFormQuestionType.multipleChoice:
        if (raw is List) {
          return raw.map((dynamic item) => item.toString()).toList();
        }
        if (raw is String && raw.trim().isNotEmpty) {
          return raw
              .split(',')
              .map((String item) => item.trim())
              .where((String item) => item.isNotEmpty)
              .toList();
        }
        return <String>[];
      case CustomFormQuestionType.yesNo:
        if (raw is bool) {
          return raw;
        }
        if (raw == null) {
          return null;
        }
        return CustomFormModel.parseBool(raw);
      case CustomFormQuestionType.number:
        if (raw is num) {
          return raw;
        }
        if (raw is String && raw.trim().isNotEmpty) {
          return num.tryParse(raw.trim());
        }
        return null;
      case CustomFormQuestionType.shortText:
      case CustomFormQuestionType.longText:
      case CustomFormQuestionType.singleChoice:
      case CustomFormQuestionType.dropdown:
      case CustomFormQuestionType.yearMonth:
      case CustomFormQuestionType.date:
        return raw == null ? '' : raw.toString();
    }
  }

  static dynamic encodeStoredValue(dynamic value) {
    if (value is List) {
      return value.map((dynamic item) => item.toString()).toList();
    }
    if (value is bool || value is num || value is String) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}

class CustomFormValidationResult {
  const CustomFormValidationResult({
    required this.isValid,
    this.firstInvalidQuestionId = '',
    this.message = '',
  });

  final bool isValid;
  final String firstInvalidQuestionId;
  final String message;

  static const CustomFormValidationResult ok = CustomFormValidationResult(
    isValid: true,
  );
}

class CustomFormAnswerSnapshot {
  const CustomFormAnswerSnapshot({
    required this.formId,
    required this.formType,
    required this.formVersion,
    required this.formTitle,
    required this.answers,
    this.submittedAt,
  });

  final String formId;
  final String formType;
  final int formVersion;
  final String formTitle;
  final DateTime? submittedAt;
  final List<CustomFormAnswerItem> answers;

  bool get isEmpty => answers.isEmpty;

  int get filledCount => answers
      .where((CustomFormAnswerItem item) => item.displayValue.trim().isNotEmpty)
      .length;

  CustomFormModel toEditableForm({required String shopId}) {
    final Map<String, List<CustomFormQuestion>> grouped =
        <String, List<CustomFormQuestion>>{};
    final Map<String, String> titles = <String, String>{};
    for (final CustomFormAnswerItem item in answers) {
      final String sectionId = item.sectionId.trim().isEmpty
          ? 'section'
          : item.sectionId;
      titles[sectionId] = item.sectionTitle;
      grouped
          .putIfAbsent(sectionId, () => <CustomFormQuestion>[])
          .add(
            CustomFormQuestion(
              id: item.questionId,
              label: item.questionLabel,
              type: item.questionType,
              required: item.required,
            ),
          );
    }
    int order = 0;
    final List<CustomFormSection> sections = grouped.entries.map((
      MapEntry<String, List<CustomFormQuestion>> entry,
    ) {
      final CustomFormSection section = CustomFormSection(
        id: entry.key,
        title: titles[entry.key] ?? formTitle,
        sortOrder: order,
        questions: entry.value,
      );
      order += 1;
      return section;
    }).toList();
    return CustomFormModel(
      id: formId.isEmpty
          ? CustomFormType.fromStorage(formType).storageId
          : formId,
      shopId: shopId,
      formType: CustomFormType.fromStorage(formType),
      title: formTitle,
      enabled: true,
      version: formVersion,
      sections: sections,
    );
  }

  factory CustomFormAnswerSnapshot.build({
    required CustomFormModel form,
    required Map<String, dynamic> answersByQuestionId,
    DateTime? submittedAt,
  }) {
    final List<CustomFormAnswerItem> items = <CustomFormAnswerItem>[];
    for (final (CustomFormSection section, CustomFormQuestion question)
        in form.enabledQuestionEntries) {
      final dynamic raw = answersByQuestionId[question.id];
      items.add(
        CustomFormAnswerItem(
          sectionId: section.id,
          sectionTitle: section.title,
          questionId: question.id,
          questionLabel: question.label,
          questionType: question.type,
          required: question.required,
          value: CustomFormAnswerItem.decodeStoredValue(
            type: question.type,
            raw: raw,
          ),
          displayValue: displayValueFor(question: question, raw: raw),
        ),
      );
    }
    return CustomFormAnswerSnapshot(
      formId: form.id.isEmpty ? form.formType.storageId : form.id,
      formType: form.formType.storageId,
      formVersion: form.version,
      formTitle: form.title,
      submittedAt: submittedAt,
      answers: items,
    );
  }

  /// 舊訂單可能把答案存在 bookingFormAnswers／formAnswers，或結構不完整。
  static CustomFormAnswerSnapshot? tryParse(dynamic raw) {
    try {
      if (raw == null) {
        return null;
      }
      if (raw is List) {
        final List<CustomFormAnswerItem> items = <CustomFormAnswerItem>[];
        for (final dynamic item in raw) {
          if (item is Map) {
            items.add(
              CustomFormAnswerItem.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
        if (items.isEmpty) {
          return null;
        }
        return CustomFormAnswerSnapshot(
          formId: '',
          formType: '',
          formVersion: 0,
          formTitle: '',
          answers: items,
        );
      }
      if (raw is! Map) {
        return null;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
      final List<CustomFormAnswerItem> items = <CustomFormAnswerItem>[];
      final dynamic answersRaw =
          map['answers'] ?? map['items'] ?? map['fields'];
      if (answersRaw is List) {
        for (final dynamic item in answersRaw) {
          if (item is Map) {
            items.add(
              CustomFormAnswerItem.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
      } else if (answersRaw is Map) {
        answersRaw.forEach((dynamic key, dynamic value) {
          items.add(
            CustomFormAnswerItem(
              sectionId: '',
              sectionTitle: '',
              questionId: key.toString(),
              questionLabel: key.toString(),
              questionType: CustomFormQuestionType.shortText,
              required: false,
              value: value,
              displayValue: value == null ? '' : value.toString(),
            ),
          );
        });
      }
      if (items.isEmpty && map.isEmpty) {
        return null;
      }
      if (items.isEmpty) {
        return null;
      }
      return CustomFormAnswerSnapshot(
        formId: (map['formId'] ?? '').toString(),
        formType: (map['formType'] ?? '').toString(),
        formVersion: CustomFormModel.parseInt(map['formVersion']),
        formTitle: (map['formTitle'] ?? '').toString(),
        submittedAt: CustomFormModel.parseDateTime(map['submittedAt']),
        answers: items,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toValueMap() {
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final CustomFormAnswerItem item in answers) {
      result[item.questionId] = item.value;
    }
    return result;
  }

  Map<String, dynamic> toFirestoreMap({bool useServerTimestamp = true}) {
    return <String, dynamic>{
      'formId': formId,
      'formType': formType,
      'formVersion': formVersion,
      'formTitle': formTitle,
      'submittedAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : (submittedAt == null ? null : Timestamp.fromDate(submittedAt!)),
      'answers': answers
          .map((CustomFormAnswerItem item) => item.toMap())
          .toList(),
    };
  }

  /// Cloud Function payload 不可含 Timestamp／FieldValue。
  Map<String, dynamic> toCallableMap() {
    return <String, dynamic>{
      'formId': formId,
      'formType': formType,
      'formVersion': formVersion,
      'formTitle': formTitle,
      'submittedAt': (submittedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'answers': answers
          .map((CustomFormAnswerItem item) => item.toMap())
          .toList(),
    };
  }

  static CustomFormValidationResult validate({
    required CustomFormModel form,
    required Map<String, dynamic> answersByQuestionId,
  }) {
    if (!form.shouldCollectAnswers) {
      return CustomFormValidationResult.ok;
    }
    for (final (CustomFormSection _, CustomFormQuestion question)
        in form.enabledQuestionEntries) {
      if (!question.collectsRequired) {
        continue;
      }
      final String? error = requiredError(
        question: question,
        raw: answersByQuestionId[question.id],
      );
      if (error != null) {
        return CustomFormValidationResult(
          isValid: false,
          firstInvalidQuestionId: question.id,
          message: error,
        );
      }
    }
    return CustomFormValidationResult.ok;
  }

  static String? requiredError({
    required CustomFormQuestion question,
    required dynamic raw,
  }) {
    if (!question.collectsRequired) {
      return numberError(question: question, raw: raw);
    }
    switch (question.type) {
      case CustomFormQuestionType.multipleChoice:
        final List<String> selected =
            CustomFormAnswerItem.decodeStoredValue(
                  type: question.type,
                  raw: raw,
                )
                as List<String>;
        if (selected.isEmpty) {
          return '請至少選擇一個選項';
        }
        break;
      case CustomFormQuestionType.yesNo:
        if (raw == null) {
          return '請選擇是或否';
        }
        break;
      case CustomFormQuestionType.number:
        final String? numberIssue = numberError(question: question, raw: raw);
        if (numberIssue != null) {
          return numberIssue;
        }
        if (raw == null || (raw is String && raw.trim().isEmpty)) {
          return '請填寫此必填題目';
        }
        break;
      case CustomFormQuestionType.shortText:
      case CustomFormQuestionType.longText:
      case CustomFormQuestionType.singleChoice:
      case CustomFormQuestionType.dropdown:
      case CustomFormQuestionType.yearMonth:
      case CustomFormQuestionType.date:
        final String text = (raw ?? '').toString().trim();
        if (text.isEmpty) {
          return '請填寫此必填題目';
        }
        break;
    }
    return numberError(question: question, raw: raw);
  }

  static String? numberError({
    required CustomFormQuestion question,
    required dynamic raw,
  }) {
    if (question.type != CustomFormQuestionType.number) {
      return null;
    }
    if (raw == null) {
      return question.collectsRequired ? '請填寫此必填題目' : null;
    }
    if (raw is num) {
      return null;
    }
    final String text = raw.toString().trim();
    if (text.isEmpty) {
      return question.collectsRequired ? '請填寫此必填題目' : null;
    }
    if (num.tryParse(text) == null) {
      return '請輸入合法數字';
    }
    return null;
  }

  static String displayValueFor({
    required CustomFormQuestion question,
    required dynamic raw,
  }) {
    switch (question.type) {
      case CustomFormQuestionType.multipleChoice:
        final List<String> ids =
            CustomFormAnswerItem.decodeStoredValue(
                  type: question.type,
                  raw: raw,
                )
                as List<String>;
        if (ids.isEmpty) {
          return '';
        }
        final Map<String, String> labels = <String, String>{
          for (final CustomFormOption option in question.options)
            option.id: option.label,
        };
        return ids.map((String id) => labels[id] ?? id).join('、');
      case CustomFormQuestionType.yesNo:
        if (raw == null) {
          return '';
        }
        final bool flag = raw is bool ? raw : CustomFormModel.parseBool(raw);
        return flag ? '是' : '否';
      case CustomFormQuestionType.singleChoice:
      case CustomFormQuestionType.dropdown:
        final String id = (raw ?? '').toString();
        if (id.isEmpty) {
          return '';
        }
        for (final CustomFormOption option in question.options) {
          if (option.id == id) {
            return option.label;
          }
        }
        return id;
      case CustomFormQuestionType.yearMonth:
        final String text = (raw ?? '').toString().trim();
        final RegExpMatch? match = RegExp(
          r'^(\d{4})-(\d{2})$',
        ).firstMatch(text);
        if (match != null) {
          final int month = int.tryParse(match.group(2)!) ?? 0;
          return '${match.group(1)}年$month月';
        }
        return text;
      case CustomFormQuestionType.number:
        if (raw == null || (raw is String && raw.trim().isEmpty)) {
          return '';
        }
        return raw.toString();
      case CustomFormQuestionType.shortText:
      case CustomFormQuestionType.longText:
      case CustomFormQuestionType.date:
        return (raw ?? '').toString().trim();
    }
  }

  /// 更新單一店家答案，不覆蓋其他店家。
  static Map<String, dynamic> mergeByShop({
    required Map<String, dynamic> existing,
    required String shopId,
    required Map<String, dynamic> snapshot,
  }) {
    final Map<String, dynamic> next = Map<String, dynamic>.from(existing);
    next[shopId] = snapshot;
    return next;
  }
}
