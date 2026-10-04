import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/about_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_about_section.dart';

void main() {
  const HomeRoomSectionSetting rooms = HomeRoomSectionSetting(
    layout: HomeRoomSectionLayouts.simpleEntry,
    simple: HomeRoomSimpleSetting(cardSize: HomeRoomSimpleCardSizes.small),
  );
  const HomeEnvironmentSectionSetting environment =
      HomeEnvironmentSectionSetting(
        layout: HomeEnvironmentLayouts.simpleEntry,
        simpleCardSize: HomeEnvironmentCardSizes.small,
      );
  const HomeAboutSectionSetting about = HomeAboutSectionSetting(
    enabled: true,
    layout: HomeAboutLayouts.simpleEntry,
    cardSize: HomeAboutCardSizes.small,
  );

  HomeSectionSpan spanOf(String sectionId) {
    return homeSectionSpan(
      sectionId: sectionId,
      rooms: rooms,
      environment: environment,
      about: about,
    );
  }

  List<List<String>> rowsOf(List<String> ids) {
    return packHomeSections(
      ids,
      spanOf,
    ).map((HomeSectionRow row) => row.sectionIds).toList();
  }

  test('about small pairs with environment small', () {
    expect(rowsOf(<String>['facilities', 'about']), <List<String>>[
      <String>['facilities', 'about'],
    ]);
  });

  test('room small pairs with about small', () {
    expect(rowsOf(<String>['rooms', 'about', 'reviews']), <List<String>>[
      <String>['rooms', 'about'],
      <String>['reviews'],
    ]);
  });

  test('three small sections wrap the third onto the next row', () {
    final List<HomeSectionRow> rows = packHomeSections(<String>[
      'rooms',
      'facilities',
      'about',
    ], spanOf);
    expect(rows.first.sectionIds, <String>['rooms', 'facilities']);
    expect(rows.last.sectionIds, <String>['about']);
    expect(rows.last.span, HomeSectionSpan.half);
    expect(rows.last.isPair, isFalse);
  });

  test('image and brand cards take a full row', () {
    const HomeAboutSectionSetting image = HomeAboutSectionSetting(
      enabled: true,
      layout: HomeAboutLayouts.imageEntry,
      cardSize: HomeAboutCardSizes.small,
    );
    const HomeAboutSectionSetting brand = HomeAboutSectionSetting(
      enabled: true,
      layout: HomeAboutLayouts.brandIntro,
    );
    expect(image.isHalf, isFalse);
    expect(brand.isHalf, isFalse);
    expect(
      packHomeSections(<String>['about', 'rooms'], (String id) {
        return homeSectionSpan(
          sectionId: id,
          rooms: rooms,
          environment: environment,
          about: image,
        );
      }).map((HomeSectionRow row) => row.sectionIds),
      <List<String>>[
        <String>['about'],
        <String>['rooms'],
      ],
    );
  });

  test('dragging about re-pairs it with the neighboring half', () {
    final List<String> saved = HomeSectionOrder.normalize(null);
    final List<String> visible = HomeSectionOrder.visible(
      saved,
      showAnnouncements: true,
      showAbout: true,
    );
    final int aboutIndex = visible.indexOf('about');
    final int roomsIndex = visible.indexOf('rooms');
    final int slot = roomsIndex + 1;
    final List<String> moved = HomeSectionOrder.reorderVisible(
      saved: saved,
      visible: visible,
      oldIndex: aboutIndex,
      newIndex: slot > aboutIndex ? slot + 1 : slot,
    );
    expect(moved.indexOf('about'), moved.indexOf('rooms') + 1);
    final HomeSectionRow pair = packHomeSections(
      moved,
      spanOf,
    ).firstWhere((HomeSectionRow row) => row.sectionIds.contains('about'));
    expect(pair.sectionIds, <String>['rooms', 'about']);
  });

  test('stay service about entry follows the shared visibility rule', () {
    expect(stayServiceShowsAbout(const HomeAboutSectionSetting()), isTrue);
    expect(
      stayServiceShowsAbout(const HomeAboutSectionSetting(enabled: true)),
      isFalse,
    );
    final List<String> hidden = HomeSectionOrder.visible(
      HomeSectionOrder.normalize(null),
      showAnnouncements: true,
      showAbout: false,
    );
    expect(hidden.contains('about'), isFalse);
    expect(
      HomeSectionOrder.visible(
        HomeSectionOrder.normalize(null),
        showAnnouncements: true,
      ).contains('about'),
      isTrue,
    );
  });

  test('missing aboutSection stays safe and image falls back in order', () {
    final HomeAboutSectionSetting setting = HomeAboutSectionSetting.fromMap(
      null,
    );
    expect(setting.enabled, isFalse);
    expect(setting.layout, HomeAboutLayouts.simpleEntry);
    expect(setting.cardSize, HomeAboutCardSizes.standard);
    expect(
      HomeAboutSectionSetting.fromMap(<String, dynamic>{
        'layout': 'poster',
        'cardSize': 'giant',
      }).layout,
      HomeAboutLayouts.simpleEntry,
    );
    const HomeAboutSectionSetting enabled = HomeAboutSectionSetting(
      enabled: true,
      imageUrl: 'https://cdn.example/chosen.jpg',
    );
    expect(
      HomeAboutSectionSetting.resolveImageUrl(
        setting: enabled,
        shop: <String, dynamic>{
          'aboutImageUrl': 'https://cdn.example/cover.jpg',
          'logoUrl': 'https://cdn.example/logo.jpg',
        },
        environmentIntro: <String, dynamic>{
          'heroImageUrl': 'https://cdn.example/env.jpg',
        },
      ),
      'https://cdn.example/chosen.jpg',
    );
    expect(
      HomeAboutSectionSetting.resolveImageUrl(
        setting: const HomeAboutSectionSetting(enabled: true),
        shop: <String, dynamic>{
          'aboutImageUrl': 'https://cdn.example/cover.jpg',
          'logoUrl': 'https://cdn.example/logo.jpg',
        },
        environmentIntro: const <String, dynamic>{},
      ),
      'https://cdn.example/cover.jpg',
    );
    expect(
      HomeAboutSectionSetting.resolveImageUrl(
        setting: const HomeAboutSectionSetting(enabled: true),
        shop: const <String, dynamic>{
          'logoUrl': 'https://cdn.example/logo.jpg',
        },
        environmentIntro: const <String, dynamic>{
          'heroImageUrl': 'https://cdn.example/env.jpg',
        },
      ),
      'https://cdn.example/logo.jpg',
    );
    expect(
      HomeAboutSectionSetting.resolveImageUrl(
        setting: const HomeAboutSectionSetting(enabled: true),
        shop: const <String, dynamic>{},
        environmentIntro: const <String, dynamic>{
          'heroImageUrl': 'https://cdn.example/env.jpg',
        },
      ),
      'https://cdn.example/env.jpg',
    );
    expect(
      HomeAboutSectionSetting.resolveImageUrl(
        setting: const HomeAboutSectionSetting(enabled: true),
        shop: const <String, dynamic>{},
        environmentIntro: const <String, dynamic>{},
      ),
      isEmpty,
    );
  });

  testWidgets('about layouts fit narrow widths and empty photos use an icon', (
    WidgetTester tester,
  ) async {
    const HomeThemeModel theme = HomeThemeModel.modernDefault;
    for (final double width in <double>[320, 500]) {
      for (final HomeAboutSectionSetting setting in <HomeAboutSectionSetting>[
        const HomeAboutSectionSetting(
          enabled: true,
          cardSize: HomeAboutCardSizes.small,
          title: '很長的關於我們標題用來確認不會爆版',
          subtitle: '很長的簡介用來確認窄螢幕會省略而不是溢出畫面',
        ),
        const HomeAboutSectionSetting(
          enabled: true,
          layout: HomeAboutLayouts.imageEntry,
          imagePosition: HomeAboutImagePositions.left,
          title: '很長的關於我們標題用來確認不會爆版',
          subtitle: '很長的簡介用來確認窄螢幕會省略而不是溢出畫面',
        ),
        const HomeAboutSectionSetting(
          enabled: true,
          layout: HomeAboutLayouts.brandIntro,
          title: '關於我們',
          subtitle: '很長的簡介用來確認窄螢幕會省略而不是溢出畫面',
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: ModernHomeAboutSection(
                  theme: theme,
                  setting: setting,
                  shop: const <String, dynamic>{'name': '很長的店名用來確認品牌卡不會爆版'},
                  environmentIntro: const <String, dynamic>{},
                  shopName: '很長的店名用來確認品牌卡不會爆版',
                  logoUrl: '',
                  preview: true,
                  onOpen: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('home-about-card')), findsOneWidget);
      }
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ModernHomeAboutSection(
              theme: HomeThemeModel.modernDefault,
              setting: const HomeAboutSectionSetting(
                enabled: true,
                layout: HomeAboutLayouts.imageEntry,
                showImage: true,
              ),
              shop: const <String, dynamic>{},
              environmentIntro: const <String, dynamic>{},
              shopName: '毛孩旅店',
              logoUrl: '',
              preview: false,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('home-about-icon')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('about card size names map without changing stored values', () {
    expect(HomeAboutCardSizes.entryCardSize('small'), 'small');
    expect(HomeAboutCardSizes.entryCardSize('standard'), 'wide');
    expect(HomeAboutCardSizes.entryCardSize('wide'), 'single');
    expect(HomeAboutCardSizes.label('small'), '小卡');
    expect(HomeAboutCardSizes.label('standard'), '標準橫卡');
    expect(HomeAboutCardSizes.label('wide'), '長卡');
    expect(
      HomeAboutSectionSetting.fromMap(<String, dynamic>{
        'enabled': true,
        'title': '舊標題',
      }).useShopNameAsTitle,
      isTrue,
    );
    expect(
      HomeAboutSectionSetting.fromMap(<String, dynamic>{
        'useShopNameAsTitle': false,
      }).useShopNameAsTitle,
      isFalse,
    );
  });

  testWidgets('each about layout only shows controls that apply', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    HomeAboutSectionSetting setting = const HomeAboutSectionSetting(
      enabled: true,
    );
    Future<void> pump({
      List<Map<String, String>> images = const <Map<String, String>>[],
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 1600,
              child: AboutSectionSettingsPanel(
                setting: setting,
                theme: HomeThemeModel.modernDefault,
                imageChoices: images,
                onChanged: (HomeAboutSectionSetting next) {
                  setting = next;
                },
              ),
            ),
          ),
        ),
      );
    }

    await pump();
    expect(find.text('卡片尺寸'), findsNothing);
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('卡片尺寸'), findsOneWidget);
    expect(find.text('標準橫卡'), findsOneWidget);
    expect(find.text('顯示箭頭'), findsOneWidget);
    expect(find.text('顯示按鈕'), findsNothing);
    expect(find.text('按鈕文字'), findsNothing);
    expect(find.text('圖片裁切'), findsNothing);
    expect(find.text('顯示圖片'), findsNothing);
    expect(find.text('顯示 Logo'), findsOneWidget);
    expect(find.text('文字對齊'), findsOneWidget);
    expect(find.text('卡片外觀'), findsOneWidget);

    await tester.tap(find.text('小卡'));
    await tester.pump();
    setting = setting.copyWith(cardSize: HomeAboutCardSizes.small);
    await pump();
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('顯示箭頭'), findsNothing);
    expect(find.text('顯示按鈕'), findsNothing);
    expect(find.text('圖片裁切'), findsNothing);
    expect(find.text('顯示圖片'), findsNothing);

    setting = setting.copyWith(cardSize: HomeAboutCardSizes.wide);
    await pump();
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('顯示箭頭'), findsOneWidget);
    expect(find.text('顯示按鈕'), findsOneWidget);
    expect(find.text('按鈕文字'), findsOneWidget);
    await tester.tap(find.text('顯示按鈕'));
    await tester.pump();
    setting = setting.copyWith(showButton: false);
    await pump();
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('按鈕文字'), findsNothing);

    setting = const HomeAboutSectionSetting(
      enabled: true,
      layout: HomeAboutLayouts.imageEntry,
    );
    await pump();
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('圖文位置'), findsOneWidget);
    expect(find.text('顯示圖片'), findsOneWidget);
    expect(find.text('顯示按鈕'), findsOneWidget);
    expect(find.text('顯示箭頭'), findsOneWidget);
    expect(find.text('卡片尺寸'), findsNothing);
    expect(find.text('顯示 Logo'), findsNothing);
    expect(find.text('目前沒有可用圖片，將使用內建圖示'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '填滿裁切'))
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '偏上'))
          .onSelected,
      isNull,
    );

    setting = const HomeAboutSectionSetting(
      enabled: true,
      layout: HomeAboutLayouts.brandIntro,
      useShopNameAsTitle: true,
    );
    await pump(
      images: const <Map<String, String>>[
        <String, String>{
          'label': '關於我們封面',
          'url': 'https://cdn.example/cover.jpg',
        },
      ],
    );
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('使用店家名稱'), findsOneWidget);
    expect(find.text('使用自訂標題'), findsOneWidget);
    expect(find.text('品牌摘要'), findsOneWidget);
    expect(find.text('顯示 Logo'), findsOneWidget);
    expect(find.text('顯示圖片'), findsOneWidget);
    expect(find.text('顯示按鈕'), findsOneWidget);
    expect(find.text('圖文位置'), findsNothing);
    expect(find.text('顯示箭頭'), findsNothing);
    expect(find.text('卡片尺寸'), findsNothing);
    expect(find.text('首頁標題'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '填滿裁切'))
          .onSelected,
      isNotNull,
    );
    await tester.tap(find.text('使用自訂標題'));
    await tester.pump();
    setting = setting.copyWith(useShopNameAsTitle: false);
    await pump(
      images: const <Map<String, String>>[
        <String, String>{
          'label': '關於我們封面',
          'url': 'https://cdn.example/cover.jpg',
        },
      ],
    );
    await tester.tap(find.text('顯示細節'));
    await tester.pump();
    expect(find.text('首頁標題'), findsOneWidget);
  });

  testWidgets('brand and image about cards honor title image and actions', (
    WidgetTester tester,
  ) async {
    final MemoryImage image = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    Future<void> pump(HomeAboutSectionSetting setting, {bool preview = true}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ModernHomeAboutSection(
                theme: HomeThemeModel.modernDefault,
                setting: setting,
                shop: const <String, dynamic>{},
                environmentIntro: const <String, dynamic>{},
                shopName: '毛孩旅店',
                logoUrl: '',
                preview: preview,
                imageProvider: image,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
    }

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        layout: HomeAboutLayouts.brandIntro,
        useShopNameAsTitle: true,
        title: '自訂標題',
        showLogo: true,
        showImage: true,
        showButton: true,
        buttonText: '了解品牌',
        imageFit: HomeAboutImageFits.contain,
        imageAlign: HomeAboutImageAligns.top,
      ),
    );
    await tester.pump();
    expect(find.text('毛孩旅店'), findsOneWidget);
    expect(find.text('自訂標題'), findsNothing);
    expect(find.text('了解品牌'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    Image painted = tester.widget<Image>(find.byType(Image));
    expect(painted.fit, BoxFit.contain);
    expect(painted.alignment, Alignment.topCenter);

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        layout: HomeAboutLayouts.brandIntro,
        useShopNameAsTitle: false,
        title: '自訂標題',
        showLogo: false,
        showImage: true,
        showButton: false,
        imageFit: HomeAboutImageFits.cover,
        imageAlign: HomeAboutImageAligns.bottom,
      ),
    );
    await tester.pump();
    expect(find.text('自訂標題'), findsOneWidget);
    expect(find.text('毛孩旅店'), findsNothing);
    expect(find.text('了解品牌'), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    painted = tester.widget<Image>(find.byType(Image));
    expect(painted.fit, BoxFit.cover);
    expect(painted.alignment, Alignment.bottomCenter);

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        layout: HomeAboutLayouts.imageEntry,
        imagePosition: HomeAboutImagePositions.left,
        title: '圖文標題',
        showImage: true,
        showButton: true,
        showArrow: true,
        buttonText: '看圖文',
        imageFit: HomeAboutImageFits.contain,
        imageAlign: HomeAboutImageAligns.bottom,
      ),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('home-about-photo'))).dx,
      lessThan(tester.getTopLeft(find.text('圖文標題')).dx),
    );
    expect(find.text('看圖文'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    painted = tester.widget<Image>(find.byType(Image));
    expect(painted.fit, BoxFit.contain);
    expect(painted.alignment, Alignment.bottomCenter);

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        layout: HomeAboutLayouts.imageEntry,
        imagePosition: HomeAboutImagePositions.right,
        title: '圖文標題',
        showButton: false,
        showArrow: false,
      ),
      preview: false,
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('home-about-photo'))).dx,
      greaterThan(tester.getTopLeft(find.text('圖文標題')).dx),
    );
    expect(find.text('看圖文'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        layout: HomeAboutLayouts.imageEntry,
        imagePosition: HomeAboutImagePositions.top,
        title: '圖文標題',
      ),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('home-about-photo'))).dy,
      lessThan(tester.getTopLeft(find.text('圖文標題')).dy),
    );

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        cardSize: HomeAboutCardSizes.small,
        showArrow: true,
        showButton: true,
        buttonText: '不該出現',
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('不該出現'), findsNothing);

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        cardSize: HomeAboutCardSizes.standard,
        showArrow: true,
        showButton: true,
        buttonText: '不該出現',
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('不該出現'), findsNothing);

    await pump(
      const HomeAboutSectionSetting(
        enabled: true,
        cardSize: HomeAboutCardSizes.wide,
        showArrow: true,
        showButton: true,
        buttonText: '長卡按鈕',
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('長卡按鈕'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview and live about renderers share the same setting', (
    WidgetTester tester,
  ) async {
    const HomeAboutSectionSetting setting = HomeAboutSectionSetting(
      enabled: true,
      title: '共用標題',
      subtitle: '共用簡介',
      cardSize: HomeAboutCardSizes.standard,
      showArrow: false,
    );
    var opened = 0;
    Future<void> pump({required bool preview}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ModernHomeAboutSection(
                theme: HomeThemeModel.modernDefault,
                setting: setting,
                shop: const <String, dynamic>{},
                environmentIntro: const <String, dynamic>{},
                shopName: '毛孩旅店',
                logoUrl: '',
                preview: preview,
                onOpen: () => opened++,
              ),
            ),
          ),
        ),
      );
    }

    await pump(preview: true);
    expect(find.text('共用標題'), findsOneWidget);
    expect(find.text('共用簡介'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    await tester.tap(find.byKey(const Key('home-about-card')));
    await tester.pump();
    expect(opened, 0);

    await pump(preview: false);
    expect(find.text('共用標題'), findsOneWidget);
    expect(find.text('共用簡介'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    await tester.tap(find.byKey(const Key('home-about-card')));
    await tester.pump();
    expect(opened, 1);
  });
}
