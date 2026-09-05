// 檔案名稱：lib/features/shop/widgets/booking/daycare_offer_card.dart
// 功能說明：安親房型／獨立方案小卡：多行計價說明

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class DaycareOfferCard extends StatelessWidget {
  const DaycareOfferCard({
    super.key,
    required this.theme,
    required this.title,
    required this.lines,
    required this.selected,
    required this.enabled,
    this.blockedReason,
    this.onTap,
  });

  final HomeThemeModel theme;
  final String title;
  final List<String> lines;
  final bool selected;
  final bool enabled;
  final String? blockedReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = selected ? theme.primaryColor : theme.cardBorderColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? theme.primaryColor.withValues(alpha: 0.08)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: selected ? 1.6 : 1),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                    if (selected)
                      Text(
                        '已選取',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...lines.map((String line) {
                  final bool muted = line == '方案未啟用';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          muted ? Icons.info_outline : Icons.circle,
                          size: muted ? 16 : 6,
                          color: muted
                              ? theme.textColor.withValues(alpha: 0.55)
                              : theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: line.startsWith('基本')
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: theme.textColor.withValues(
                                alpha: muted ? 0.7 : 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (blockedReason != null && blockedReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      blockedReason!,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<String> linesForPlan(DaycarePlanModel plan) =>
      plan.customerSummaryLines;
}
