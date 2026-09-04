// lib/features/shop/widgets/store/store_product_price_view.dart
// 🛒 商城原價 / 優惠價共用顯示

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_promotion_badge.dart';

class StoreEnabledPromotionsBuilder extends StatelessWidget {
  const StoreEnabledPromotionsBuilder({
    super.key,
    required this.shopId,
    required this.builder,
  });

  final String shopId;
  final Widget Function(
    BuildContext context,
    List<StorePromotionModel> promotions,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StorePromotionModel>>(
      stream: StorePromotionService.instance.streamEnabledPromotions(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StorePromotionModel>> snapshot,
          ) {
            return builder(
              context,
              snapshot.data ?? const <StorePromotionModel>[],
            );
          },
    );
  }
}

class StoreProductPriceView extends StatelessWidget {
  const StoreProductPriceView({
    super.key,
    required this.line,
    this.compact = false,
    this.color,
    this.showSaved = false,
    this.showUntil = false,
    this.showBadge = true,
  });

  final StorePricedLine line;
  final bool compact;
  final Color? color;
  final bool showSaved;
  final bool showUntil;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? Theme.of(context).colorScheme.primary;
    final bool cheaper = line.finalUnitPrice < line.originalUnitPrice;
    final DateTime? until = line.appliedEndAt ?? line.promotion?.endAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              StoreMoney.ntd(line.finalUnitPrice),
              style: TextStyle(
                fontSize: compact ? 14 : 22,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
            if (cheaper)
              Text(
                StoreMoney.ntd(line.originalUnitPrice),
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey.shade600,
                ),
              ),
            if (showBadge)
              StorePromotionBadge(line: line, color: tone, compact: compact),
          ],
        ),
        if (showSaved && cheaper)
          Text(
            '現省 ${StoreMoney.ntd(line.originalUnitPrice - line.finalUnitPrice)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        if (showUntil && until != null)
          Text(
            '活動至 ${_until(until)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
      ],
    );
  }

  String _until(DateTime value) {
    return '${value.month}/${value.day} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
