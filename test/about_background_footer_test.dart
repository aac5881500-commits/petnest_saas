// 功能：關於我們獨立背景與重用底部資訊範本的草稿／呈現相容驗證。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_appearance_editor.dart';

void main() {
  test('分區底色與底部範本讀回、清除及舊資料相容', () {
    final old = AboutPageSetting();
    expect(old.sectionBackground('stories'), isNull);
    expect(old.contactLayout, 'list');
    final setting = old
        .withSectionBackground('stories', const Color(0xffddeeff))
        .withAppearance({
          'backgroundSource': 'color',
          'backgroundColor': 0xfff7f0e0,
          'contactLayout': 'footer',
          'contactFooter': shopInfoPresets[2]
              .apply(const HomeShopInfoSetting())
              .toMap(),
        });
    final read = AboutPageSetting.fromMap(setting.toMap());
    expect(read.sectionBackground('stories'), const Color(0xffddeeff));
    expect(read.contactFooter.preset, shopInfoPresets[2].id);
    expect(read.contactLayout, 'footer');
    expect(
      read.withSectionBackground('stories', null).sectionBackground('stories'),
      isNull,
    );
    expect(
      read
          .withSectionBackground('stories', null)
          .color('backgroundColor', Colors.white),
      const Color(0xfff7f0e0),
    );
    expect(
      AboutPageSetting.fromMap({
        'appearance': {
          'sectionBackgrounds': {'stories': 'bad'},
        },
      }).sectionBackground('stories'),
      isNull,
    );
  });
  for (final width in [390.0, 1200.0]) {
    testWidgets('十款底部快速排版在 $width 預覽與正式一致、不溢出', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final preset in shopInfoPresets) {
        final setting = AboutPageSetting()
            .withAppearance({
              'contactLayout': 'footer',
              'contactFooter': preset
                  .apply(const HomeShopInfoSetting())
                  .toMap(),
            })
            .withSectionBackground('contact', const Color(0xffddeeff));
        for (final preview in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AboutIntroView(
                  shop: const {
                    'name': '本店',
                    'phone': '0900000000',
                    'address': '本店地址',
                    'businessHours': '10:00–18:00',
                  },
                  setting: setting,
                  theme: HomeThemeModel.classicDefault,
                  preview: preview,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('本店'), findsWidgets);
          expect(
            tester
                .widget<Container>(
                  find.byKey(
                    const ValueKey('about-section-background-contact'),
                  ),
                )
                .color,
            const Color(0xffddeeff),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${preset.id} preview=$preview',
          );
        }
      }
    });
  }
  testWidgets('點選底部快速樣式只更新本頁草稿', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AboutPageSetting setting = AboutPageSetting();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AboutAppearanceEditor(
              section: 'contact',
              setting: setting,
              theme: HomeThemeModel.classicDefault,
              onChanged: (value) => setting = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(shopInfoPresets.first.label));
    expect(setting.contactLayout, 'footer');
    expect(setting.contactFooter.preset, shopInfoPresets.first.id);
    expect(setting.toMap().containsKey('modern'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
