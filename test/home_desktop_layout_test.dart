import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_desktop_layout_setting.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_desktop_layout.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editorial_section_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_banner_carousel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_editor_overlay.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

void main() {
  test('desktop choices round trip with safe defaults and no shop content', () {
    for (final id in HomeDesktopLayoutSetting.labels.keys) {
      final current = HomeDesktopLayoutSetting(preset: id);
      expect(HomeDesktopLayoutSetting.fromMap(current.toMap()).preset, id);
      expect(current.toMap().keys, ['preset']);
      expect(current.bannerHeight, lessThanOrEqualTo(420));
      expect(current.columnsForWidth(876), lessThanOrEqualTo(3));
    }
    expect(HomeDesktopLayoutSetting.fromMap(null).preset, 'standard');
    expect(
      HomeDesktopLayoutSetting.fromMap({'preset': 'unknown'}).preset,
      'standard',
    );
  });
  for (final id in HomeDesktopLayoutSetting.labels.keys) {
    testWidgets('$id keeps desktop bounded and phone unchanged across widths', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final setting = HomeDesktopLayoutSetting(preset: id);
      for (final width in [430.0, 900.0, 1024.0, 1440.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 1100);
        await tester.pumpWidget(
          MaterialApp(
            home: HomeDesktopLayoutFrame(
              setting: setting,
              background: Colors.white,
              child: Builder(
                builder: (context) {
                  final desktop = HomeDesktopLayoutScope.maybeOf(context);
                  return Scaffold(
                    key: const Key('bounded-body'),
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            StoreBrandTopBar(
                              style: const StoreBrandStyle(
                                markType: 'wordmark',
                              ),
                              shopName: '自己的店家',
                              subtitle: '讓每一次出門 都有安心的後盾',
                              logoUrl: '',
                              theme: HomeThemeModel.modernDefault,
                              backgroundColor: Colors.white,
                              leading: IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.menu),
                              ),
                              actions: IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.notifications_outlined),
                              ),
                            ),
                            LayoutBuilder(
                              key: const Key('hero'),
                              builder: (context, c) => ModernHomeBannerCarousel(
                                banners: const [],
                                theme: HomeThemeModel.modernDefault,
                                frameSetting: const ModernBannerFrameSetting(
                                  widthPreset: HomeBannerWidthPreset.full,
                                  heightPreset: HomeBannerHeightPreset.short,
                                ),
                                frameAspectRatioOverride: desktop == null
                                    ? null
                                    : c.maxWidth / desktop.bannerHeight,
                              ),
                            ),
                            EnvironmentHighlightCards(
                              items: [
                                for (final name in [
                                  '舒適獨立空間',
                                  '每日清潔照護',
                                  '貼心生活陪伴',
                                ])
                                  {'title': name, 'description': '乾淨安全，放鬆自在'},
                              ],
                              theme: HomeThemeModel.modernDefault,
                              onOpen: () {},
                            ),
                            EditorialRoomStrip(
                              rooms: [
                                for (var i = 0; i < 4; i++)
                                  {
                                    'id': 'room$i',
                                    'name': '房型$i',
                                    'price': 800 + i * 100,
                                    'description': '溫潤木質，寬敞舒適',
                                    'customFeatures': [
                                      {'name': '獨立空間'},
                                      {'name': '高空跳台'},
                                      {'name': '大片採光'},
                                    ],
                                  },
                              ],
                              theme: HomeThemeModel.modernDefault,
                              title: '房型介紹',
                              onRoom: (_) {},
                              onAll: () {},
                            ),
                            EditorialAboutCard(
                              theme: HomeThemeModel.modernDefault,
                              sectionTitle: '關於我們',
                              title: '以貓咪為本的溫暖旅店',
                              body:
                                  '打造安全、舒適、充滿愛的住宿環境，讓每一位貓咪都能像在家一樣自在，也讓飼主出門更安心。',
                              photo: '',
                              button: '認識我們',
                              onOpen: () {},
                            ),
                            ModernShopInfoPanel(
                              alwaysExpanded: true,
                              footer: ModernShopFooter(
                                shopId: 'own-shop',
                                shop: const {
                                  'phone': '030000000',
                                  'address': '店家自己的地址',
                                  'businessHours': '10:00 - 20:00',
                                },
                                shopName: '自己的店家',
                                primaryColor: Colors.orange,
                                darkTextColor: Colors.brown,
                                secondaryTextColor: Colors.brown,
                                cardColor: Colors.white,
                                borderColor: Colors.orange,
                                setting: const HomeShopInfoSetting(
                                  layout: 'photoContact',
                                  imageSource: 'photo',
                                  showName: false,
                                  showIntro: false,
                                  actionIds: ['phone', 'map', 'line'],
                                  actionLayout: 'threeColumns',
                                  fields: ['hours', 'address'],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$id / $width');
        expect(
          tester.getSize(find.byKey(const Key('bounded-body'))).width,
          width < 900
              ? width
              : (width < setting.maxWidth ? width : setting.maxWidth),
        );
        if (width >= 900) {
          expect(
            tester.getSize(find.byKey(const Key('hero'))).height,
            closeTo(setting.bannerHeight, .01),
          );
        }
        expect(find.text('NT\$800／晚'), findsOneWidget);
      }
    });
  }
}
