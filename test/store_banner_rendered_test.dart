// 檔案名稱：test/store_banner_rendered_test.dart
// 功能說明：成品圖欄位解析；舊海報沒有 renderedImageUrl 仍可用

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';

void main() {
  test('舊海報沒有成品圖', () {
    final StoreBannerModel banner = StoreBannerModel.fromMap(
      const <String, dynamic>{
        'id': 'b1',
        'imageUrl': 'https://example.com/a.jpg',
      },
    );
    expect(banner.hasRenderedImage, isFalse);
    expect(banner.hasImage, isTrue);
  });

  test('新海報成品圖欄位', () {
    final StoreBannerModel banner = StoreBannerModel.fromMap(
      const <String, dynamic>{
        'id': 'b2',
        'imageUrl': 'https://example.com/a.jpg',
        'renderedImageUrl': 'https://example.com/r.jpg',
        'renderedImageStoragePath': 'shops/s/home/banners/b2/rendered_v1.jpg',
        'renderVersion': 1,
      },
    );
    expect(banner.hasRenderedImage, isTrue);
    expect(banner.renderedImageUrl, 'https://example.com/r.jpg');
    expect(banner.toMap()['renderedImageUrl'], 'https://example.com/r.jpg');
  });
}
