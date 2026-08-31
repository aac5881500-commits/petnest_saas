import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';

void main() {
  test('商城名稱以 storeName 為準，storeTitle 只當舊資料 fallback', () {
    final StoreHomeDisplaySettings named = StoreHomeDisplaySettings.fromMap(
      const <String, dynamic>{
        'storeName': 'PetNest 寵物商城',
        'storeAppearance': <String, dynamic>{'storeTitle': '舊賣場標題'},
      },
    );
    expect(named.resolvedStorefrontTitle, 'PetNest 寵物商城');
    final StoreHomeDisplaySettings legacy = StoreHomeDisplaySettings.fromMap(
      const <String, dynamic>{
        'storeAppearance': <String, dynamic>{
          'storeTitle': '舊賣場標題',
          'storeSubtitle': '舊副標',
        },
      },
    );
    expect(legacy.resolvedStorefrontTitle, '舊賣場標題');
    expect(legacy.resolvedStorefrontSubtitle, '舊副標');
    final StoreHomeDisplaySettings fromDesc = StoreHomeDisplaySettings.fromMap(
      const <String, dynamic>{'storeDescription': '安心選購毛孩用品'},
    );
    expect(fromDesc.resolvedStorefrontSubtitle, '安心選購毛孩用品');
  });

  test('舊店家沒有 storeAppearance → 維持預設', () {
    final StoreHomeDisplaySettings home = StoreHomeDisplaySettings.fromMap(
      const <String, dynamic>{},
    );
    expect(home.storeAppearance.cardBackgroundMode, StoreCardBackgroundModes.solid);
    expect(home.storeAppearance.usesCardImage, isFalse);
    expect(home.storeAppearance.resolvedStoreTitle, '寵物賣場');
    expect(home.storeAppearance.resolvedFeaturedTitle, '精選商品');
    final HomeThemeModel theme = home.resolveTheme(HomeThemeModel.modernDefault);
    expect(theme.backgroundColorValue, HomeThemeModel.modernDefault.backgroundColorValue);
  });

  test('overlay 原圖 / 淡 / 很淡', () {
    expect(StoreCardOverlays.opacity(StoreCardOverlays.original), 0.18);
    expect(StoreCardOverlays.opacity(StoreCardOverlays.light), 0.35);
    expect(StoreCardOverlays.opacity(StoreCardOverlays.veryLight), 0.50);
  });

  test('深色按鈕自動用淺色字', () {
    expect(
      StoreAppearanceSetting.onColor(const Color(0xFF4A4A4A)),
      const Color(0xFFFFFFFF),
    );
    expect(
      StoreAppearanceSetting.onColor(const Color(0xFFFFF6EC)),
      const Color(0xFF2A221C),
    );
  });

  test('白色卡片文字時 overlay 用深色', () {
    const StoreAppearanceSetting look = StoreAppearanceSetting(
      cardTextPreset: StoreCardTextPresets.white,
    );
    expect(
      look.overlayColor(HomeThemeModel.modernDefault),
      const Color(0xFF1A1410),
    );
  });

  test('banner 自動輪播預設 5 秒', () {
    final StoreHomeDisplaySettings home = StoreHomeDisplaySettings.fromMap(
      const <String, dynamic>{},
    );
    expect(home.bannerAutoPlay, isTrue);
    expect(home.bannerAutoPlaySeconds, 5);
    final StoreHomeDisplaySettings parsed = StoreHomeDisplaySettings.fromMap(
      const <String, dynamic>{
        'bannerAutoPlay': false,
        'bannerAutoPlaySeconds': 8,
      },
    );
    expect(parsed.bannerAutoPlay, isFalse);
    expect(parsed.bannerAutoPlaySeconds, 8);
  });

  test('parse storeAppearance 圖卡設定', () {
    final StoreAppearanceSetting look = StoreAppearanceSetting.fromMap(
      <String, dynamic>{
        'cardBackgroundMode': 'image',
        'cardBackgroundImageUrl': 'https://example.com/bg.jpg',
        'cardBackgroundFit': 'contain',
        'storeTitle': '毛孩選物',
      },
    );
    expect(look.usesCardImage, isTrue);
    expect(look.cardBoxFit, BoxFit.contain);
    expect(look.resolvedStoreTitle, '毛孩選物');
  });
}
