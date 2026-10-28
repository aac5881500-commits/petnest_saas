import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_preview_policy.dart';

void main() {
  test('editors with live previews use a separate frontend preview', () {
    for (final page in ['ShopThemeSettingPage', 'ShopEnvironmentManagePage',
      'ShopAboutManagePage', 'ShopMediaPage', 'ShopBookingSetupCenterPage']) {
      expect(ShopFrontendPreviewPolicy.hasLivePreview(page), isTrue, reason: page);
    }
  });
  test('ordinary pages and dashboard keep side preview available', () {
    for (final page in <String?>[null, 'ShopBasicInfoPage', 'ShopBusinessInfoPage', 'AdminMemberListPage']) {
      expect(ShopFrontendPreviewPolicy.hasLivePreview(page), isFalse, reason: page);
    }
  });
}
