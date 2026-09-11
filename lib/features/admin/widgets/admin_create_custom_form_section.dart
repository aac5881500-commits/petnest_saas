// 檔案名稱：lib/features/admin/widgets/admin_create_custom_form_section.dart
// 功能說明：手動建單填寫「手動訂單表單」；無題目時不顯示。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_response_fields.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class AdminCreateCustomFormSection extends StatelessWidget {
  const AdminCreateCustomFormSection({
    super.key,
    required this.form,
    required this.answers,
    required this.onChanged,
    required this.theme,
    this.fieldKeys,
  });

  final CustomFormModel? form;
  final Map<String, dynamic> answers;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final HomeThemeModel theme;
  final Map<String, GlobalKey>? fieldKeys;

  @override
  Widget build(BuildContext context) {
    final CustomFormModel? current = form;
    if (current == null || !current.shouldCollectAnswers) {
      return const SizedBox.shrink();
    }
    return BookingThemedCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '手動訂單表單',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '僅後台使用，不會顯示給客戶。必填題請完整填寫。',
            style: TextStyle(
              fontSize: 13,
              color: theme.textColor.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 10),
          CustomFormResponseFields(
            form: current,
            answers: answers,
            onChanged: onChanged,
            theme: theme,
            fieldKeys: fieldKeys,
          ),
        ],
      ),
    );
  }
}
