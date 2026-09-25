// 檔案名稱：lib/features/shop/widgets/discount_promo_preview_card.dart
// 功能說明：優惠／加價設定頁的唯讀客戶付款示意。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/discount_promo_preview.dart';

class DiscountPromoPreviewCard extends StatelessWidget {
  const DiscountPromoPreviewCard({
    required this.lines,
    super.key,
    this.heading = '客戶付款／優惠預覽',
    this.footer = '',
    this.header,
  });

  final List<DiscountPromoPreviewLine> lines;
  final String heading;
  final String footer;
  final Widget? header;

  factory DiscountPromoPreviewCard.fromResult(
    DiscountPromoPreviewResult result, {
    Widget? header,
  }) {
    return DiscountPromoPreviewCard(
      heading: result.heading,
      lines: result.lines,
      footer: result.footer,
      header: header,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String note = footer.trim().isEmpty
        ? '實際金額依訂單日期、房型、安親方案、加購與優惠資格計算。'
        : footer;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              heading,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (header != null) ...<Widget>[
              const SizedBox(height: 10),
              header!,
            ],
            const SizedBox(height: 12),
            ...lines.map(_line),
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(DiscountPromoPreviewLine line) {
    final DiscountPromoPreviewKind kind = _kindOf(line);
    final Color color = switch (kind) {
      DiscountPromoPreviewKind.surcharge => const Color(0xFFE65100),
      DiscountPromoPreviewKind.discount => const Color(0xFF2E7D32),
      DiscountPromoPreviewKind.hint => const Color(0xFF757575),
      DiscountPromoPreviewKind.total => Colors.black87,
      DiscountPromoPreviewKind.base => const Color(0xFF374151),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            line.label,
            style: TextStyle(
              fontWeight: kind == DiscountPromoPreviewKind.total
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: kind == DiscountPromoPreviewKind.total ? 16 : 14,
              color: color,
            ),
          ),
          if (line.chip.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                line.chip,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  DiscountPromoPreviewKind _kindOf(DiscountPromoPreviewLine line) {
    if (line.kind != DiscountPromoPreviewKind.base) {
      return line.kind;
    }
    if (line.amount < 0) {
      return DiscountPromoPreviewKind.discount;
    }
    if (line.label.contains('加價')) {
      return DiscountPromoPreviewKind.surcharge;
    }
    if (line.amount == 0) {
      return DiscountPromoPreviewKind.hint;
    }
    if (line.label.contains('應付')) {
      return DiscountPromoPreviewKind.total;
    }
    return DiscountPromoPreviewKind.base;
  }
}
