// lib/features/shop/widgets/store/store_product_card.dart
// 🛒 商城商品卡：compact 橫滑 / grid 兩欄共用視覺

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_availability_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_promotion_badge.dart';

enum StoreProductCardVariant { compact, grid }

class StoreProductGrid extends StatelessWidget {
  const StoreProductGrid({
    super.key,
    required this.products,
    required this.theme,
    required this.onTap,
    required this.pricedOf,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
    this.showStockToCustomer = true,
    this.appearance,
  });

  final List<StoreProductModel> products;
  final HomeThemeModel theme;
  final void Function(StoreProductModel product) onTap;
  final StorePricedLine Function(StoreProductModel product) pricedOf;
  final EdgeInsets padding;
  final bool showStockToCustomer;
  final StoreAppearanceSetting? appearance;

  static int columnsFor(double width) {
    if (width >= 900) {
      return 4;
    }
    if (width >= 600) {
      return 3;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = columnsFor(constraints.maxWidth);
        final List<Widget> rows = <Widget>[];
        for (int index = 0; index < products.length; index += columns) {
          final List<StoreProductModel> slice = products
              .skip(index)
              .take(columns)
              .toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: index + columns < products.length ? 12 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(columns, (int column) {
                  if (column >= slice.length) {
                    return const Expanded(child: SizedBox.shrink());
                  }
                  final StoreProductModel product = slice[column];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: column == 0 ? 0 : 6,
                        right: column == columns - 1 ? 0 : 6,
                      ),
                      child: StoreProductCard(
                        product: product,
                        theme: theme,
                        variant: StoreProductCardVariant.grid,
                        priced: pricedOf(product),
                        outOfStock: StoreStockHelper.isOutOfStock(product),
                        showStockToCustomer: showStockToCustomer,
                        appearance: appearance,
                        onTap: () => onTap(product),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        }
        return Padding(
          padding: padding,
          child: Column(children: rows),
        );
      },
    );
  }
}

class StoreProductCarousel extends StatelessWidget {
  const StoreProductCarousel({
    super.key,
    required this.products,
    required this.theme,
    required this.onTap,
    required this.pricedOf,
    this.showStockToCustomer = true,
    this.cardWidth = 160,
    this.appearance,
  });

  final List<StoreProductModel> products;
  final HomeThemeModel theme;
  final void Function(StoreProductModel product) onTap;
  final StorePricedLine Function(StoreProductModel product) pricedOf;
  final bool showStockToCustomer;
  final double cardWidth;
  final StoreAppearanceSetting? appearance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardWidth + 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final StoreProductModel product = products[index];
          return SizedBox(
            width: cardWidth,
            child: StoreProductCard(
              product: product,
              theme: theme,
              variant: StoreProductCardVariant.compact,
              priced: pricedOf(product),
              outOfStock: StoreStockHelper.isOutOfStock(product),
              showStockToCustomer: showStockToCustomer,
              appearance: appearance,
              onTap: () => onTap(product),
            ),
          );
        },
      ),
    );
  }
}

class StoreProductCard extends StatelessWidget {
  const StoreProductCard({
    super.key,
    required this.product,
    required this.theme,
    required this.onTap,
    this.stockLabel = '',
    this.outOfStock = false,
    this.showStockToCustomer = true,
    this.priced,
    this.variant = StoreProductCardVariant.grid,
    this.appearance,
  });

  final StoreProductModel product;
  final HomeThemeModel theme;
  final StoreAppearanceSetting? appearance;
  final VoidCallback onTap;
  final String stockLabel;
  final bool outOfStock;
  final bool showStockToCustomer;
  final StorePricedLine? priced;
  final StoreProductCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final StorePricedLine line =
        priced ??
        StorePricedLine(
          product: product,
          quantity: 1,
          originalUnitPrice: product.price,
          finalUnitPrice: product.price,
        );
    final String status = stockLabel.isEmpty
        ? StoreAvailabilityView.label(
            product: product,
            showStockToCustomer: showStockToCustomer,
          )
        : stockLabel;
    final bool soldOut = outOfStock || StoreStockHelper.isOutOfStock(product);
    final bool compact = variant == StoreProductCardVariant.compact;
    final StoreAppearanceSetting look =
        appearance ?? const StoreAppearanceSetting();
    final Color cardColor = look.cardSolidColor(theme);
    final Color titleColor = look.primaryTextColor(theme);
    final Color mutedColor = look.secondaryTextColor(theme);
    final Color priceColor = look.priceColor(theme);
    final Color accent = look.accentColor(theme);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: cardColor)),
              if (look.usesCardImage)
                Positioned.fill(
                  child: Image.network(
                    look.cardBackgroundImageUrl,
                    fit: look.cardBoxFit,
                    alignment: look.cardAlignment,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              if (look.usesCardImage)
                Positioned.fill(
                  child: ColoredBox(
                    color: look
                        .overlayColor(theme)
                        .withValues(alpha: look.overlayOpacity),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ColoredBox(
                              color: look.usesCardImage
                                  ? Colors.transparent
                                  : cardColor,
                              child: product.imageUrl.isEmpty
                                  ? Icon(
                                      Icons.shopping_bag_outlined,
                                      color: accent,
                                    )
                                  : Opacity(
                                      opacity: soldOut ? 0.6 : 1,
                                      child: Image.network(
                                        product.imageUrl,
                                        fit: BoxFit.contain,
                                        loadingBuilder:
                                            (
                                              BuildContext context,
                                              Widget child,
                                              ImageChunkEvent? progress,
                                            ) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return ColoredBox(
                                                color: look.usesCardImage
                                                    ? Colors.transparent
                                                    : cardColor,
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: accent,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            },
                                        errorBuilder: (_, _, _) {
                                          return Icon(
                                            Icons.shopping_bag_outlined,
                                            color: accent,
                                          );
                                        },
                                      ),
                                    ),
                            ),
                            if (line.showsPromotionOnProductImage)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: StorePromotionBadge(
                                  line: line,
                                  color: accent,
                                ),
                              ),
                            if (soldOut)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '已售完',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 8 : 9,
                        7,
                        compact ? 8 : 9,
                        compact ? 8 : 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 12 : 13,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StoreProductPriceView(
                            line: line,
                            compact: true,
                            showBadge: false,
                            color: priceColor,
                          ),
                          if (line.isBuyXGetYOffer &&
                              line.offerBadge.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                line.offerBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ),
                          if (status.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: soldOut
                                      ? const Color(0xFFB45309)
                                      : mutedColor,
                                ),
                              ),
                            ),
                        ],
                      ),
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
