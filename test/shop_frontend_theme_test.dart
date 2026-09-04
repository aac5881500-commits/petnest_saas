import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

void main() {
  group('HomeThemeModel.parseColorValue', () {
    test('int、hex、#、無效值與空值', () {
      expect(HomeThemeModel.parseColorValue(0xFF112233, 0), 0xFF112233);
      expect(HomeThemeModel.parseColorValue(0x112233, 0), 0xFF112233);
      expect(HomeThemeModel.parseColorValue('#AABBCC', 0), 0xFFAABBCC);
      expect(HomeThemeModel.parseColorValue('AABBCC', 0), 0xFFAABBCC);
      expect(HomeThemeModel.parseColorValue('#80AABBCC', 0), 0x80AABBCC);
      expect(HomeThemeModel.parseColorValue('#ABC', 0), 0xFFAABBCC);
      expect(HomeThemeModel.parseColorValue(null, 0xFF111111), 0xFF111111);
      expect(HomeThemeModel.parseColorValue('', 0xFF111111), 0xFF111111);
      expect(
        HomeThemeModel.parseColorValue('not-a-color', 0xFF111111),
        0xFF111111,
      );
    });
  });

  group('ShopFrontendTheme', () {
    test('缺少外觀使用 modernDefault', () {
      final ShopFrontendTheme theme = ShopFrontendTheme.fromShop(null);
      expect(theme.primaryColor, HomeThemeModel.modernDefault.primaryColor);
      expect(
        theme.pageBackgroundColor,
        HomeThemeModel.modernDefault.backgroundColor,
      );
    });

    test('無效 themeColors 不崩潰並 fallback', () {
      final ShopFrontendTheme theme = ShopFrontendTheme.fromShop(
        <String, dynamic>{
          'homeAppearance': <String, dynamic>{
            'layout': 'modern',
            'modern': <String, dynamic>{
              'themeColors': <String, dynamic>{'primaryColor': 'zzzz'},
            },
          },
        },
      );
      expect(theme.primaryColor, HomeThemeModel.modernDefault.primaryColor);
    });

    test('淺黃主色按鈕文字為深色', () {
      final ShopFrontendTheme theme = ShopFrontendTheme.fromHome(
        const HomeThemeModel(
          backgroundColorValue: 0xFFFFFBF7,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFFFD9B3,
          primaryColorValue: 0xFFFFF3A0,
          textColorValue: 0xFF3A2A20,
        ),
      );
      expect(
        ThemeData.estimateBrightnessForColor(theme.primaryColor),
        Brightness.light,
      );
      expect(theme.onPrimaryColor, const Color(0xFF3A2A20));
    });

    test('深色主色按鈕文字為白色', () {
      final ShopFrontendTheme theme = ShopFrontendTheme.fromHome(
        const HomeThemeModel(
          backgroundColorValue: 0xFFFFFBF7,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFFFD9B3,
          primaryColorValue: 0xFF1B4F8A,
          textColorValue: 0xFF3A2A20,
        ),
      );
      expect(
        ThemeData.estimateBrightnessForColor(theme.primaryColor),
        Brightness.dark,
      );
      expect(theme.onPrimaryColor, Colors.white);
    });

    test('切換 shop map 後不沿用上一間主色', () {
      final ShopFrontendTheme blue = ShopFrontendTheme.fromShop(
        <String, dynamic>{
          'homeAppearance': <String, dynamic>{
            'layout': 'modern',
            'modern': <String, dynamic>{
              'themeColors': HomeThemeModel.modernDefault
                  .copyWith(primaryColorValue: 0xFF1B4F8A)
                  .toMap(),
            },
          },
        },
      );
      final ShopFrontendTheme green = ShopFrontendTheme.fromShop(
        <String, dynamic>{
          'homeAppearance': <String, dynamic>{
            'layout': 'modern',
            'modern': <String, dynamic>{
              'themeColors': HomeThemeModel.modernDefault
                  .copyWith(primaryColorValue: 0xFF2E7D4F)
                  .toMap(),
            },
          },
        },
      );
      expect(blue.primaryColor, const Color(0xFF1B4F8A));
      expect(green.primaryColor, const Color(0xFF2E7D4F));
      expect(blue.buttonColor, blue.primaryColor);
      expect(green.buttonColor, green.primaryColor);
    });

    test('語意色不跟隨主色', () {
      final ShopFrontendTheme theme = ShopFrontendTheme.fromHome(
        const HomeThemeModel(
          backgroundColorValue: 0xFFFFFBF7,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFFFD9B3,
          primaryColorValue: 0xFF1B4F8A,
          textColorValue: 0xFF3A2A20,
        ),
      );
      expect(theme.success, ShopFrontendTheme.successColor);
      expect(theme.danger, ShopFrontendTheme.errorColor);
    });
  });
}
