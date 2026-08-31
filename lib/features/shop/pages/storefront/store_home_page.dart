// lib/features/shop/pages/storefront/store_home_page.dart
// 🛒 商城前台首頁

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_bundle_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_cart_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_product_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_carousel.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_bundle_card.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_card.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';

class StoreHomePage extends StatefulWidget {
  const StoreHomePage({
    super.key,
    required this.shopId,
    required this.shop,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  final TextEditingController _search = TextEditingController();
  String _categoryId = '';
  bool _promoOnly = false;
  String _sort = 'recommended';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openCart() {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StoreCartPage(
          shopId: widget.shopId,
          shop: widget.shop,
          theme: widget.theme,
        ),
      ),
    );
  }

  void _openProduct(StoreProductModel product, HomeThemeModel theme) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StoreProductDetailPage(
          shopId: widget.shopId,
          shop: widget.shop,
          productId: product.id,
          theme: theme,
        ),
      ),
    );
  }

  List<StoreProductModel> _sortProducts(
    List<StoreProductModel> products,
    StorePricedLine Function(StoreProductModel product) pricedOf,
  ) {
    final List<StoreProductModel> next = List<StoreProductModel>.from(products);
    next.sort((StoreProductModel a, StoreProductModel b) {
      switch (_sort) {
        case 'newest':
          return b.createdAt.compareTo(a.createdAt);
        case 'priceLow':
          return pricedOf(
            a,
          ).finalUnitPrice.compareTo(pricedOf(b).finalUnitPrice);
        case 'priceHigh':
          return pricedOf(
            b,
          ).finalUnitPrice.compareTo(pricedOf(a).finalUnitPrice);
        default:
          final int byOrder = a.sortOrder.compareTo(b.sortOrder);
          if (byOrder != 0) {
            return byOrder;
          }
          return a.name.compareTo(b.name);
      }
    });
    return next;
  }

  String _sortLabel() {
    switch (_sort) {
      case 'newest':
        return '最新上架';
      case 'priceLow':
        return '價格低到高';
      case 'priceHigh':
        return '價格高到低';
      default:
        return '推薦排序';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> settingsSnapshot) {
        final StoreHomeDisplaySettings home = StoreHomeDisplaySettings.fromMap(
          settingsSnapshot.data ?? const <String, dynamic>{},
        );
        final HomeThemeModel theme = home.resolveTheme(widget.theme);
        final StoreAppearanceSetting look = home.storeAppearance;
        final String title = home.resolvedStorefrontTitle;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textColor,
            elevation: 0,
            title: Text(title),
            actions: <Widget>[
              StreamBuilder<List<StoreCartItem>>(
                stream: StoreCartService.instance.streamCart(widget.shopId),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<StoreCartItem>> snapshot,
                    ) {
                      final int count =
                          (snapshot.data ?? const <StoreCartItem>[]).fold<int>(
                            0,
                            (int sum, StoreCartItem item) {
                              return sum + item.quantity;
                            },
                          );
                      return IconButton(
                        tooltip: '購物車',
                        onPressed: _openCart,
                        icon: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                      );
                    },
              ),
            ],
          ),
          body:
              !StorefrontAccess.isStorefrontOpen(
                shop: widget.shop,
                settings: settingsSnapshot.data,
              )
              ? const Center(child: Text('賣場目前未開放'))
              : StoreEnabledPromotionsBuilder(
                  shopId: widget.shopId,
                  builder: (BuildContext context, promotions) {
                    return StreamBuilder<List<StoreCategoryModel>>(
                      stream: StoreCategoryService.instance.streamCategories(
                        widget.shopId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<StoreCategoryModel>>
                            categorySnapshot,
                          ) {
                            return StreamBuilder<List<StoreProductModel>>(
                              stream: StoreProductService.instance
                                  .streamEnabledProducts(widget.shopId),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<List<StoreProductModel>>
                                    productSnapshot,
                                  ) {
                                    if (productSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        !productSnapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    final String keyword = _search.text
                                        .trim()
                                        .toLowerCase();
                                    final bool browsing =
                                        keyword.isEmpty && !_promoOnly;
                                    final List<StoreCategoryModel> categories =
                                        (categorySnapshot.data ??
                                                const <StoreCategoryModel>[])
                                            .where(
                                              (StoreCategoryModel item) =>
                                                  item.enabled,
                                            )
                                            .toList();
                                    final List<StoreProductModel> enabled =
                                        productSnapshot.data ??
                                        const <StoreProductModel>[];

                                    StorePricedLine pricedOf(
                                      StoreProductModel product,
                                    ) {
                                      return StorePricingService.instance
                                          .quoteProduct(
                                            product: product,
                                            promotions: promotions,
                                          );
                                    }

                                    bool sellable(StoreProductModel product) {
                                      if (!product.hasInventoryLink) {
                                        return false;
                                      }
                                      return !home.hideOutOfStock ||
                                          !StoreStockHelper.isOutOfStock(
                                            product,
                                          );
                                    }

                                    final List<StoreProductModel> visible =
                                        enabled.where(sellable).toList();
                                    final DateTime now = DateTime.now();
                                    final List<StorePromotionModel>
                                    activeBundles = promotions.where((
                                      StorePromotionModel item,
                                    ) {
                                      return item.isBundle &&
                                          item.isActiveAt(now);
                                    }).toList();
                                    List<StoreProductModel> featured = visible
                                        .where(
                                          (StoreProductModel item) =>
                                              item.featured,
                                        )
                                        .take(home.featuredCount)
                                        .toList();
                                    List<StoreProductModel> promoProducts =
                                        visible
                                            .where((StoreProductModel item) {
                                              return pricedOf(item).hasOffer;
                                            })
                                            .take(home.featuredCount)
                                            .toList();
                                    bool showFeatured =
                                        browsing &&
                                        _categoryId.isEmpty &&
                                        home.showFeaturedProducts &&
                                        featured.isNotEmpty;
                                    bool showPromo =
                                        browsing &&
                                        _categoryId.isEmpty &&
                                        home.showPromoProducts &&
                                        (promoProducts.isNotEmpty ||
                                            activeBundles.isNotEmpty);
                                    if (visible.length <= 2) {
                                      if (showPromo) {
                                        showFeatured = false;
                                      } else if (showFeatured) {
                                        showPromo = false;
                                      }
                                    }

                                    final List<StoreProductModel> catalog =
                                        _sortProducts(
                                          visible.where((
                                            StoreProductModel product,
                                          ) {
                                            final bool matchesCategory =
                                                _categoryId.isEmpty ||
                                                product.categoryId ==
                                                    _categoryId;
                                            final bool matchesSearch =
                                                keyword.isEmpty ||
                                                product.name
                                                    .toLowerCase()
                                                    .contains(keyword);
                                            final bool matchesPromo =
                                                !_promoOnly ||
                                                pricedOf(product).hasOffer;
                                            return matchesCategory &&
                                                matchesSearch &&
                                                matchesPromo;
                                          }).toList(),
                                          pricedOf,
                                        );

                                    final List<StoreBannerModel> banners =
                                        home.showBanners
                                        ? home.enabledBanners
                                        : const <StoreBannerModel>[];
                                    final bool showFallbackBanner =
                                        browsing &&
                                        home.showBanners &&
                                        banners.isEmpty;

                                    return CustomScrollView(
                                      slivers: <Widget>[
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              10,
                                              16,
                                              0,
                                            ),
                                            child: SizedBox(
                                              height: 46,
                                              child: TextField(
                                                controller: _search,
                                                onChanged: (_) =>
                                                    setState(() {}),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: theme.textColor,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: '搜尋商品',
                                                  prefixIcon: const Icon(
                                                    Icons.search,
                                                    size: 20,
                                                  ),
                                                  filled: true,
                                                  fillColor: theme.cardColor,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 0,
                                                      ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color:
                                                          theme.cardBorderColor,
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: theme
                                                              .cardBorderColor,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: theme
                                                              .primaryColor,
                                                        ),
                                                      ),
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (home.hasStorefrontSubtitle)
                                          SliverToBoxAdapter(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    8,
                                                    16,
                                                    0,
                                                  ),
                                              child: Text(
                                                home.resolvedStorefrontSubtitle,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: theme.textColor
                                                      .withValues(alpha: 0.68),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (browsing && home.hasAnnouncement)
                                          SliverToBoxAdapter(
                                            child: _AnnouncementBar(
                                              theme: theme,
                                              text: home.announcementText,
                                            ),
                                          ),
                                        if (browsing && banners.isNotEmpty)
                                          SliverToBoxAdapter(
                                            child: StoreBannerCarousel(
                                              banners: banners,
                                              theme: theme,
                                              autoPlay: home.bannerAutoPlay,
                                              autoPlaySeconds:
                                                  home.bannerAutoPlaySeconds,
                                              onTap: (StoreBannerModel banner) {
                                                _onBannerTap(
                                                  banner,
                                                  theme,
                                                  enabled,
                                                  promotions,
                                                );
                                              },
                                            ),
                                          ),
                                        if (showFallbackBanner)
                                          SliverToBoxAdapter(
                                            child: StoreFallbackBanner(
                                              theme: theme,
                                              title: title,
                                              subtitle:
                                                  look.resolvedStoreSubtitle,
                                            ),
                                          ),
                                        if (home.showCategories &&
                                            categories.isNotEmpty)
                                          SliverToBoxAdapter(
                                            child: _CategoryStrip(
                                              theme: theme,
                                              categories: categories,
                                              selectedId: _categoryId,
                                              onSelected: (String id) {
                                                setState(() {
                                                  _categoryId = id;
                                                  _promoOnly = false;
                                                });
                                              },
                                            ),
                                          ),
                                        if (showFeatured)
                                          SliverToBoxAdapter(
                                            child: _HomeSection(
                                              theme: theme,
                                              title: look.resolvedFeaturedTitle,
                                              actionLabel: '查看全部',
                                              actionColor: look
                                                  .primaryButtonColor(theme),
                                              onAction: () {
                                                setState(() {
                                                  _promoOnly = false;
                                                  _categoryId = '';
                                                });
                                              },
                                              child: StoreProductCarousel(
                                                products: featured,
                                                theme: theme,
                                                appearance: look,
                                                pricedOf: pricedOf,
                                                showStockToCustomer:
                                                    home.showStockToCustomer,
                                                onTap:
                                                    (
                                                      StoreProductModel product,
                                                    ) {
                                                      _openProduct(
                                                        product,
                                                        theme,
                                                      );
                                                    },
                                              ),
                                            ),
                                          ),
                                        if (showPromo)
                                          SliverToBoxAdapter(
                                            child: _HomeSection(
                                              theme: theme,
                                              title: look.resolvedPromoTitle,
                                              actionLabel: '查看全部優惠',
                                              actionColor: look
                                                  .primaryButtonColor(theme),
                                              onAction: () {
                                                setState(() {
                                                  _promoOnly = true;
                                                  _categoryId = '';
                                                });
                                              },
                                              child: Column(
                                                children: <Widget>[
                                                  if (activeBundles.isNotEmpty)
                                                    SizedBox(
                                                      height: 176,
                                                      child: ListView.separated(
                                                        scrollDirection:
                                                            Axis.horizontal,
                                                        padding:
                                                            const EdgeInsets.fromLTRB(
                                                              16,
                                                              0,
                                                              16,
                                                              8,
                                                            ),
                                                        itemCount: activeBundles
                                                            .length,
                                                        separatorBuilder:
                                                            (_, _) =>
                                                                const SizedBox(
                                                                  width: 10,
                                                                ),
                                                        itemBuilder:
                                                            (
                                                              BuildContext
                                                              context,
                                                              int index,
                                                            ) {
                                                              final StorePromotionModel
                                                              promo =
                                                                  activeBundles[index];
                                                              return SizedBox(
                                                                width: 240,
                                                                child: StoreBundleCard(
                                                                  promotion:
                                                                      promo,
                                                                  products:
                                                                      enabled,
                                                                  theme: theme,
                                                                  onTap: () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute<
                                                                        void
                                                                      >(
                                                                        builder: (_) => StoreBundleDetailPage(
                                                                          shopId:
                                                                              widget.shopId,
                                                                          shop:
                                                                              widget.shop,
                                                                          promotion:
                                                                              promo,
                                                                          theme:
                                                                              theme,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              );
                                                            },
                                                      ),
                                                    ),
                                                  if (promoProducts.isNotEmpty)
                                                    StoreProductCarousel(
                                                      products: promoProducts,
                                                      theme: theme,
                                                      appearance: look,
                                                      pricedOf: pricedOf,
                                                      showStockToCustomer: home
                                                          .showStockToCustomer,
                                                      onTap:
                                                          (
                                                            StoreProductModel
                                                            product,
                                                          ) {
                                                            _openProduct(
                                                              product,
                                                              theme,
                                                            );
                                                          },
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              12,
                                              8,
                                              8,
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(
                                                    _promoOnly
                                                        ? '全部優惠'
                                                        : (keyword.isEmpty
                                                              ? look.resolvedAllTitle
                                                              : '搜尋結果'),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: theme.textColor,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${catalog.length} 件商品',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.textColor
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  tooltip: '排序',
                                                  initialValue: _sort,
                                                  onSelected: (String value) {
                                                    setState(
                                                      () => _sort = value,
                                                    );
                                                  },
                                                  itemBuilder: (_) =>
                                                      const <
                                                        PopupMenuEntry<String>
                                                      >[
                                                        PopupMenuItem<String>(
                                                          value: 'recommended',
                                                          child: Text('推薦排序'),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'newest',
                                                          child: Text('最新上架'),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'priceLow',
                                                          child: Text('價格低到高'),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'priceHigh',
                                                          child: Text('價格高到低'),
                                                        ),
                                                      ],
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                    child: Row(
                                                      children: <Widget>[
                                                        Text(
                                                          _sortLabel(),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: theme
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.expand_more,
                                                          size: 18,
                                                          color: theme
                                                              .primaryColor,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (catalog.isNotEmpty)
                                          SliverToBoxAdapter(
                                            child: StoreProductGrid(
                                              products: catalog,
                                              theme: theme,
                                              appearance: look,
                                              pricedOf: pricedOf,
                                              showStockToCustomer:
                                                  home.showStockToCustomer,
                                              onTap:
                                                  (StoreProductModel product) {
                                                    _openProduct(
                                                      product,
                                                      theme,
                                                    );
                                                  },
                                            ),
                                          ),
                                        if (catalog.isEmpty)
                                          SliverToBoxAdapter(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    32,
                                                    16,
                                                    48,
                                                  ),
                                              child: Center(
                                                child: Text(
                                                  '目前沒有符合的商品',
                                                  style: TextStyle(
                                                    color: theme.textColor
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        const SliverToBoxAdapter(
                                          child: SizedBox(height: 28),
                                        ),
                                      ],
                                    );
                                  },
                            );
                          },
                    );
                  },
                ),
        );
      },
    );
  }

  void _onBannerTap(
    StoreBannerModel banner,
    HomeThemeModel theme,
    List<StoreProductModel> products,
    List<StorePromotionModel> promotions,
  ) {
    if (banner.actionType == StoreBannerActionTypes.product) {
      StoreProductModel? product;
      for (final StoreProductModel item in products) {
        if (item.id == banner.actionTargetId) {
          product = item;
          break;
        }
      }
      if (product != null && product.enabled) {
        _openProduct(product, theme);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('商品不存在或已下架')));
      }
      return;
    }
    if (banner.actionType == StoreBannerActionTypes.category) {
      setState(() {
        _categoryId = banner.actionTargetId;
        _promoOnly = false;
      });
      return;
    }
    if (banner.actionType == StoreBannerActionTypes.promotion ||
        banner.actionType == StoreBannerActionTypes.bundle) {
      StorePromotionModel? promo;
      for (final StorePromotionModel item in promotions) {
        if (item.id == banner.actionTargetId) {
          promo = item;
          break;
        }
      }
      if (promo != null &&
          (promo.isBundle ||
              banner.actionType == StoreBannerActionTypes.bundle)) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => StoreBundleDetailPage(
              shopId: widget.shopId,
              shop: widget.shop,
              promotion: promo!,
              theme: theme,
            ),
          ),
        );
        return;
      }
      if (banner.actionType == StoreBannerActionTypes.promotion) {
        setState(() {
          _promoOnly = true;
          _categoryId = '';
        });
      }
    }
  }
}

class _AnnouncementBar extends StatelessWidget {
  const _AnnouncementBar({required this.theme, required this.text});

  final HomeThemeModel theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('商城公告'),
                  content: Text(text),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                );
              },
            );
          },
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.campaign_outlined,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.textColor.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.theme,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final HomeThemeModel theme;
  final List<StoreCategoryModel> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        children: <Widget>[
          _chip('全部', '', Icons.apps_rounded),
          ...categories.map((StoreCategoryModel category) {
            return _chip(category.name, category.id, _iconFor(category.name));
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    final bool selected = selectedId == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? theme.primaryColor.withValues(alpha: 0.14)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(value),
          child: Container(
            width: 72,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? theme.primaryColor : theme.cardBorderColor,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: theme.primaryColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
    if (name.contains('罐頭')) {
      return Icons.inventory_2_outlined;
    }
    if (name.contains('零食')) {
      return Icons.restaurant_outlined;
    }
    if (name.contains('用品')) {
      return Icons.pets_outlined;
    }
    if (name.contains('玩具')) {
      return Icons.toys_outlined;
    }
    return Icons.category_outlined;
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.theme,
    required this.title,
    required this.child,
    this.actionLabel,
    this.actionColor,
    this.onAction,
  });

  final HomeThemeModel theme;
  final String title;
  final Widget child;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: actionColor ?? theme.primaryColor,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
