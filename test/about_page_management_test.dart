// 功能：關於我們內容、外觀、草稿及單一資料流的局部驗證，不寫入正式資料。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_media.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

const theme = HomeThemeModel.classicDefault;
final shop = <String, dynamic>{
  'aboutTitle': '我們的店',
  'aboutDescription': '簡短而真實的介紹',
  'aboutMessage': '完整故事的內容',
  'licenseNumber': '測試字號',
  'phone': '0000000000',
};
AboutPageSetting content(String layout) => AboutPageSetting.fromMap({
  'layout': layout,
  'stories': [
    const AboutContentItem(id: 's', title: '創店故事', text: '真實故事內容').toMap(),
  ],
  'principles': [
    const AboutContentItem(
      id: 'p',
      title: '觀察與陪伴',
      text: '依店主填寫內容顯示',
      icon: 'heart',
    ).toMap(),
  ],
  'team': [
    const AboutContentItem(
      id: 't',
      title: '店主',
      role: '照護夥伴',
      text: '一位店主也可使用',
    ).toMap(),
  ],
  'credentials': [
    const AboutContentItem(id: 'q', title: '訓練經歷', text: '由店家自行填寫').toMap(),
  ],
});
void main() {
  test('舊資料、未知排版、照片解析與局部欄位序列化', () {
    expect(AboutPageSetting.fromMap(null).layout, 'classic');
    expect(AboutPageSetting.fromMap({'layout': 'unknown'}).layout, 'classic');
    expect(
      aboutShopPhotos({
        'environmentIntro': {
          'galleryImages': [
            'a',
            {'url': 'b'},
            {'imageUrl': 'c'},
            '',
            null,
          ],
        },
      }),
      ['a', 'b', 'c'],
    );
    const image = AboutMedia(source: 'firstGallery');
    expect(
      image.resolveShop({
        'environmentIntro': {
          'galleryImages': ['new', 'old'],
        },
      }),
      'new',
    );
    expect(
      const AboutMedia(
        source: 'shop',
        url: 'explicit',
      ).resolveShop({'aboutImageUrl': 'other'}),
      'explicit',
    );
    final original = content('team').withAppearance({
      'fontSource': 'custom',
      'fontFamily': 'NotoSerifTC',
      'colorsSource': 'custom',
      'titleColor': 0xff123456,
    });
    final changed = original.withAppearance({'colorsSource': 'theme'});
    expect(aboutPageUpdates(original, changed), {
      'homeAppearance.aboutPage.appearance.colorsSource': 'theme',
    });
    final loaded = AboutPageSetting.fromShop({
      'homeAppearance': {'aboutPage': changed.toMap()},
    });
    expect(loaded.appearance['titleColor'], 0xff123456);
    expect(loaded.font, 'NotoSerifTC');
    expect(
      loaded.copyWith({'layout': 'story'}).items('team').single.title,
      '店主',
    );
    expect(loaded.setVisible('team', false).items('team'), hasLength(1));
    expect(
      loaded.setVisible('team', false).setVisible('team', true).visible('team'),
      isTrue,
    );
    final frame = AboutPageSetting().coverFrame({'aboutImageFit': 'contain'});
    expect(frame.imageFit, 'contain');
    final reframed = AboutPageSetting().copyWith({
      'coverFrame': frame.copyWith(imageFit: 'cover').toMap(),
    });
    expect(reframed.coverFrame({'aboutImageFit': 'contain'}).imageFit, 'cover');
    expect(
      aboutPageUpdates(AboutPageSetting(), reframed).keys.every(
        (key) => key.startsWith('homeAppearance.aboutPage.coverFrame.'),
      ),
      isTrue,
    );
  });
  testWidgets('明確選圖不換來源，失效圖片安全降級，空相簿不留照片區', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 200,
            child: AboutMediaView(
              media: AboutMedia(
                source: 'shop',
                url: 'https://invalid.example/about.jpg',
              ),
              shop: {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    final setting = AboutPageSetting.fromMap({
      'layout': 'brief',
      'cover': const AboutMedia(source: 'firstGallery').toMap(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutIntroView(
            shop: const {
              'aboutTitle': '仍有真實介紹',
              'environmentIntro': {'galleryImages': []},
            },
            setting: setting,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('仍有真實介紹'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('儲存失敗保留草稿，不誤顯示已儲存', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream.value(shop),
          saveAbout: (_) async => throw StateError('測試失敗'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '失敗後保留');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    final state =
        tester.state(find.byType(ShopAboutManagePage))
            as ShopDashboardLeaveAware;
    expect(state.dashboardHasUnsavedChanges, isTrue);
    expect(find.text('有未儲存變更'), findsOneWidget);
    expect(find.text('已儲存'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('六種結構在手機與桌機，大字、單人團隊及空區塊安全顯示', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [360.0, 390.0, 430.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final layout in AboutPageSetting.layouts.keys) {
        var setting = content(layout).withAppearance({'textScale': 1.3});
        final data = {
          ...shop,
          if (width == 360)
            'aboutTitle': List.filled(12, '長篇品牌介紹 Long title ').join(),
        };
        if (width >= 430) {
          const photo = AboutMedia(
            source: 'shop',
            url: 'https://invalid.example/story.jpg',
          );
          setting = setting
              .copyWith({'cover': photo.toMap()})
              .withItems('stories', [
                setting.items('stories').first.copyWith(image: photo),
                const AboutContentItem(
                  id: 's2',
                  title: '第二段故事',
                  text: '另一段故事',
                  image: photo,
                ),
              ])
              .withItems('team', [
                ...setting.items('team'),
                AboutContentItem(
                  id: 't2',
                  title: '照護夥伴',
                  text: List.filled(16, '保留完整的長篇介紹。').join(),
                ),
              ]);
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AboutIntroView(shop: data, setting: setting, theme: theme),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$layout $width');
        expect(find.text('創店故事'), findsOneWidget);
        expect(find.text('店主'), findsOneWidget);
      }
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutIntroView(
            shop: const {},
            setting: AboutPageSetting(),
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('照護理念'), findsNothing);
    expect(find.text('團隊介紹'), findsNothing);
    expect(find.textContaining('開始介紹'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('局部字體與配色有效，切回跟隨保留自訂值並使用新主題', (tester) async {
    final custom = content('brief').withAppearance({
      'fontSource': 'custom',
      'fontFamily': 'NotoSerifTC',
      'colorsSource': 'custom',
      'titleColor': 0xff112233,
      'bodyColor': 0xff334455,
      'cardsSource': 'custom',
      'cardColor': 0xffffffff,
    });
    Widget view(AboutPageSetting setting, HomeThemeModel base) => MaterialApp(
      home: Scaffold(
        body: AboutIntroView(shop: shop, setting: setting, theme: base),
      ),
    );
    await tester.pumpWidget(view(custom, theme));
    await tester.pumpAndSettle();
    final title = tester.element(find.text('我們的店'));
    expect(DefaultTextStyle.of(title).style.fontFamily, 'NotoSerifTC');
    expect(
      tester.widget<Text>(find.text('我們的店')).style!.color,
      const Color(0xff112233),
    );
    final following = custom.withAppearance({
      'fontSource': 'theme',
      'colorsSource': 'theme',
      'cardsSource': 'theme',
    });
    await tester.pumpWidget(
      view(following, theme.copyWith(textColorValue: 0xff234567)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('我們的店')).style!.color,
      const Color(0xff234567),
    );
    expect(following.appearance['fontFamily'], 'NotoSerifTC');
    expect(following.appearance['titleColor'], 0xff112233);
    final withFrontStyle = {
      ...shop,
      'homeAppearance': {
        'layout': 'modern',
        'modern': {
          'displayStyle': {
            'titleColor': 0xff345678,
            'cardRadius': 'small',
            'cardBorder': false,
          },
        },
      },
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutIntroView(
            shop: withFrontStyle,
            setting: following,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('我們的店')).style!.color,
      const Color(0xff345678),
    );
    final card = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('about-principles-p')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((card.decoration as BoxDecoration).border, isNull);
    expect(
      (card.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(10),
    );
  });
  testWidgets('管理草稿即時預覽、分頁保留、離開取消及局部儲存', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    final source = Stream<Map<String, dynamic>?>.value(shop);
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: source,
          saveAbout: (data) async => writes.add(data),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '修改中的標題');
    await tester.pumpAndSettle();
    expect(find.text('修改中的標題'), findsWidgets);
    expect(writes, isEmpty);
    await tester.tap(find.text('排版外觀'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('故事版'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('介紹內容'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '修改中的標題',
    );
    final state =
        tester.state(find.byType(ShopAboutManagePage))
            as ShopDashboardLeaveAware;
    final leaving = state.dashboardConfirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(await leaving, isFalse);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('預覽'));
    await tester.pumpAndSettle();
    expect(find.text('修改中的標題'), findsOneWidget);
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '修改中的標題',
    );
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(writes.single['aboutTitle'], '修改中的標題');
    expect(writes.single['homeAppearance.aboutPage.layout'], 'story');
    expect(writes.single.containsKey('homeAppearance'), isFalse);
    expect(writes.single.containsKey('aboutDescription'), isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '這段要放棄');
    await tester.pump();
    final discard = state.dashboardConfirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄變更'));
    await tester.pumpAndSettle();
    expect(await discard, isTrue);
    expect(writes, hasLength(1));
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '修改中的標題',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('正式頁使用單一店家訂閱，更新快照不重建資料來源', (tester) async {
    int subscriptions = 0;
    final controller = StreamController<Map<String, dynamic>?>(
      onListen: () => subscriptions++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutPage(
          shopId: 'local',
          theme: theme,
          shopStream: controller.stream,
        ),
      ),
    );
    controller.add({
      ...shop,
      'homeAppearance': {'aboutPage': content('team').toMap()},
    });
    await tester.pumpAndSettle();
    expect(find.byType(AboutIntroView), findsOneWidget);
    expect(subscriptions, 1);
    controller.add({...shop, 'aboutTitle': '最新標題'});
    await tester.pumpAndSettle();
    expect(find.text('最新標題'), findsOneWidget);
    expect(subscriptions, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => controller.close());
  });
}
