// lib/features/shop/widgets/store/store_admin_product_card.dart
// 🛒 後台商品卡

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_status_chip.dart';

class StoreAdminProductCard extends StatelessWidget {
  const StoreAdminProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.priced,
    this.categoryName = '',
    this.inventoryItem,
  });

  final StoreProductModel product;
  final VoidCallback onTap;
  final StorePricedLine? priced;
  final String categoryName;
  final InventoryItemModel? inventoryItem;

  @override
  Widget build(BuildContext context) {
    final bool unlinked = !product.hasInventoryLink;
    final String stock = StoreStockHelper.adminStatusLabel(product);
    final StoreStatusTone stockTone = unlinked || stock == '未連結庫存'
        ? StoreStatusTone.warning
        : stock == '售罄'
        ? StoreStatusTone.danger
        : stock == '低庫存'
        ? StoreStatusTone.warning
        : StoreStatusTone.success;
    final String rawUnit = inventoryItem?.unit.trim().isNotEmpty == true
        ? inventoryItem!.unit.trim()
        : product.inventoryUnitSnapshot.trim();
    final String unit = rawUnit.isEmpty ? '個' : rawUnit;
    final String stockLine = unlinked
        ? '⚠ 未連結庫存'
        : inventoryItem == null
        ? '中央庫存：${product.inventoryItemNameSnapshot.isEmpty ? '已連結' : product.inventoryItemNameSnapshot}'
        : '中央庫存：${InventoryConstants.formatQuantity(inventoryItem!.currentStock)} $unit';
    final StorePricedLine line =
        priced ??
        StorePricedLine(
          product: product,
          quantity: 1,
          originalUnitPrice: product.price,
          finalUnitPrice: product.price,
        );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: product.imageUrl.isEmpty
                      ? ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08),
                          child: const Icon(Icons.shopping_bag_outlined),
                        )
                      : Image.network(product.imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (categoryName.isNotEmpty)
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 4),
                    StoreProductPriceView(line: line, compact: true),
                    Text(
                      stockLine,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: unlinked
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: unlinked
                            ? const Color(0xFFC45C26)
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        StoreStatusChip(
                          label: product.enabled ? '上架中' : '未上架',
                          tone: product.enabled
                              ? StoreStatusTone.success
                              : StoreStatusTone.neutral,
                        ),
                        if (product.featured)
                          const StoreStatusChip(
                            label: '精選',
                            tone: StoreStatusTone.info,
                          ),
                        StoreStatusChip(label: stock, tone: stockTone),
                      ],
                    ),
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
