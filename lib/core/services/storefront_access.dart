// 檔案名稱：lib/core/services/storefront_access.dart
// 功能說明：集中判斷 ShopModules.store 與賣場設定，頁面不散落 plan 判斷。
// 🛒 賣場前台開關

import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class StorefrontAccess {
  StorefrontAccess._();

  static bool isModuleEnabled(Map<String, dynamic>? shop) {
    return ShopService.instance.isModuleEnabled(shop, ShopModules.store);
  }

  static bool isStorefrontEnabled(Map<String, dynamic>? settings) {
    return settings == null || settings['storefrontEnabled'] != false;
  }

  static bool isStorefrontOpen({
    required Map<String, dynamic>? shop,
    Map<String, dynamic>? settings,
  }) {
    return isModuleEnabled(shop) && isStorefrontEnabled(settings);
  }
}
