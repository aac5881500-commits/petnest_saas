// 檔案名稱：lib/features/platform/platform_account_display.dart
// 功能說明：最高管理員帳號資料的唯讀欄位。不提供修改角色或 Email。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/platform_account_display.dart';

export 'package:petnest_saas/core/models/platform_account_display.dart';

class PlatformLockedAccountFields extends StatelessWidget {
  const PlatformLockedAccountFields({
    super.key,
    required this.name,
    required this.email,
    required this.uid,
    required this.sales,
  });

  final String name;
  final String email;
  final String uid;
  final Widget sales;

  @override
  Widget build(BuildContext context) {
    final String shownName =
        name.trim().isEmpty ? PlatformAccountDisplay.unset : name.trim();
    final String shownEmail =
        email.trim().isEmpty ? PlatformAccountDisplay.unset : email.trim();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(context, label: '顯示名稱', value: shownName, copyable: false),
            const SizedBox(height: 12),
            _field(
              context,
              label: 'Email',
              value: shownEmail,
              copyable: email.trim().isNotEmpty,
            ),
            const SizedBox(height: 12),
            _field(context, label: '平台角色', value: '超級管理員', copyable: false),
            const SizedBox(height: 8),
            const Text('最高管理員角色受到保護，不能在此修改。'),
            const SizedBox(height: 12),
            _field(
              context,
              label: 'UID',
              value: uid,
              copyable: uid.trim().isNotEmpty,
            ),
            const SizedBox(height: 16),
            sales,
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required String value,
    required bool copyable,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  SelectableText(value),
                ],
              ),
            ),
            if (copyable)
              IconButton(
                tooltip: '複製$label',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已複製$label')),
                  );
                },
                icon: const Icon(Icons.copy),
              ),
          ],
        ),
      ),
    );
  }
}
