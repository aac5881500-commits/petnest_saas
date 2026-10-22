// 檔案名稱：test/home_environment_section_test.dart
// 功能說明：環境展示設定、圖片來源、住宿服務入口與窄螢幕版面。

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_environment_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/environment_home_image_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'galleryFirst follows the current album order and keeps legacy sources separate',
    () {
      final intro = <String, dynamic>{
        'heroImageUrl': 'https://example.test/hero',
        'galleryImages': [
          null,
          {'imageUrl': ''},
          'https://example.test/first',
          {'imageUrl': 'https://example.test/second'},
        ],
      };
      final legacy = HomeEnvironmentSectionSetting.fromMap({
        'imageSource': 'auto',
        'selectedImageUrl': 'https://example.test/hero',
      });
      expect(legacy.imageForIntro(intro), 'https://example.test/hero');
      final first = legacy.copyWith(imageSource: 'galleryFirst');
      expect(first.imageForIntro(intro), 'https://example.test/first');
      intro['galleryImages'] = [
        {'imageUrl': 'https://example.test/second'},
        'https://example.test/first',
      ];
      expect(first.imageForIntro(intro), 'https://example.test/second');
      intro['galleryImages'] = [];
      expect(first.imageForIntro(intro), isEmpty);
      final saved = HomeEnvironmentSectionSetting.fromMap(
        first
            .copyWith(
              imageSource: 'platformCard',
              simpleImageSource: 'platformCard',
              imageAssetId: 'card-asset',
            )
            .toMap(),
      );
      expect(saved.imageAssetId, 'card-asset');
      expect(saved.imageForIntro(intro), isEmpty);
      expect(
        saved
            .copyWith(layout: HomeEnvironmentLayouts.simpleEntry)
            .usesPlatformImage,
        isTrue,
      );
      expect(
        saved
            .copyWith(
              layout: HomeEnvironmentLayouts.simpleEntry,
              simpleImageSource: 'icon',
            )
            .usesPlatformImage,
        isFalse,
      );
      expect(
        saved.copyWith(imageSource: 'galleryFirst').imageAssetId,
        'card-asset',
      );
    },
  );

  testWidgets(
    'entry background fills each card size and default icon cards stay unchanged',
    (tester) async {
      var opened = 0;
      for (final size in HomeEnvironmentCardSizes.all) {
        Widget sample({bool image = false}) => _host(
          width: 320,
          child: ModernHomeEntryCard(
            cardKey: const Key('background-entry'),
            theme: HomeThemeModel.modernDefault,
            title: '環境介紹',
            subtitle: '查看環境',
            showSubtitle: true,
            cardSize: size,
            surface: HomeEnvironmentSurfaces.filled,
            icon: Icons.home_outlined,
            onTap: () => opened++,
            backgroundImage: image ? const _SolidImage() : null,
          ),
        );
        await tester.pumpWidget(sample());
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        final originalSize = tester.getSize(
          find.byKey(const Key('background-entry')),
        );
        await tester.pumpWidget(sample(image: true));
        await tester.pump();
        final card = tester.getSize(find.byKey(const Key('background-entry')));
        expect(card, originalSize);
        expect(tester.getSize(find.byType(Image)), card);
        if (size == HomeEnvironmentCardSizes.small) {
          expect(card.height, kModernHomeSmallCardHeight);
        }
        if (size == HomeEnvironmentCardSizes.wide) {
          expect(card.height, kModernHomeWideCardHeight);
        }
        if (size == HomeEnvironmentCardSizes.single) {
          expect(
            card.height,
            greaterThanOrEqualTo(kModernHomeSingleCardMinHeight),
          );
        }
        expect(find.byIcon(Icons.home_outlined), findsNothing);
        await tester.tap(find.byKey(const Key('background-entry')));
        expect(tester.takeException(), isNull);
      }
      expect(opened, 3);
    },
  );

  testWidgets(
    'environment thumbnail is bounded contain and uses album first at narrow and wide widths',
    (tester) async {
      for (final width in [300.0, 700.0]) {
        await tester.pumpWidget(
          _host(
            width: width,
            child: EnvironmentHomeImageSettings(
              setting: const HomeEnvironmentSectionSetting(
                layout: HomeEnvironmentLayouts.imageEntry,
                imageSource: 'galleryFirst',
              ),
              environmentIntro: const {
                'heroImageUrl': 'https://example.test/hero',
                'galleryImages': ['https://example.test/album'],
              },
              onChanged: (_) {},
              onPickLegacy: () {},
              onManage: () {},
            ),
          ),
        );
        final frame = tester.getSize(find.byType(AspectRatio));
        expect(frame.width, lessThanOrEqualTo(280));
        expect(frame.width / frame.height, closeTo(4 / 3, .001));
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.contain);
        expect((image.image as NetworkImage).url, 'https://example.test/album');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('首頁環境共用標題開關涵蓋四種版型，箭頭可直接導頁', (tester) async {
    var opened = 0;
    const setting = HomeEnvironmentSectionSetting(
      title: '上方區塊標題',
      subtitle: '上方區塊說明',
      cardTitle: '卡片內標題',
      cardSubtitle: '卡片內說明',
      showTitle: true,
      showDescription: true,
    );
    for (final layout in HomeEnvironmentLayouts.all) {
      Widget sample(HomeEnvironmentSectionSetting value) => _host(
        width: 360,
        child: ModernHomeEnvironmentSection(
          theme: HomeThemeModel.modernDefault,
          setting: value,
          environmentIntro: const {},
          facilityKeys: const ['water'],
          preview: true,
          onOpen: () => opened++,
          imageProvider: const _SolidImage(),
        ),
      );
      await tester.pumpWidget(sample(setting.copyWith(layout: layout)));
      await tester.pump();
      expect(find.text('上方區塊標題'), findsOneWidget);
      expect(find.text('上方區塊說明'), findsOneWidget);
      await tester.pumpWidget(
        sample(
          setting.copyWith(
            layout: layout,
            showTitle: false,
            showDescription: false,
          ),
        ),
      );
      expect(find.text('上方區塊標題'), findsNothing);
      expect(find.text('上方區塊說明'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      _host(
        width: 320,
        child: ModernHomeEnvironmentSection(
          theme: HomeThemeModel.modernDefault,
          setting: const HomeEnvironmentSectionSetting(),
          environmentIntro: const {},
          facilityKeys: const ['water'],
          preview: false,
          onOpen: () => opened++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('home-environment-end')));
    expect(opened, 1);
  });

  test('首頁設備選擇以 key 排序限量，不補入未選設備，並保留舊入口 false', () {
    final available = [
      for (final key in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {'key': key},
    ];
    const initial = HomeEnvironmentSectionSetting();
    expect(initial.selectedFacilities(available).length, 6);
    final draft = initial.copyWith(
      facilitySelectionCustomized: true,
      homeFacilityKeys: ['c', 'missing', 'a'],
      facilityLimit: 4,
    );
    final restored = HomeEnvironmentSectionSetting.fromMap(draft.toMap());
    expect(restored.selectedFacilities(available).map((m) => m['key']), [
      'c',
      'a',
    ]);
    expect(available.length, 7);
    expect(
      HomeEnvironmentSectionSetting.fromMap({
        'showEndEntryCard': false,
      }).showEndEntryCard,
      isFalse,
    );
    expect(
      HomeEnvironmentSectionSetting.fromMap({
        'title': '舊標題',
        'subtitle': '舊說明',
      }).cardTitle,
      '舊標題',
    );
  });

  test('舊資料沒有 environmentSection 時預設設備橫滑', () {
    final HomeEnvironmentSectionSetting setting =
        HomeEnvironmentSectionSetting.fromMap(null);
    expect(setting.layout, HomeEnvironmentLayouts.facilityScroll);
    expect(setting.showTitle, isFalse);
    expect(setting.showEndEntryCard, isTrue);
    expect(setting.showsOnHome(hasFacilities: true), isTrue);
    expect(
      HomeEnvironmentSectionSetting.fromMap('舊字串').layout,
      HomeEnvironmentLayouts.facilityScroll,
    );
  });

  test('三種 layout 可正常 toMap 與 fromMap', () {
    for (final String layout in HomeEnvironmentLayouts.all) {
      final HomeEnvironmentSectionSetting setting =
          HomeEnvironmentSectionSetting(
            layout: layout,
            title: '環境介紹',
            subtitle: '查看住宿環境與安心設備',
            showTitle: false,
            showSubtitle: true,
            showEndEntryCard: true,
            simpleCardSize: HomeEnvironmentCardSizes.wide,
            simpleSurface: HomeEnvironmentSurfaces.filled,
            simpleIcon: HomeEnvironmentIcons.home,
            imageHeight: HomeEnvironmentImageHeights.standard,
            imageTextPlacement: HomeEnvironmentTextPlacements.overlay,
          );
      final HomeEnvironmentSectionSetting restored =
          HomeEnvironmentSectionSetting.fromMap(setting.toMap());
      expect(restored.layout, layout);
      expect(restored.toMap()['layout'], layout);
      expect(restored.showSubtitle, isTrue);
      expect(
        restored.imageTextPlacement,
        HomeEnvironmentTextPlacements.overlay,
      );
    }
  });

  test('無效 layout 回復設備橫滑', () {
    final HomeEnvironmentSectionSetting setting =
        HomeEnvironmentSectionSetting.fromMap(<String, dynamic>{
          'layout': 'poster',
          'simpleCardSize': 'giant',
          'simpleSurface': 'glass',
          'simpleIcon': 'star',
          'imageHeight': 'huge',
          'imageTextPlacement': 'side',
          'title': '   ',
          'subtitle': '',
        });
    expect(setting.layout, HomeEnvironmentLayouts.facilityScroll);
    expect(setting.simpleCardSize, HomeEnvironmentCardSizes.wide);
    expect(setting.simpleSurface, HomeEnvironmentSurfaces.filled);
    expect(setting.simpleIcon, HomeEnvironmentIcons.home);
    expect(setting.imageHeight, HomeEnvironmentImageHeights.standard);
    expect(setting.imageTextPlacement, HomeEnvironmentTextPlacements.overlay);
    expect(setting.entryTitle, '環境介紹');
    expect(
      const HomeEnvironmentSectionSetting(title: '').facilityTitle,
      '環境設備',
    );
  });

  testWidgets('簡約入口三種卡片規格正常', (WidgetTester tester) async {
    for (final String size in HomeEnvironmentCardSizes.all) {
      await tester.pumpWidget(
        _host(
          width: 360,
          child: ModernHomeEntryCard(
            cardKey: Key('entry-$size'),
            theme: HomeThemeModel.modernDefault,
            title: '環境介紹',
            subtitle: '查看住宿環境與安心設備',
            showSubtitle: true,
            cardSize: size,
            surface: HomeEnvironmentSurfaces.filled,
            icon: Icons.home_outlined,
            onTap: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final Size box = tester.getSize(find.byKey(Key('entry-$size')));
      expect(box.width, greaterThan(300));
    }
  });

  test('圖片來源優先使用 heroImageUrl', () {
    expect(
      HomeEnvironmentSectionSetting.resolveImageUrl(<String, dynamic>{
        'heroImageUrl': 'https://cdn.example/hero.jpg',
        'galleryImages': <Map<String, dynamic>>[
          <String, dynamic>{'imageUrl': 'https://cdn.example/gallery.jpg'},
        ],
        'features': <Map<String, dynamic>>[
          <String, dynamic>{'imageUrl': 'https://cdn.example/feature.jpg'},
        ],
      }),
      'https://cdn.example/hero.jpg',
    );
  });

  test('沒有 heroImageUrl 時使用第一張有效 gallery 圖', () {
    expect(
      HomeEnvironmentSectionSetting.resolveImageUrl(<String, dynamic>{
        'heroImageUrl': '  ',
        'galleryImages': <Object>[
          <String, dynamic>{'imageUrl': ''},
          'https://cdn.example/gallery.jpg',
        ],
        'features': <Map<String, dynamic>>[
          <String, dynamic>{'imageUrl': 'https://cdn.example/feature.jpg'},
        ],
      }),
      'https://cdn.example/gallery.jpg',
    );
    expect(
      HomeEnvironmentSectionSetting.resolveImageUrl(<String, dynamic>{
        'galleryImages': <Map<String, dynamic>>[
          <String, dynamic>{'imageUrl': ''},
        ],
        'features': <Map<String, dynamic>>[
          <String, dynamic>{'imageUrl': 'https://cdn.example/feature.jpg'},
        ],
      }),
      'https://cdn.example/feature.jpg',
    );
  });

  testWidgets('完全沒有圖片時退回簡約入口', (WidgetTester tester) async {
    expect(HomeEnvironmentSectionSetting.resolveImageUrl(null), isEmpty);
    expect(
      HomeEnvironmentSectionSetting.resolveImageUrl(<String, dynamic>{
        'galleryImages': <Map<String, dynamic>>[
          <String, dynamic>{'url': ''},
        ],
        'features': <Object?>[null, <String, dynamic>{}],
      }),
      isEmpty,
    );
    await tester.pumpWidget(
      _host(
        width: 360,
        child: ModernHomeEnvironmentSection(
          theme: HomeThemeModel.modernDefault,
          setting: const HomeEnvironmentSectionSetting(
            layout: HomeEnvironmentLayouts.imageEntry,
          ),
          environmentIntro: const <String, dynamic>{},
          facilityKeys: const <String>[],
          preview: true,
          onOpen: () {},
        ),
      ),
    );
    expect(find.byKey(const Key('home-environment-entry')), findsOneWidget);
    expect(find.byKey(const Key('home-environment-image')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('環境展示有顯示時住宿服務不再放環境介紹', () {
    for (final String layout in <String>[
      HomeEnvironmentLayouts.simpleEntry,
      HomeEnvironmentLayouts.imageEntry,
      HomeEnvironmentLayouts.facilityScroll,
    ]) {
      final HomeEnvironmentSectionSetting setting =
          HomeEnvironmentSectionSetting(layout: layout);
      final bool visible = setting.showsOnHome(hasFacilities: true);
      expect(visible, isTrue);
      expect(!visible, isFalse);
    }
  });

  test('設備橫滑沒有設備時不占首頁區塊', () {
    const HomeEnvironmentSectionSetting scroll =
        HomeEnvironmentSectionSetting();
    expect(scroll.showsOnHome(hasFacilities: false), isFalse);
    const HomeEnvironmentSectionSetting simple = HomeEnvironmentSectionSetting(
      layout: HomeEnvironmentLayouts.simpleEntry,
    );
    expect(simple.showsOnHome(hasFacilities: false), isTrue);
    const HomeEnvironmentSectionSetting photo = HomeEnvironmentSectionSetting(
      layout: HomeEnvironmentLayouts.imageEntry,
    );
    expect(photo.showsOnHome(hasFacilities: false), isTrue);
  });

  test('facilities 拖曳後 homeSectionOrder 正確', () {
    final List<String> saved = HomeSectionOrder.normalize(null);
    final List<String> visible = HomeSectionOrder.visible(
      saved,
      showAnnouncements: true,
    );
    final int from = visible.indexOf('facilities');
    final List<String> next = HomeSectionOrder.reorderVisible(
      saved: saved,
      visible: visible,
      oldIndex: from,
      newIndex: from + 2,
    );
    expect(next, <String>[
      'banners',
      'sharedEntries',
      'quickBooking',
      'announcements',
      'facilities',
      'dailyCare',
      'rooms',
      'featured',
      'storeEntrance',
      'about',
      'services',
      'policy',
      'faq',
      'reviews',
    ]);
    expect(next.contains('facilities'), isTrue);
  });

  testWidgets('320 到 500 寬度沒有 overflow', (WidgetTester tester) async {
    const HomeThemeModel theme = HomeThemeModel.modernDefault;
    final List<Widget> samples = <Widget>[
      ModernHomeEnvironmentSection(
        theme: theme,
        setting: const HomeEnvironmentSectionSetting(),
        environmentIntro: const <String, dynamic>{},
        facilityKeys: const <String>['air_cleaner', 'water', 'sunlight'],
        preview: true,
        onOpen: () {},
      ),
      for (final String size in HomeEnvironmentCardSizes.all)
        ModernHomeEntryCard(
          cardKey: Key('narrow-$size'),
          theme: theme,
          title: '環境介紹標題可以比較長',
          subtitle: '查看住宿環境與安心設備，副標也要能折行',
          showSubtitle: true,
          cardSize: size,
          surface: size == HomeEnvironmentCardSizes.wide
              ? HomeEnvironmentSurfaces.outlined
              : HomeEnvironmentSurfaces.transparent,
          icon: Icons.home_outlined,
          actionLabel: '查看環境介紹',
          onTap: () {},
        ),
      ModernHomeEnvironmentSection(
        theme: theme,
        setting: const HomeEnvironmentSectionSetting(
          layout: HomeEnvironmentLayouts.imageEntry,
          imageTextPlacement: HomeEnvironmentTextPlacements.overlay,
          imageHeight: HomeEnvironmentImageHeights.compact,
        ),
        environmentIntro: const <String, dynamic>{
          'heroImageUrl': 'https://cdn.example/hero.jpg',
          'heroImageAlignment': 'top',
        },
        facilityKeys: const <String>[],
        preview: true,
        onOpen: () {},
        imageProvider: const _SolidImage(),
      ),
    ];
    for (final double width in <double>[320, 500]) {
      for (final Widget sample in samples) {
        await tester.pumpWidget(_host(width: width, child: sample));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(_host(width: 360, child: samples.first));
    await tester.pump();
    final ScrollBehavior behavior = ScrollConfiguration.of(
      tester.element(find.byType(ListView).first),
    );
    expect(
      behavior.dragDevices,
      containsAll(<PointerDeviceKind>[
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      ]),
    );
    final RenderBox scrollBox = tester.renderObject<RenderBox>(
      find.byKey(const Key('home-environment-scroll')),
    );
    final double right = scrollBox
        .localToGlobal(Offset(scrollBox.size.width, 0))
        .dx;
    final double end = tester
        .getTopLeft(find.byKey(const Key('home-environment-end')))
        .dx;
    expect(end, greaterThanOrEqualTo(right));
    expect(
      tester.getSize(find.byKey(const Key('home-environment-end'))).width,
      greaterThanOrEqualTo(44),
    );
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    final double before = scrollable.position.pixels;
    await tester.drag(
      find.byKey(const Key('home-environment-scroll')),
      const Offset(-80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(before));
    expect(
      tester.getTopLeft(find.byKey(const Key('home-environment-end'))).dx,
      end,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _host({required double width, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

class _SolidImage extends ImageProvider<_SolidImage> {
  const _SolidImage();

  @override
  Future<_SolidImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_SolidImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_SolidImage key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_frame());
  }

  Future<ImageInfo> _frame() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF224466),
    );
    final ui.Image image = await recorder.endRecording().toImage(8, 8);
    return ImageInfo(image: image);
  }
}
