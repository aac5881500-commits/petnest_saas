// 檔案名稱：test/home_banner_service_test.dart
// 功能說明：首頁橫幅服務的單元測試（前台只顯示 enabled / isActive 海報並依 sortOrder）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/home_banner_navigation.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';

void main() {
  test('前台只顯示 enabled / isActive 海報並依 sortOrder', () {
    final List<StoreBannerModel> banners = HomeBannerService.instance
        .parseEnabledFrontBanners(<String, dynamic>{
          'banners': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'a',
              'imageUrl': 'https://a.jpg',
              'isActive': false,
              'sortOrder': 0,
            },
            <String, dynamic>{
              'id': 'b',
              'imageUrl': 'https://b.jpg',
              'enabled': true,
              'sortOrder': 2,
            },
            <String, dynamic>{
              'id': 'c',
              'imageUrl': 'https://c.jpg',
              'isActive': true,
              'sortOrder': 1,
            },
          ],
        });
    expect(banners.map((StoreBannerModel item) => item.id).toList(), <String>[
      'c',
      'b',
    ]);
  });

  test('沒有活動海報時才用 coverUrl 後備', () {
    final List<StoreBannerModel> banners = HomeBannerService.instance
        .parseEnabledFrontBanners(<String, dynamic>{
          'coverUrl': 'https://cover.jpg',
          'banners': <Map<String, dynamic>>[
            <String, dynamic>{'imageUrl': 'https://a.jpg', 'isActive': false},
          ],
        });
    expect(banners.length, 1);
    expect(banners.first.id, HomeBannerService.coverFallbackId);
    expect(banners.first.imageUrl, 'https://cover.jpg');
  });

  test('外部網址只允許 http / https', () {
    expect(HomeBannerNavigation.isSafeHttpUrl('https://example.com/a'), isTrue);
    expect(HomeBannerNavigation.isSafeHttpUrl('http://example.com'), isTrue);
    expect(HomeBannerNavigation.isSafeHttpUrl('javascript:alert(1)'), isFalse);
    expect(HomeBannerNavigation.isSafeHttpUrl('not-a-url'), isFalse);
  });
}
