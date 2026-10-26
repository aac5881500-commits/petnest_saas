import 'package:petnest_saas/core/models/modern_store_home_setting.dart';

/// 外觀頁只覆寫自己調整過的入口顯示與版型，保留商城頁的新文案和圖片。
ModernStoreHomeSetting mergeStoreHomeDisplayDraft({
  required ModernStoreHomeSetting latest,
  required ModernStoreHomeSetting loaded,
  required ModernStoreHomeSetting draft,
}) => latest.copyWith(
  showStoreBanner: draft.showStoreBanner == loaded.showStoreBanner
      ? null
      : draft.showStoreBanner,
  featuredProductLayout:
      draft.featuredProductLayout == loaded.featuredProductLayout
      ? null
      : draft.featuredProductLayout,
  storeEntryLayout: draft.storeEntryLayout == loaded.storeEntryLayout
      ? null
      : draft.storeEntryLayout,
);
