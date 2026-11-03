import 'modern_store_home_setting.dart';

/// Bundled demo art; shop uploads always take precedence when applying layouts.
class StoreEntryBuiltinImages {
  static const assets = {
    'goods': 'assets/images/store_entry_goods_v1.png',
    'feather': 'assets/images/store_entry_feather_v1.png',
    'cat': 'assets/images/store_entry_cat_v1.png',
    'shop': 'assets/images/store_entry_shop_v1.png',
  };
  static String url(String id) => 'builtin-store:$id';
  static String? asset(String url) =>
      url.startsWith('builtin-store:') ? assets[url.substring(14)] : null;
  static String primary(String layout) => switch (layout) {
    ModernStoreEntryLayouts.photoBanner => url('cat'),
    ModernStoreEntryLayouts.boutique => url('shop'),
    ModernStoreEntryLayouts.ticket || ModernStoreEntryLayouts.capsule => '',
    _ => url('goods'),
  };
}
