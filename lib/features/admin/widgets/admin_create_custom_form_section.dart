// 檔案名稱：lib/features/admin/widgets/admin_create_custom_form_section.dart
// 功能說明：手動建單填寫「手動訂單表單」；無題目時不顯示。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/order_custom_form_fill.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class AdminCreateCustomFormSection extends StatelessWidget {
  const AdminCreateCustomFormSection({
    super.key,
    required this.form,
    required this.answers,
    required this.onChanged,
    required this.theme,
    this.fieldKeys,
    this.pets = const <Map<String, dynamic>>[],
    this.petAnswersByPetId = const <String, Map<String, dynamic>>{},
    this.onPetChanged,
  });

  final CustomFormModel? form;
  final Map<String, dynamic> answers;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final HomeThemeModel theme;
  final Map<String, GlobalKey>? fieldKeys;
  final List<Map<String, dynamic>> pets;
  final Map<String, Map<String, dynamic>> petAnswersByPetId;
  final void Function(String petId, Map<String, dynamic> answers)? onPetChanged;

  @override
  Widget build(BuildContext context) {
    final CustomFormModel? current = form;
    if (current == null || !current.shouldCollectAnswers) {
      return const SizedBox.shrink();
    }
    return BookingThemedCard(
      theme: theme,
      child: OrderCustomFormFill(
        form: current,
        title: '手動訂單表單',
        subtitle: '僅後台使用，不會顯示給客戶。必填題請完整填寫。',
        orderAnswers: answers,
        petAnswersByPetId: petAnswersByPetId,
        pets: pets,
        theme: theme,
        fieldKeys: fieldKeys,
        onOrderChanged: onChanged,
        onPetChanged:
            onPetChanged ?? (String petId, Map<String, dynamic> answers) {},
      ),
    );
  }
}
