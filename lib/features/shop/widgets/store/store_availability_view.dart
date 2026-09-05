// 檔案名稱：lib/features/shop/widgets/store/store_availability_view.dart
// 功能說明：商城庫存狀態（首頁 / 搜尋 / 分類 / 詳情 / 活動 picker 共用）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';

class StoreAvailabilityView extends StatelessWidget {
  const StoreAvailabilityView({
    super.key,
    required this.product,
    this.showStockToCustomer = true,
    this.unpublished = false,
    this.compact = false,
    this.soldOutOverride = false,
    this.color,
  });

  final StoreProductModel product;
  final bool showStockToCustomer;
  final bool unpublished;
  final bool compact;
  final bool soldOutOverride;
  final Color? color;

  static String label({
    required StoreProductModel product,
    bool showStockToCustomer = true,
    bool unpublished = false,
    bool soldOutOverride = false,
  }) {
    if (soldOutOverride) {
      return '售罄';
    }
    return StoreStockHelper.storefrontStatusLabel(
      product,
      showStockToCustomer: showStockToCustomer,
      unpublished: unpublished,
    );
  }

  static bool isSoldOut(StoreProductModel product, {bool unpublished = false}) {
    if (unpublished || !product.enabled) {
      return true;
    }
    return StoreStockHelper.isOutOfStock(product);
  }

  @override
  Widget build(BuildContext context) {
    final String text = label(
      product: product,
      showStockToCustomer: showStockToCustomer,
      unpublished: unpublished,
      soldOutOverride: soldOutOverride,
    );
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool soldOut = soldOutOverride || isSoldOut(product);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 11 : 13,
        fontWeight: FontWeight.w700,
        color: color ?? (soldOut ? const Color(0xFFB45309) : Colors.black54),
      ),
    );
  }
}
