import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';
import 'package:petnest_saas/features/shop/models/shop_policy_templates.dart';

class ShopPolicyParametersDialog extends StatefulWidget {
  const ShopPolicyParametersDialog({super.key, required this.parameters});
  final List<ShopPolicyParameter> parameters;
  @override
  State<ShopPolicyParametersDialog> createState() =>
      _ShopPolicyParametersDialogState();
}

class _ShopPolicyParametersDialogState
    extends State<ShopPolicyParametersDialog> {
  late final _inputs = {
    for (final p in widget.parameters) p.id: TextEditingController(),
  };
  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('補齊本店實際設定'),
    scrollable: true,
    content: SizedBox(
      width: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('可先填一部分再套用。範例僅供參考，不會自動帶入；留白項目會保留原標記。'),
          for (final section
              in widget.parameters.map((p) => p.sectionKey).toSet()) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                ShopPolicyHistory.sectionLabel(
                  section,
                  PolicyApplicableService.accommodation,
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final p in widget.parameters.where(
              (p) => p.sectionKey == section,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.description),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _inputs[p.id],
                      minLines: p.multiline ? 3 : 1,
                      maxLines: p.multiline ? 6 : 2,
                      decoration: InputDecoration(
                        labelText: p.name,
                        hintText: p.example,
                        hintMaxLines: 4,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _inputs.map((key, controller) => MapEntry(key, controller.text)),
        ),
        child: const Text('套用到草稿'),
      ),
    ],
  );
}
