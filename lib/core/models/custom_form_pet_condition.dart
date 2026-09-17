// 檔案名稱：lib/core/models/custom_form_pet_condition.dart
// 功能說明：寵物資訊題目依寵物固定欄位判斷是否顯示；無法判定時不顯示。

import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';

class CustomFormPetCondition {
  CustomFormPetCondition._();

  static String careSectionTitle(Map<String, dynamic> pet) {
    final String name = (pet['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return '寵物的照護資訊';
    }
    return '$name的照護資訊';
  }

  static String petIdOf(Map<String, dynamic> pet) {
    return (pet['petId'] ?? pet['id'] ?? '').toString().trim();
  }

  static bool questionVisibleForPet({
    required CustomFormQuestion question,
    required Map<String, dynamic> pet,
  }) {
    if (question.answerScope != CustomFormAnswerScope.pet) {
      return false;
    }
    if (!question.enabled || question.id.trim().isEmpty) {
      return false;
    }
    final CustomFormDisplayCondition condition = question.displayCondition;
    if (condition.isEmpty) {
      return true;
    }
    try {
      return _matches(pet: pet, condition: condition);
    } catch (_) {
      return false;
    }
  }

  static bool _matches({
    required Map<String, dynamic> pet,
    required CustomFormDisplayCondition condition,
  }) {
    final CustomFormPetConditionField field =
        CustomFormPetConditionField.fromStorage(condition.field);
    final String expected = condition.value.trim();
    if (field == CustomFormPetConditionField.none || expected.isEmpty) {
      return true;
    }
    final Map<String, dynamic> snapshot = PetSnapshot.fromPet(pet);
    switch (field) {
      case CustomFormPetConditionField.none:
        return true;
      case CustomFormPetConditionField.isNeutered:
        final bool? flag = _asBool(snapshot['isNeutered'] ?? pet['isNeutered']);
        if (flag == null) {
          return false;
        }
        if (expected == '有結紮') {
          return flag;
        }
        if (expected == '未結紮') {
          return !flag;
        }
        return false;
      case CustomFormPetConditionField.medicalStatus:
        final String medical = PetSnapshot.medicalStatusText(pet);
        if (medical.isEmpty) {
          return false;
        }
        if (expected == '無') {
          return medical == '無';
        }
        if (expected == '有疾病') {
          return PetSnapshot.hasRecordedDisease(pet);
        }
        return medical == expected;
      case CustomFormPetConditionField.allergy:
        final String allergy = (snapshot['allergy'] ?? pet['allergy'] ?? '')
            .toString()
            .trim();
        if (allergy.isEmpty) {
          return false;
        }
        if (expected == '有') {
          return allergy != '無';
        }
        if (expected == '無') {
          return allergy == '無';
        }
        return false;
      case CustomFormPetConditionField.canMedicate:
        final Object? raw = snapshot.containsKey('canMedicate')
            ? snapshot['canMedicate']
            : pet['canMedicate'];
        if (raw == null &&
            !pet.containsKey('canMedicate') &&
            !snapshot.containsKey('canMedicate')) {
          return false;
        }
        final bool? flag = _asBool(raw);
        if (flag == null) {
          return false;
        }
        if (expected == '是') {
          return flag;
        }
        if (expected == '否') {
          return !flag;
        }
        return false;
    }
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String text = value.trim().toLowerCase();
      if (text.isEmpty) {
        return null;
      }
      if (text == 'true' || text == '1' || text == '是' || text == '有結紮') {
        return true;
      }
      if (text == 'false' || text == '0' || text == '否' || text == '未結紮') {
        return false;
      }
    }
    return null;
  }
}
