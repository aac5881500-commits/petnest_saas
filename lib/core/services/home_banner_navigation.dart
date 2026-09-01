// lib/core/services/home_banner_navigation.dart
// 首頁海報點擊：沿用現有前台頁面，不另開 routing。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_review_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_product_detail_page.dart';

class HomeBannerNavigation {
  HomeBannerNavigation._();

  static bool isSafeHttpUrl(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static Future<void> open({
    required BuildContext context,
    required String shopId,
    required Map<String, dynamic> shop,
    required HomeThemeModel theme,
    required StoreBannerModel banner,
    bool useModernDrawer = false,
  }) async {
    if (banner.id == HomeBannerService.coverFallbackId) {
      return;
    }
    switch (banner.actionType) {
      case HomeBannerActionTypes.none:
        return;
      case HomeBannerActionTypes.booking:
        await _openBooking(
          context: context,
          shopId: shopId,
          theme: theme,
          useModernDrawer: useModernDrawer,
        );
        return;
      case HomeBannerActionTypes.rooms:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopRoomIntroPage(shopId: shopId, theme: theme),
          ),
        );
        return;
      case HomeBannerActionTypes.policy:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopPolicyViewPage(
              shopId: shopId,
              theme: theme,
              readOnly: true,
            ),
          ),
        );
        return;
      case HomeBannerActionTypes.about:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopAboutPage(shopId: shopId, theme: theme),
          ),
        );
        return;
      case HomeBannerActionTypes.reviews:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopReviewListPage(shopId: shopId, theme: theme),
          ),
        );
        return;
      case HomeBannerActionTypes.faq:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopFaqPage(shopId: shopId, theme: theme),
          ),
        );
        return;
      case HomeBannerActionTypes.store:
        await _openStore(
          context: context,
          shopId: shopId,
          shop: shop,
          theme: theme,
        );
        return;
      case HomeBannerActionTypes.product:
        await _openProduct(
          context: context,
          shopId: shopId,
          shop: shop,
          theme: theme,
          productId: banner.actionTargetId,
        );
        return;
      case HomeBannerActionTypes.url:
        return;
      default:
        return;
    }
  }

  static Future<void> _openBooking({
    required BuildContext context,
    required String shopId,
    required HomeThemeModel theme,
    required bool useModernDrawer,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopBookingEntryPage(
          shopId: shopId,
          theme: theme,
          useModernDrawer: useModernDrawer,
        ),
      ),
    );
  }

  static Future<void> _openStore({
    required BuildContext context,
    required String shopId,
    required Map<String, dynamic> shop,
    required HomeThemeModel theme,
  }) async {
    if (!StorefrontAccess.isModuleEnabled(shop)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('寵物賣場尚未開放')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreHomePage(shopId: shopId, shop: shop, theme: theme),
      ),
    );
  }

  static Future<void> _openProduct({
    required BuildContext context,
    required String shopId,
    required Map<String, dynamic> shop,
    required HomeThemeModel theme,
    required String productId,
  }) async {
    if (productId.trim().isEmpty) {
      return;
    }
    if (!StorefrontAccess.isModuleEnabled(shop)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('寵物賣場尚未開放')));
      return;
    }
    final StoreProductModel? product = await StoreProductService.instance
        .getProduct(shopId: shopId, productId: productId);
    if (!context.mounted) {
      return;
    }
    if (product == null || !product.enabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商品不存在或已下架')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreProductDetailPage(
          shopId: shopId,
          shop: shop,
          productId: productId.trim(),
          theme: theme,
        ),
      ),
    );
  }
}
