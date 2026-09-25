// 檔案名稱：lib/features/shop/widgets/discount_hub_host.dart
// 功能說明：優惠設定同頁編輯器宿主、適用服務卡片與併用切換卡。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/features/shop/widgets/discount_campaign_type_picker.dart';

Future<T?> presentDiscountEditor<T>({
  required BuildContext context,
  required Widget child,
  double dialogWidth = 1040,
}) {
  final double width = MediaQuery.sizeOf(context).width;
  if (width >= 980) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final Size size = MediaQuery.sizeOf(context);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: dialogWidth.clamp(720, size.width - 56),
            height: size.height * 0.92,
            child: child,
          ),
        );
      },
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.96,
        child: child,
      );
    },
  );
}

class DiscountServiceChoice extends StatelessWidget {
  const DiscountServiceChoice({
    super.key,
    required this.services,
    required this.onChanged,
    this.lockedStayOnly = false,
    this.lockReason = '',
  });

  final List<String> services;
  final ValueChanged<List<String>> onChanged;
  final bool lockedStayOnly;
  final String lockReason;

  @override
  Widget build(BuildContext context) {
    Widget card({
      required String title,
      required String subtitle,
      required List<String> value,
      required bool enabled,
    }) {
      final bool selected =
          services.length == value.length && services.every(value.contains);
      return Expanded(
        child: Material(
          color: selected ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => onChanged(List<String>.from(value)) : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: enabled ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Color(0xFF1565C0),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            card(
              title: '住宿',
              subtitle: '僅套用住宿訂單',
              value: PolicyApplicableService.accommodationOnly,
              enabled: true,
            ),
            const SizedBox(width: 8),
            card(
              title: '安親',
              subtitle: lockedStayOnly ? '此類型不適用' : '僅套用安親訂單',
              value: PolicyApplicableService.daycareOnly,
              enabled: !lockedStayOnly,
            ),
            const SizedBox(width: 8),
            card(
              title: '住宿與安親',
              subtitle: lockedStayOnly ? '此類型不適用' : '兩種服務皆可套用',
              value: PolicyApplicableService.shared,
              enabled: !lockedStayOnly,
            ),
          ],
        ),
        if (lockedStayOnly && lockReason.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            lockReason,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }
}

class DiscountToggleCard extends StatelessWidget {
  const DiscountToggleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onLabel = '可併用',
    this.offLabel = '不併用',
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String onLabel;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = value
        ? const Color(0xFF2E7D32)
        : const Color(0xFF757575);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFF2E7D32).withValues(alpha: 0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? const Color(0xFF2E7D32).withValues(alpha: 0.28)
              : Colors.grey.shade200,
        ),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                value ? onLabel : offLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: chipColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(fontSize: 12)),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

Future<DiscountCampaignType?> pickDiscountCampaignType(BuildContext context) {
  return presentDiscountEditor<DiscountCampaignType>(
    context: context,
    dialogWidth: 980,
    child: const DiscountCampaignTypePickerPage(),
  );
}
