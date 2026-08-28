// lib/features/shop/widgets/store/store_product_card.dart
// 🛒 商城商品卡片（手機 2 欄 compact）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';

class StoreProductCard extends StatelessWidget {
  const StoreProductCard({
    super.key,
    required this.product,
    required this.theme,
    required this.onTap,
    this.stockLabel = '',
    this.outOfStock = false,
  });

  final StoreProductModel product;
  final HomeThemeModel theme;
  final VoidCallback onTap;
  final String stockLabel;
  final bool outOfStock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  child: product.imageUrl.isEmpty
                      ? ColoredBox(
                          color: theme.primaryColor.withValues(alpha: 0.08),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: theme.primaryColor,
                          ),
                        )
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return ColoredBox(
                              color: theme.primaryColor.withValues(alpha: 0.08),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: theme.primaryColor,
                              ),
                            );
                          },
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NT\$ ${product.price}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    ),
                    if (stockLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        stockLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: outOfStock
                              ? const Color(0xFFB45309)
                              : theme.textColor.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
