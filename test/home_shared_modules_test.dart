import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_flow.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editorial_section_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_environment_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';

void main() {
  const theme = HomeThemeModel.modernDefault;
  testWidgets(
    'ordinary underline navigation fits mobile and dispatches selected item',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 430,
                child: ModernBottomNavigation(
                  slots: [
                    for (final id in [
                      'booking',
                      'rooms',
                      'home',
                      'orders',
                      'member',
                    ])
                      FrontendNavigationRegistry.find(id),
                  ],
                  theme: theme,
                  selectedId: 'home',
                  appearance: FrontendNavigationConfig.appearanceUnderline,
                  surface: FrontendNavigationConfig.surfaceOpaque,
                  onSelect: (item) => selected = item.id,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('bottom-nav-underline-home')),
        findsOneWidget,
      );
      await tester.tap(find.text('房型'));
      expect(selected, 'rooms');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'empty asynchronous sections collapse their gap until content arrives',
    (tester) async {
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: buildHomeSectionRows(
                sectionIds: const ['banners', 'facilities', 'rooms'],
                spanOf: (_) => HomeSectionSpan.full,
                itemBuilder: (id) => id == 'facilities'
                    ? ValueListenableBuilder<bool>(
                        valueListenable: ready,
                        builder: (_, value, _) =>
                            SizedBox(height: value ? 30 : 0),
                      )
                    : SizedBox(
                        key: ValueKey(id),
                        height: id == 'banners' ? 64 : 28,
                      ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getTopLeft(find.byKey(const ValueKey('rooms'))).dy, 74);
      ready.value = true;
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('rooms'))).dy, 114);
      expect(tester.takeException(), isNull);
    },
  );
  test('catalog dimensions and carousel controls survive reopening', () {
    final room = const HomeRoomSectionSetting(layout: 'catalog').copyWith(
      compact: const HomeRoomCompactSetting(
        columns: 3,
        imageHeight: HomeRoomImageHeights.tall,
      ),
    );
    final reopened = HomeRoomSectionSetting.fromMap(room.toMap());
    expect(reopened.compact.columns, 3);
    expect(reopened.compact.imageHeight, HomeRoomImageHeights.tall);
    final banner = const ModernBannerFrameSetting(
      dotsOverlay: true,
      showArrows: false,
      showCounter: false,
    );
    final restored = ModernBannerFrameSetting.fromMap(banner.toMap());
    expect(restored, banner);
    expect(restored.showDots, true);
    for (final count in [1, 2, 3]) {
      final env = HomeEnvironmentSectionSetting.fromMap(
        HomeEnvironmentSectionSetting(
          layout: 'featureCards',
          facilityLimit: count,
        ).toMap(),
      );
      expect(env.facilityLimit, count);
    }
  });
  testWidgets('about image visibility and top position remain editable', (
    tester,
  ) async {
    Future<void> show(bool visible, bool top) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EditorialAboutCard(
              theme: theme,
              sectionTitle: '關於我們',
              title: '另一店',
              body: '自己的介紹',
              photo: '',
              button: '認識我們',
              onOpen: () {},
              showImage: visible,
              imageTop: top,
            ),
          ),
        ),
      ),
    );
    await show(false, false);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    await show(true, true);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'new choices survive existing module serialization without owner content',
    () {
      expect(
        HomeRoomSectionSetting.fromMap(const {'layout': 'catalog'}).layout,
        'catalog',
      );
      expect(
        HomeAboutSectionSetting.fromMap(const {'layout': 'editorial'}).layout,
        'editorial',
      );
      expect(
        HomeEnvironmentSectionSetting.fromMap(const {
          'layout': 'featureCards',
        }).layout,
        'featureCards',
      );
      final footer = HomeShopInfoSetting.fromMap(const {
        'layout': 'photoContact',
        'actionIds': ['line', 'phone', 'invalid'],
        'actionLayout': 'threeColumns',
        'phoneLabel': '聯絡店家',
        'photoFraction': 9,
      });
      final roundtrip = HomeShopInfoSetting.fromMap(footer.toMap());
      expect(roundtrip.actionIds, ['line', 'phone']);
      expect(roundtrip.phoneLabel, '聯絡店家');
      expect(roundtrip.photoFraction, .5);
      expect(roundtrip.imageUrl, isEmpty);
      expect(HomeShopInfoSetting.fromMap(null).layout, 'stacked');
    },
  );
  testWidgets('environment home cards read the environment module and update', (
    tester,
  ) async {
    var opened = false;
    Future<void> show(String title) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModernHomeEnvironmentSection(
            theme: theme,
            setting: const HomeEnvironmentSectionSetting(
              layout: 'featureCards',
              facilityLimit: 3,
              showTitle: false,
            ),
            environmentIntro: {
              'features': [
                {'title': title, 'description': '環境管理的說明', 'icon': 'heart'},
              ],
            },
            facilityKeys: const [],
            preview: false,
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    await show('原特色');
    await tester.pumpAndSettle();
    expect(find.text('原特色'), findsOneWidget);
    await tester.tap(find.text('原特色'));
    expect(opened, true);
    await show('環境頁修改後');
    await tester.pumpAndSettle();
    expect(find.text('原特色'), findsNothing);
    expect(find.text('環境頁修改後'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [375.0, 430.0, 841.0]) {
    testWidgets(
      'shared contact and catalog modules fit $width and use actual data',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    EditorialRoomStrip(
                      rooms: const [
                        {
                          'id': 'other-shop-room',
                          'name': '自訂房型',
                          'price': 1760,
                          'features': [],
                          'customFeatures': [
                            {'name': '獨立空間'},
                            {'name': '高空跳台'},
                            {'name': '大片採光'},
                          ],
                          'description': '溫潤木質，寬敞舒適',
                        },
                      ],
                      theme: theme,
                      title: '房型',
                      onRoom: (r) => opened = r,
                      onAll: () {},
                    ),
                    Builder(
                      builder: (context) => ModernShopFooter(
                        shopId: 'unrelated-shop',
                        shop: const {
                          'phone': '030000000',
                          'city': '臺南市',
                          'address': '另一店地址',
                          'businessHours': '10:00 - 20:00',
                        },
                        shopName: '另一店',
                        primaryColor: theme.primaryColor,
                        darkTextColor: theme.textColor,
                        secondaryTextColor: theme.secondaryTextColor,
                        cardColor: theme.cardColor,
                        borderColor: theme.cardBorderColor,
                        setting: const HomeShopInfoSetting(
                          layout: 'photoContact',
                          imageSource: 'none',
                          showName: false,
                          actionIds: ['phone', 'map', 'line'],
                          actionLayout: 'threeColumns',
                          buttonStyle: 'mixed',
                          fields: ['hours', 'address'],
                        ),
                      ).buildInfoBody(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('NT\$1760／晚'), findsOneWidget);
        expect(find.text('高空跳台'), findsOneWidget);
        await tester.tap(find.text('自訂房型'));
        expect(opened?['id'], 'other-shop-room');
        expect(find.text('電話聯絡'), findsOneWidget);
        expect(find.text('查看地圖'), findsOneWidget);
        expect(find.text('加入 LINE'), findsOneWidget);
        expect(find.text('臺南市另一店地址'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
