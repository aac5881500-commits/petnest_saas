// 功能：店主快速範本的重現性、內建照片、草稿與儲存讀回，不寫正式資料。
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/about_page_template.dart';
import 'package:petnest_saas/core/models/about_builtin_photos.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_builtin_photo.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_media.dart';

void main() {
  test('不同舊外觀一鍵還原同一配方，保留實際內容與顯示條件', () {
    final first = AboutPageSetting().withAppearance({
      'coverLayout': 'imageRight',
      'backgroundSource': 'library',
      'fontFamily': 'KleeOne',
      'cardImage': {'source': 'platformCard', 'assetId': 'old'},
    });
    final second = AboutPageSetting().withAppearance({
      'principleLayout': 'stacked',
      'contactLayout': 'list',
    });
    final a = AboutPageTemplate.apply(first),
        b = AboutPageTemplate.apply(second);
    for (final key in AboutPageTemplate.appearance.keys) {
      expect(a.appearance[key], b.appearance[key]);
    }
    expect(a.cover.source, 'legacy');
    expect(a.items('principles'), isEmpty);
    final original = first
        .withItems('principles', [
          const AboutContentItem(
            id: 'mine',
            title: '原文',
            image: AboutMedia(
              source: 'shop',
              url: 'https://example.invalid/mine.jpg',
            ),
          ),
        ])
        .setVisible('principles', false)
        .copyWith({
          'cover': const AboutMedia(source: 'shop', url: 'mine').toMap(),
        });
    final next = AboutPageTemplate.apply(original, fillEmpty: true);
    expect(
      next.items('principles').single.toMap(),
      original.items('principles').single.toMap(),
    );
    expect(next.visible('principles'), false);
    expect(next.cover.url, 'mine');
  });
  test('明確補示範才新增空白內容，重複套用不重複且讀回一致', () {
    final next = AboutPageTemplate.apply(AboutPageSetting(), fillEmpty: true);
    expect(next.cover.source, 'builtin');
    expect(next.items('principles'), hasLength(3));
    expect(next.items('stories'), hasLength(1));
    expect(
      AboutPageTemplate.apply(next, fillEmpty: true).toMap(),
      next.toMap(),
    );
    final loaded = AboutPageSetting.fromMap(next.toMap());
    expect(loaded.cover.assetId, 'daylight-cover');
    expect(loaded.appearance, next.appearance);
    expect(loaded.storiesTitle, '我們的故事');
    expect(loaded.sectionOrder.last, 'contact');
    expect(
      AboutMedia.fromMap({
        'source': 'builtin',
        'assetId': 'not-allowed',
      }).source,
      'none',
    );
    expect(
      aboutPageUpdates(
        AboutPageSetting(),
        next,
      ).keys.every((key) => key.startsWith(AboutPageSetting.path)),
      true,
    );
  });
  testWidgets('範本圖集已打包，六張識別與來源皆可讀回', (tester) async {
    final image = await tester.runAsync(() async {
      final bytes = await rootBundle.load(AboutBuiltinPhotos.atlas);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    expect(image!.width / image.height, closeTo(1.5, .01));
    image.dispose();
    for (final id in AboutBuiltinPhotos.names.keys) {
      final media = AboutMedia.fromMap({'source': 'builtin', 'assetId': id});
      expect(media.source, 'builtin');
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 160,
            height: 120,
            child: AboutMediaView(media: media, shop: const {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AboutBuiltinPhoto>(find.byType(AboutBuiltinPhoto)).id,
        id,
      );
      expect(tester.takeException(), isNull);
    }
  });
  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('完整範本在 $width 手機優先呈現，無遠端素材查詢', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final setting = AboutPageTemplate.apply(
        AboutPageSetting(),
        fillEmpty: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AboutIntroView(
              shop: AboutPageTemplate.previewShop(const {
                'name': '本機測試',
                'phone': '0900000000',
                'address': '測試地址',
              }),
              setting: setting,
              theme: HomeThemeModel.classicDefault,
              preview: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AboutBuiltinPhoto), findsNWidgets(5));
      expect(find.text('我們的故事'), findsOneWidget);
      final card = tester.getSize(
        find.byKey(
          const ValueKey('about-principle-side-daylight-principle-space'),
        ),
      );
      if (width < 700) expect(card.height, lessThan(140));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('版型卡與快速範本共用完整套用事件', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final applies = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AboutAppearanceEditor(
              setting: AboutPageSetting(),
              theme: HomeThemeModel.classicDefault,
              onChanged: (_) => fail('日光簡約入口不應只修改 layout'),
              onApplyTemplate: applies.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('日光簡約版'));
    await tester.tap(find.text('日光簡約版'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('about-apply-daylight-template')),
    );
    await tester.tap(
      find.byKey(const ValueKey('about-apply-daylight-template')),
    );
    expect(applies, [false, false]);
  });
  testWidgets('店主只按範本按鈕便能重現，取消不改草稿，儲存經原流程', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream<Map<String, dynamic>?>.value(const {
            'name': '測試店',
            'aboutTitle': '',
            'aboutDescription': '',
          }),
          saveAbout: (data) async => writes.add(data),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('排版外觀'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('about-apply-daylight-template')),
    );
    await tester.tap(
      find.byKey(const ValueKey('about-apply-daylight-template')),
    );
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    var actual = tester
        .widgetList<AboutIntroView>(find.byType(AboutIntroView))
        .first;
    expect(actual.setting.layout, 'daylight');
    expect(actual.setting.items('principles'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('about-fill-daylight-example')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    actual = tester
        .widgetList<AboutIntroView>(find.byType(AboutIntroView))
        .first;
    expect(actual.setting.items('principles'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('about-fill-daylight-example')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('填入草稿'));
    await tester.pumpAndSettle();
    actual = tester
        .widgetList<AboutIntroView>(find.byType(AboutIntroView))
        .first;
    expect(actual.setting.items('principles'), hasLength(3));
    expect(actual.setting.cover.source, 'builtin');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('about-cover-subtitle-field')),
          )
          .controller!
          .text,
      AboutPageTemplate.subtitle,
    );
    expect(actual.shop['aboutTitle'], AboutPageTemplate.title);
    expect(writes, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, '儲存'));
    await tester.pumpAndSettle();
    expect(writes.single['homeAppearance.aboutPage.cover.source'], 'builtin');
    expect(
      writes.single['homeAppearance.aboutPage.appearance.backgroundSource'],
      'color',
    );
    expect(writes.single['aboutTitle'], AboutPageTemplate.title);
    expect(writes.single.containsKey('homeAppearance'), false);
    expect(tester.takeException(), isNull);
  });
}
