// lib/features/shop/widgets/store/store_bundle_card.dart
// 🛒 前台套裝優惠卡

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';

class StoreBundleCard extends StatelessWidget {
  const StoreBundleCard({
    super.key,
    required this.promotion,
    required this.products,
    required this.theme,
    required this.onTap,
  });

  final StorePromotionModel promotion;
  final List<StoreProductModel> products;
  final HomeThemeModel theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StoreBundleQuote quote = StorePricingService.instance.quoteBundle(
      promotion: promotion,
      sets: 1,
      products: products,
    );
    final bool soldOut = quote.soldOut;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        soldOut ? '售罄' : '套裝優惠',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (quote.saved > 0)
                      Text(
                        '現省 NT\$${quote.saved}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  promotion.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '內含 ${promotion.bundlePieceCount} 件商品',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.68),
                  ),
                ),
                if (quote.componentLabels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      quote.componentLabels.join(' + '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textColor.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Text(
                      'NT\$${quote.finalTotal}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (quote.originalTotal > quote.finalTotal)
                      Text(
                        'NT\$${quote.originalTotal}',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: theme.textColor.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
