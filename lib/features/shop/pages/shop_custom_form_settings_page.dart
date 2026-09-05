// 檔案名稱：lib/features/shop/pages/shop_custom_form_settings_page.dart
// 功能說明：店家自訂表單設定入口：選擇新增寵物或送出訂單表單。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
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
            '兩種表單分開儲存，編輯器相同，資料不會混在一起。',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          _FormTypeCard(
            title: CustomFormType.petProfile.defaultTitle,
            description: CustomFormType.petProfile.defaultDescription,
            icon: Icons.pets_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopCustomFormEditorPage(
                    shopId: shopId,
                    formType: CustomFormType.petProfile,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _FormTypeCard(
            title: CustomFormType.bookingSubmit.defaultTitle,
            description: CustomFormType.bookingSubmit.defaultDescription,
            icon: Icons.receipt_long_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopCustomFormEditorPage(
                    shopId: shopId,
                    formType: CustomFormType.bookingSubmit,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FormTypeCard extends StatelessWidget {
  const _FormTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
