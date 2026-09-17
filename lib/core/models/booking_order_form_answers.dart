// 檔案名稱：lib/core/models/booking_order_form_answers.dart
// 功能說明：訂單資訊／寵物資訊自訂表單答案的組裝、驗證與訂單快照欄位。

import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';

class BookingOrderFormAnswers {
  BookingOrderFormAnswers._();

  static const String petFormAnswersByPetIdField = 'petFormAnswersByPetId';
  static const String adminPetFormAnswersByPetIdField =
      'adminPetFormAnswersByPetId';
  static const String nestedPetFormAnswers = 'petFormAnswers';
  static const String nestedAdminPetFormAnswers = 'adminPetFormAnswers';

  static CustomFormModel orderForm(CustomFormModel form) {
    return form.whereQuestions(
      (CustomFormQuestion question) =>
          question.answerScope == CustomFormAnswerScope.order,
    );
  }

  static CustomFormModel petFormFor({
    required CustomFormModel form,
    required Map<String, dynamic> pet,
  }) {
    return form.whereQuestions(
      (CustomFormQuestion question) =>
          CustomFormPetCondition.questionVisibleForPet(
            question: question,
            pet: pet,
          ),
    );
  }

  static bool hasPetQuestions(CustomFormModel form) {
    return form
        .enabledQuestionEntriesWhere(
          (CustomFormQuestion question) =>
              question.answerScope == CustomFormAnswerScope.pet,
        )
        .isNotEmpty;
  }

  static CustomFormValidationResult validateOrder({
    required CustomFormModel form,
    required Map<String, dynamic> answersByQuestionId,
  }) {
    return CustomFormAnswerSnapshot.validate(
      form: orderForm(form),
      answersByQuestionId: answersByQuestionId,
    );
  }

  static CustomFormValidationResult validatePet({
    required CustomFormModel form,
    required Map<String, dynamic> pet,
    required Map<String, dynamic> answersByQuestionId,
  }) {
    final CustomFormModel visible = petFormFor(form: form, pet: pet);
    final CustomFormValidationResult result = CustomFormAnswerSnapshot.validate(
      form: visible,
      answersByQuestionId: answersByQuestionId,
    );
    if (result.isValid) {
      return result;
    }
    final String name = (pet['name'] ?? '').toString().trim();
    final String who = name.isEmpty ? '寵物' : name;
    return CustomFormValidationResult(
      isValid: false,
      firstInvalidQuestionId: result.firstInvalidQuestionId,
      message: result.message.isEmpty
          ? '請完成$who的照護資訊'
          : '$who：${result.message}',
    );
  }

  static CustomFormAnswerSnapshot? buildOrderSnapshot({
    required CustomFormModel form,
    required Map<String, dynamic> answersByQuestionId,
  }) {
    final CustomFormModel scoped = orderForm(form);
    if (!scoped.shouldCollectAnswers) {
      return null;
    }
    return CustomFormAnswerSnapshot.build(
      form: scoped,
      answersByQuestionId: answersByQuestionId,
    );
  }

  static CustomFormAnswerSnapshot? buildPetSnapshot({
    required CustomFormModel form,
    required Map<String, dynamic> pet,
    required Map<String, dynamic> answersByQuestionId,
  }) {
    final CustomFormModel scoped = petFormFor(form: form, pet: pet);
    if (!scoped.hasEnabledQuestions) {
      return null;
    }
    return CustomFormAnswerSnapshot.build(
      form: scoped.copyWith(enabled: true),
      answersByQuestionId: answersByQuestionId,
    );
  }

  static Map<String, dynamic> encodeByPetId({
    required CustomFormModel form,
    required List<Map<String, dynamic>> pets,
    required Map<String, Map<String, dynamic>> answersByPetId,
  }) {
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final Map<String, dynamic> pet in pets) {
      final String petId = CustomFormPetCondition.petIdOf(pet);
      if (petId.isEmpty) {
        continue;
      }
      final CustomFormAnswerSnapshot? snapshot = buildPetSnapshot(
        form: form,
        pet: pet,
        answersByQuestionId: answersByPetId[petId] ?? const <String, dynamic>{},
      );
      if (snapshot == null || snapshot.isEmpty) {
        continue;
      }
      out[petId] = encodePetEntry(
        petId: petId,
        petName: (pet['name'] ?? '').toString(),
        snapshot: snapshot,
      );
    }
    return out;
  }

  static Map<String, dynamic> encodePetEntry({
    required String petId,
    required String petName,
    required CustomFormAnswerSnapshot snapshot,
  }) {
    return <String, dynamic>{
      'petId': petId,
      'petName': petName,
      ...snapshot.toCallableMap(),
    };
  }

  static List<Map<String, dynamic>> attachToPets({
    required List<Map<String, dynamic>> pets,
    required Map<String, dynamic> byPetId,
    String nestedKey = nestedPetFormAnswers,
  }) {
    return pets.map((Map<String, dynamic> pet) {
      final String petId = CustomFormPetCondition.petIdOf(pet);
      final Object? entry = byPetId[petId];
      if (entry is! Map || petId.isEmpty) {
        return Map<String, dynamic>.from(pet);
      }
      return <String, dynamic>{
        ...pet,
        nestedKey: Map<String, dynamic>.from(entry),
      };
    }).toList();
  }

  static Map<String, dynamic> parseByPetId(dynamic raw) {
    if (raw is! Map) {
      return <String, dynamic>{};
    }
    final Map<String, dynamic> out = <String, dynamic>{};
    raw.forEach((dynamic key, dynamic value) {
      final String petId = key.toString().trim();
      if (petId.isEmpty || value is! Map) {
        return;
      }
      out[petId] = Map<String, dynamic>.from(value);
    });
    return out;
  }

  static Map<String, dynamic> resolveByPetId({
    required Map<String, dynamic> booking,
    required bool admin,
  }) {
    final Map<String, dynamic> fromRoot = parseByPetId(
      booking[admin
          ? adminPetFormAnswersByPetIdField
          : petFormAnswersByPetIdField],
    );
    if (fromRoot.isNotEmpty) {
      return fromRoot;
    }
    final Map<String, dynamic> fromPets = <String, dynamic>{};
    final Object? petsRaw = booking['pets'];
    if (petsRaw is List) {
      for (final Object? item in petsRaw) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> pet = Map<String, dynamic>.from(item);
        final String petId = CustomFormPetCondition.petIdOf(pet);
        final Object? nested =
            pet[admin ? nestedAdminPetFormAnswers : nestedPetFormAnswers];
        if (petId.isEmpty || nested is! Map) {
          continue;
        }
        fromPets[petId] = <String, dynamic>{
          'petId': petId,
          'petName': (pet['name'] ?? '').toString(),
          ...Map<String, dynamic>.from(nested),
        };
      }
    }
    return fromPets;
  }

  static String petNameOf(Map<String, dynamic> entry, String fallbackId) {
    final String name = (entry['petName'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }
    return fallbackId;
  }

  static int filledCountOfMap(Map<String, dynamic> byPetId) {
    int total = 0;
    for (final Object? value in byPetId.values) {
      total += CustomFormAnswerSnapshot.tryParse(value)?.filledCount ?? 0;
    }
    return total;
  }
}
