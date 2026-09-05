// 檔案名稱：lib/core/services/store_settings_service.dart
// 功能說明：賣場設定

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';

class StoreSettingsService {
  StoreSettingsService._();

  static final StoreSettingsService instance = StoreSettingsService._();

  DocumentReference<Map<String, dynamic>> settingsRef(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.settingsCollection)
        .doc(StoreConstants.settingsDocId);
  }

  Stream<Map<String, dynamic>> streamSettings(String shopId) {
    return settingsRef(shopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      return snapshot.data() ?? <String, dynamic>{};
    });
  }

  Future<void> saveSettings({
    required String shopId,
    required String pickupNote,
    required bool storefrontEnabled,
    String storeName = '',
    String storeDescription = '',
    bool showFeaturedProducts = true,
    bool showLatestProducts = false,
    bool showPromoProducts = true,
    int featuredCount = 6,
    bool hideOutOfStock = false,
    bool showStockToCustomer = true,
    bool acceptNewOrders = true,
    String orderNote = '',
    String cancelRuleNote = '',
    String announcement = '',
    bool showAnnouncement = true,
    bool showBanners = true,
    bool showCategories = true,
    String appearancePreset = 'system',
    List<Map<String, dynamic>> banners = const <Map<String, dynamic>>[],
    bool bannerAutoPlay = true,
    int bannerAutoPlaySeconds = 5,
  }) async {
    final int safeCount = featuredCount == 4 || featuredCount == 8
        ? featuredCount
        : 6;
    await settingsRef(shopId).set(<String, dynamic>{
      'shopId': shopId.trim(),
      'pickupNote': pickupNote.trim(),
      'storefrontEnabled': storefrontEnabled,
      'storeName': storeName.trim(),
      'storeDescription': storeDescription.trim(),
      'showFeaturedProducts': showFeaturedProducts,
      'showLatestProducts': showLatestProducts,
      'showPromoProducts': showPromoProducts,
      'featuredCount': safeCount,
      'hideOutOfStock': hideOutOfStock,
      'showStockToCustomer': showStockToCustomer,
      'acceptNewOrders': acceptNewOrders,
      'orderNote': orderNote.trim(),
      'cancelRuleNote': cancelRuleNote.trim(),
      'announcement': announcement.trim(),
      'showAnnouncement': showAnnouncement,
      'showBanners': showBanners,
      'showCategories': showCategories,
      'appearancePreset': appearancePreset.trim().isEmpty
          ? 'system'
          : appearancePreset.trim(),
      'banners': banners.take(5).toList(),
      'bannerAutoPlay': bannerAutoPlay,
      'bannerAutoPlaySeconds':
          bannerAutoPlaySeconds == 3 || bannerAutoPlaySeconds == 8
          ? bannerAutoPlaySeconds
          : 5,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveBanners({
    required String shopId,
    required List<StoreBannerModel> banners,
    bool? bannerAutoPlay,
    int? bannerAutoPlaySeconds,
    bool? showBanners,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'shopId': shopId.trim(),
      'banners': banners.take(5).map((StoreBannerModel item) {
        return item.toMap();
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (showBanners != null) {
      data['showBanners'] = showBanners;
    }
    if (bannerAutoPlay != null) {
      data['bannerAutoPlay'] = bannerAutoPlay;
    }
    if (bannerAutoPlaySeconds != null) {
      data['bannerAutoPlaySeconds'] =
          bannerAutoPlaySeconds == 3 || bannerAutoPlaySeconds == 8
          ? bannerAutoPlaySeconds
          : 5;
    }
    await settingsRef(shopId).set(data, SetOptions(merge: true));
  }

  Future<void> mergeSettings({
    required String shopId,
    required Map<String, dynamic> data,
  }) async {
    await settingsRef(shopId).set(<String, dynamic>{
      'shopId': shopId.trim(),
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveStoreAppearance({
    required String shopId,
    required Map<String, dynamic> storeAppearance,
  }) async {
    await settingsRef(shopId).set(<String, dynamic>{
      'shopId': shopId.trim(),
      'storeAppearance': storeAppearance,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
