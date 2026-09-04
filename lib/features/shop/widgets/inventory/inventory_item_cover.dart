// lib/features/shop/widgets/inventory/inventory_item_cover.dart
// 📦 庫存品項代表圖
// 功能：有 imageUrl 時顯示縮圖；沒有圖片時顯示 placeholder。舊資料沒有圖片欄位仍可正常顯示。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';

class InventoryItemCover extends StatelessWidget {
  const InventoryItemCover({
    super.key,
    required this.item,
    this.size = 72,
    this.borderRadius = 14,
  });

  final InventoryItemModel item;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: colors.primary.withValues(alpha: 0.08),
        child: item.hasCoverImage
            ? Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return _Placeholder(color: colors.primary, size: size);
                    },
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return _Placeholder(color: colors.primary, size: size);
                    },
              )
            : _Placeholder(color: colors.primary, size: size),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.inventory_2_outlined, color: color, size: size * 0.42),
    );
  }
}
