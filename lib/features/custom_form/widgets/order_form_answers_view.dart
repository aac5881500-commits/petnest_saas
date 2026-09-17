// 檔案名稱：lib/features/custom_form/widgets/order_form_answers_view.dart
// 功能說明：完整表單階層顯示：訂單資訊＋每隻寵物的照護資訊。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_order_form_answers.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';

class OrderFormAnswersView extends StatelessWidget {
  const OrderFormAnswersView({
    super.key,
    required this.orderRaw,
    required this.petAnswersByPetId,
    required this.pets,
    required this.theme,
    this.orderTitle = '訂單資訊',
    this.collapsible = false,
    this.initiallyExpanded = false,
  });

  final dynamic orderRaw;
  final Map<String, dynamic> petAnswersByPetId;
  final List<Map<String, dynamic>> pets;
  final HomeThemeModel theme;
  final String orderTitle;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      CustomFormAnswerView(
        raw: orderRaw,
        title: orderTitle,
        theme: theme,
        collapsible: collapsible,
        initiallyExpanded: initiallyExpanded,
      ),
    ];
    final Set<String> seen = <String>{};
    for (final Map<String, dynamic> pet in pets) {
      final String petId = CustomFormPetCondition.petIdOf(pet);
      if (petId.isEmpty || seen.contains(petId)) {
        continue;
      }
      seen.add(petId);
      final Map<String, dynamic>? entry = petAnswersByPetId[petId] is Map
          ? Map<String, dynamic>.from(petAnswersByPetId[petId] as Map)
          : null;
      if (entry == null) {
        continue;
      }
      children.add(
        CustomFormAnswerView(
          raw: entry,
          title: CustomFormPetCondition.careSectionTitle(<String, dynamic>{
            'name': BookingOrderFormAnswers.petNameOf(
              entry,
              (pet['name'] ?? '').toString(),
            ),
          }),
          theme: theme,
          collapsible: collapsible,
          initiallyExpanded: initiallyExpanded,
        ),
      );
    }
    petAnswersByPetId.forEach((String petId, dynamic value) {
      if (seen.contains(petId) || value is! Map) {
        return;
      }
      seen.add(petId);
      final Map<String, dynamic> entry = Map<String, dynamic>.from(value);
      children.add(
        CustomFormAnswerView(
          raw: entry,
          title: CustomFormPetCondition.careSectionTitle(<String, dynamic>{
            'name': BookingOrderFormAnswers.petNameOf(entry, petId),
          }),
          theme: theme,
          collapsible: collapsible,
          initiallyExpanded: initiallyExpanded,
        ),
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  static bool hasVisibleContent({
    required dynamic orderRaw,
    required Map<String, dynamic> petAnswersByPetId,
  }) {
    if ((CustomFormAnswerSnapshot.tryParse(orderRaw)?.filledCount ?? 0) > 0) {
      return true;
    }
    return BookingOrderFormAnswers.filledCountOfMap(petAnswersByPetId) > 0;
  }
}
