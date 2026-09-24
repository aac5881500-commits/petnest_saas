// 檔案名稱：lib/features/shop/widgets/discount_promo_preview_card.dart
// 功能說明：優惠／加價設定頁的唯讀客戶付款示意。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/discount_promo_preview.dart';

class DiscountPromoPreviewCard extends StatelessWidget {
  const DiscountPromoPreviewCard({required this.lines, super.key});

  final List<DiscountPromoPreviewLine> lines;

  @override
  Widget build(BuildContext context) {
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
            const Text(
              '客戶付款／優惠預覽',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '實際金額依訂單日期、房型、安親方案、加購與優惠資格計算。',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            ...lines.map((DiscountPromoPreviewLine line) {
              final bool isTotal = line == lines.last;
              final bool positive = line.amount > 0 && !isTotal;
              final bool negative = line.amount < 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line.label,
                  style: TextStyle(
                    fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                    color: negative
                        ? Colors.green.shade800
                        : (positive && line.label.contains('加價')
                              ? Colors.deepOrange.shade800
                              : Colors.grey.shade900),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
