/// Editors that already own a live preview must retain the full workspace width.
abstract final class ShopFrontendPreviewPolicy {
  static const livePreviewDestinations = <String>{
    'ShopThemeSettingPage',
    'ShopEnvironmentManagePage',
    'ShopAboutManagePage',
    'ShopMediaPage',
    'ShopBookingSetupCenterPage',
  };
  static bool hasLivePreview(String? destination) =>
      livePreviewDestinations.contains(destination);
}
