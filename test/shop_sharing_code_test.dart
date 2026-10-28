import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_sharing_service.dart';

void main() {
  test(
    'custom search codes normalize and platform sequential codes are rejected',
    () {
      expect(ShopSharingService.parse(' cat_home_2026 '), 'CAT_HOME_2026');
      for (final value in [
        'SHOP0018',
        'shop123456789',
        'short',
        'cat home 2026',
        '',
      ]) {
        expect(ShopSharingService.parse(value), isNull);
      }
    },
  );
  test('QR URLs and raw tokens preserve case and accept the same payload', () {
    final token = List.filled(48, 'a').join();
    expect(ShopSharingService.parse(token), token);
    expect(ShopSharingService.parse('https://petnest.tw/s/$token'), token);
    expect(ShopSharingService.parse('https://petnest.tw/s/SHOP0018'), isNull);
    expect(ShopSharingService.parse('https://petnest.tw/other/$token'), isNull);
  });
}
