// 檔案名稱：lib/core/services/home_banner_service.dart
// 功能說明：首頁活動海報：存在 shops/{shopId}.banners[]，與商城 store_settings 分開。

import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class HomeBannerService {
  HomeBannerService._();

  static final HomeBannerService instance = HomeBannerService._();

  static const int maxCount = 5;
  static const String imageFolder = 'home/banners';
  static const String coverFallbackId = 'cover_fallback';

  List<StoreBannerModel> parseBanners(dynamic raw) {
    final List<StoreBannerModel> banners = <StoreBannerModel>[];
    if (raw is! List) {
      return banners;
    }
    for (int i = 0; i < raw.length; i++) {
      final Object? item = raw[i];
      if (item is! Map) {
        continue;
      }
      banners.add(fromShopMap(Map<dynamic, dynamic>.from(item), index: i));
    }
    banners.sort(
      (StoreBannerModel a, StoreBannerModel b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );
    return banners;
  }

  List<StoreBannerModel> parseEnabledFrontBanners(Map<String, dynamic> shop) {
    final List<StoreBannerModel> banners = <StoreBannerModel>[];
    final Object? rawBanners = shop['banners'];
    if (rawBanners is List) {
      for (int i = 0; i < rawBanners.length; i++) {
        final Object? item = rawBanners[i];
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        if (!_isEnabled(map)) {
          continue;
        }
        final StoreBannerModel banner = forFront(map, index: i);
        if (!banner.hasImage) {
          continue;
        }
        banners.add(banner);
      }
    }
    banners.sort(
      (StoreBannerModel a, StoreBannerModel b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );
    if (banners.isNotEmpty) {
      return banners;
    }
    final String coverUrl = (shop['coverUrl'] ?? '').toString().trim();
    if (coverUrl.isEmpty) {
      return banners;
    }
    return <StoreBannerModel>[
      StoreBannerModel(id: coverFallbackId, imageUrl: coverUrl, enabled: true),
    ];
  }

  StoreBannerModel fromShopMap(Map<dynamic, dynamic> raw, {int index = 0}) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String id = (map['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      map['id'] = 'home_$index';
    }
    if (map['sortOrder'] == null) {
      map['sortOrder'] = index;
    }
    return StoreBannerModel.fromMap(map);
  }

  StoreBannerModel forFront(Map<String, dynamic> raw, {int index = 0}) {
    final StoreBannerModel banner = fromShopMap(raw, index: index);
    if (banner.usesOwnOverlay) {
      return banner;
    }
    final String cropped = (raw['croppedImageUrl'] ?? '').toString().trim();
    if (cropped.isEmpty) {
      return banner;
    }
    return banner.copyWith(imageUrl: cropped);
  }

  Map<String, dynamic> toShopMap(StoreBannerModel banner) {
    final Map<String, dynamic> map = banner.toMap();
    map['isActive'] = banner.enabled;
    map['enabled'] = banner.enabled;
    return map;
  }

  Future<void> saveBanners({
    required String shopId,
    required List<StoreBannerModel> banners,
  }) async {
    final List<StoreBannerModel> next = banners.take(maxCount).toList();
    for (int i = 0; i < next.length; i++) {
      next[i] = next[i].copyWith(sortOrder: i);
    }
    await ShopService.instance.updateShop(
      shopId: shopId,
      data: <String, dynamic>{'banners': next.map(toShopMap).toList()},
    );
  }

  Future<void> deleteBannerImage({
    required String shopId,
    required String imageUrl,
    required String imageStoragePath,
  }) async {
    final bool oldFlatFile = _isLegacyFlatBannerPath(
      shopId: shopId,
      path: imageStoragePath,
    );
    if (oldFlatFile || imageStoragePath.trim().isEmpty) {
      await ShopService.instance.tryDeleteShopBannerImage(
        shopId: shopId,
        imageStoragePath: imageStoragePath,
        imageUrl: imageUrl,
      );
      return;
    }
    await InventoryImageService.instance.tryDeleteImage(
      imageUrl: imageUrl,
      imageStoragePath: imageStoragePath,
    );
  }

  HomeThemeModel themeFromShop(Map<String, dynamic>? shop) {
    final Object? rawAppearance = shop?['homeAppearance'];
    if (rawAppearance is! Map) {
      return HomeThemeModel.modernDefault;
    }
    final Map<String, dynamic> appearance = Map<String, dynamic>.from(
      rawAppearance,
    );
    final String layout = (appearance['layout'] ?? 'modern').toString();
    if (layout == 'classic') {
      return HomeThemeModel.fromClassicSettings(
        rawData: appearance['classic'] ?? appearance,
      );
    }
    final Object? rawModern = appearance['modern'];
    if (rawModern is Map) {
      return HomeThemeModel.fromMap(
        rawModern['themeColors'],
        fallback: HomeThemeModel.modernDefault,
      );
    }
    return HomeThemeModel.modernDefault;
  }

  bool _isEnabled(Map<String, dynamic> map) {
    if (map['enabled'] is bool) {
      return map['enabled'] == true;
    }
    return map['isActive'] != false;
  }

  bool _isLegacyFlatBannerPath({required String shopId, required String path}) {
    final String normalized = path.trim();
    final String prefix = 'shops/${shopId.trim()}/';
    if (!normalized.startsWith(prefix)) {
      return false;
    }
    final String fileName = normalized.substring(prefix.length);
    return fileName.startsWith('banner_') && !fileName.contains('/');
  }
}
