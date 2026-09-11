// 檔案名稱：lib/features/shop/pages/shop_custom_form_settings_page.dart
// 功能說明：店家自訂表單設定入口：三種用途、狀態與快速建立。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_custom_form_editor_page.dart';

class ShopCustomFormSettingsPage extends StatelessWidget {
  const ShopCustomFormSettingsPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '自訂表單設定',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[ShopTaskCenterButton(shopId: shopId)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Text(
            '三種表單分開儲存，用途不同，資料不會混在一起。手動訂單表單只給店員填，客戶端永遠看不到。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          _FormTypeLiveCard(
            shopId: shopId,
            formType: CustomFormType.petProfile,
            icon: Icons.pets_outlined,
          ),
          const SizedBox(height: 12),
          _FormTypeLiveCard(
            shopId: shopId,
            formType: CustomFormType.bookingSubmit,
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 12),
          _FormTypeLiveCard(
            shopId: shopId,
            formType: CustomFormType.adminCreate,
            icon: Icons.edit_note_outlined,
          ),
        ],
      ),
    );
  }
}

class _FormTypeLiveCard extends StatelessWidget {
  const _FormTypeLiveCard({
    required this.shopId,
    required this.formType,
    required this.icon,
  });

  final String shopId;
  final CustomFormType formType;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomFormModel>(
      stream: CustomFormService.instance.streamForm(
        shopId: shopId,
        formType: formType,
      ),
      builder: (BuildContext context, AsyncSnapshot<CustomFormModel> snapshot) {
        final CustomFormModel form =
            snapshot.data ??
            CustomFormModel.empty(shopId: shopId, formType: formType);
        return _FormTypeCard(
          form: form,
          icon: icon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ShopCustomFormEditorPage(
                  shopId: shopId,
                  formType: formType,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FormTypeCard extends StatelessWidget {
  const _FormTypeCard({
    required this.form,
    required this.icon,
    required this.onTap,
  });

  final CustomFormModel form;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = form.enabled && form.hasEnabledQuestions;
    final bool started = form.version > 0 || form.hasCustomQuestions;
    final CustomFormType type = form.formType;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type.defaultTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: enabled
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      enabled ? '已啟用' : '未啟用',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? colors.onPrimaryContainer
                            : colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MetaLine(label: '使用時機', value: type.whenToUse),
              _MetaLine(label: '誰填寫', value: type.whoFills),
              _MetaLine(label: '答案儲存位置', value: type.answerLocation),
              const SizedBox(height: 8),
              Text(
                '分類 ${form.sectionCount}　題目 ${form.questionCount}　必填 ${form.requiredQuestionCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onTap,
                  child: Text(started ? '開始設定' : '快速建立'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
