// lib/features/shop/widgets/store/store_promotion_card.dart
// 🛒 後台促銷活動卡

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_status_chip.dart';

class StorePromotionCard extends StatelessWidget {
  const StorePromotionCard({
    super.key,
    required this.promotion,
    this.products = const <String, StoreProductModel>{},
    this.onView,
    this.onEdit,
    this.onToggle,
    this.onDuplicate,
    this.onArchive,
    this.onOpenProduct,
  });

  final StorePromotionModel promotion;
  final Map<String, StoreProductModel> products;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDuplicate;
  final VoidCallback? onArchive;
  final VoidCallback? onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final StoreStatusTone tone = switch (promotion.statusKey) {
      'active' => StoreStatusTone.success,
      'upcoming' => StoreStatusTone.info,
      'ended' => StoreStatusTone.neutral,
      _ => StoreStatusTone.warning,
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    promotion.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StoreStatusChip(label: promotion.statusLabel, tone: tone),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              StorePromotionTypes.label(promotion.type),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              promotion.contentsLabel(<String, String>{
                for (final MapEntry<String, StoreProductModel> entry
                    in products.entries)
                  entry.key: entry.value.name,
              }),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              promotion.isBundle && products.isNotEmpty
                  ? 'NT\$${promotion.bundleOriginalOf(<String, int>{
                      for (final MapEntry<String, StoreProductModel> entry
                          in products.entries)
                        entry.key: entry.value.price,
                    })} → NT\$${promotion.discountValue.round()}'
                  : promotion.offerDetail,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '期間：${promotion.periodLabel}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Wrap(
              spacing: 4,
              children: <Widget>[
                if (onView != null)
                  TextButton(onPressed: onView, child: const Text('查看')),
                if (onEdit != null)
                  TextButton(onPressed: onEdit, child: const Text('編輯')),
                if (onToggle != null)
                  TextButton(
                    onPressed: onToggle,
                    child: Text(promotion.enabled ? '停用' : '啟用'),
                  ),
                if (onDuplicate != null)
                  TextButton(onPressed: onDuplicate, child: const Text('複製')),
                if (onArchive != null)
                  TextButton(
                    onPressed: onArchive,
                    child: Text(promotion.usedOrderCount > 0 ? '封存' : '刪除'),
                  ),
                if (onOpenProduct != null && promotion.productIds.isNotEmpty)
                  TextButton(
                    onPressed: onOpenProduct,
                    child: const Text('查看商品'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
