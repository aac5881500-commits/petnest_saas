// 檔案名稱：lib/features/custom_form/widgets/custom_form_fill_preview.dart
// 功能說明：設定頁填寫預覽；桌機左側可勾選模擬寵物以測試條件題。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/order_custom_form_fill.dart';

class CustomFormFillPreview extends StatelessWidget {
  const CustomFormFillPreview({
    super.key,
    required this.form,
    required this.formType,
    this.interactive = false,
    this.theme,
  });

  final CustomFormModel form;
  final CustomFormType formType;
  final bool interactive;
  final HomeThemeModel? theme;

  static const List<Map<String, dynamic>> demoPets = <Map<String, dynamic>>[
    <String, dynamic>{
      'petId': 'preview_general',
      'name': '一般寵物',
      'vaccine': '無',
    },
    <String, dynamic>{
      'petId': 'preview_medical',
      'name': '有疾病寵物',
      'vaccine': '有疾病',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel resolved = theme ?? HomeThemeModel.classicDefault;
    final bool staff = formType == CustomFormType.adminCreate;
    Widget body;
    if (form.questionCount == 0) {
      body = Text(
        '尚未有題目。可套用建議初版，或自行新增分類與題目。',
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: resolved.textColor.withValues(alpha: 0.7),
        ),
      );
    } else {
      body = OrderCustomFormFill(
        form: form.copyWith(enabled: true),
        orderAnswers: const <String, dynamic>{},
        petAnswersByPetId: const <String, Map<String, dynamic>>{},
        pets: demoPets,
        onOrderChanged: (_) {},
        onPetChanged: (String petId, Map<String, dynamic> answers) {},
        theme: resolved,
        title: staff ? '填寫預覽（店員實際看到的表單）' : '填寫預覽（客戶實際看到的表單）',
        subtitle: staff
            ? '示範兩隻寵物：一般寵物不顯示疾病照護補充；有疾病寵物會顯示。'
            : '示範兩隻寵物：一般寵物不顯示疾病照護補充；有疾病寵物會顯示。',
      );
    }
    if (interactive) {
      return body;
    }
    return AbsorbPointer(child: body);
  }
}

class CustomFormDesktopFillPreview extends StatefulWidget {
  const CustomFormDesktopFillPreview({
    super.key,
    required this.form,
  });

  final CustomFormModel form;

  static const Map<String, dynamic> healthyPet = <String, dynamic>{
    'petId': 'preview_healthy',
    'name': '米米',
    'vaccine': '無',
    'medicalStatus': '無',
    'isNeutered': true,
    'allergy': '無',
    'canMedicate': false,
  };

  static const Map<String, dynamic> medicalPet = <String, dynamic>{
    'petId': 'preview_medical',
    'name': '毛毛',
    'vaccine': '心臟病',
    'medicalStatus': '心臟病',
    'isNeutered': true,
    'allergy': '無',
    'canMedicate': true,
  };

  @override
  State<CustomFormDesktopFillPreview> createState() =>
      _CustomFormDesktopFillPreviewState();
}

class _CustomFormDesktopFillPreviewState
    extends State<CustomFormDesktopFillPreview> {
  bool _includeHealthy = true;
  bool _includeMedical = true;

  List<Map<String, dynamic>> get _selectedPets {
    return <Map<String, dynamic>>[
      if (_includeHealthy) CustomFormDesktopFillPreview.healthyPet,
      if (_includeMedical) CustomFormDesktopFillPreview.medicalPet,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final HomeThemeModel theme = HomeThemeModel.classicDefault;
    final List<Map<String, dynamic>> pets = _selectedPets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '模擬本次選取寵物',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '可勾選不同狀況的寵物，確認寵物資訊題目與條件顯示是否正確。',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        _petToggleCard(
          colors: colors,
          selected: _includeHealthy,
          name: '米米',
          status: '疾病狀況：無',
          onChanged: (bool value) {
            setState(() => _includeHealthy = value);
          },
        ),
        const SizedBox(height: 8),
        _petToggleCard(
          colors: colors,
          selected: _includeMedical,
          name: '毛毛',
          status: '疾病狀況：有疾病',
          onChanged: (bool value) {
            setState(() => _includeMedical = value);
          },
        ),
        const SizedBox(height: 16),
        if (widget.form.questionCount == 0)
          Text(
            '尚未有題目。可套用建議初版，或自行新增分類與題目。',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          )
        else ...<Widget>[
          AbsorbPointer(
            child: OrderCustomFormFill(
              form: widget.form.copyWith(enabled: true),
              orderAnswers: const <String, dynamic>{},
              petAnswersByPetId: const <String, Map<String, dynamic>>{},
              pets: pets,
              onOrderChanged: (_) {},
              onPetChanged: (String petId, Map<String, dynamic> answers) {},
              theme: theme,
              title: '',
              subtitle: '',
            ),
          ),
          if (pets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '尚未選取寵物，因此不顯示寵物資訊題目。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _petToggleCard({
    required ColorScheme colors,
    required bool selected,
    required String name,
    required String status,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.55)
          : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Checkbox(
                value: selected,
                onChanged: (bool? value) {
                  onChanged(value == true);
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.surface
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
