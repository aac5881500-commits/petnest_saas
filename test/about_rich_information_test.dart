import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_shop_info_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';

const theme = HomeThemeModel.classicDefault;
const info = <String, dynamic>{
  'name': '暖日貓咪旅店',
  'phone': '02-12345678',
  'businessHours': '週一至週日 10:00–19:00（預約制）',
  'city': '新北市',
  'district': '新莊區',
  'address': '示範路 55 號 2 樓',
  'licenseNumber': '測試字號',
  'igUrl': 'https://www.instagram.com/example',
  'lineUrl': 'https://lin.ee/example',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansTC'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: RepaintBoundary(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('contact cannot be hidden, including legacy false visibility', () {
    final setting = AboutPageSetting.fromMap({
      'visibility': {'contact': false},
      'sectionOrder': ['stories'],
    });
    expect(setting.visible('contact'), isTrue);
    expect(setting.setVisible('contact', false).visible('contact'), isTrue);
    expect(setting.sectionOrder.where((key) => key == 'contact'), hasLength(1));
    expect(
      AboutPageSetting.fromMap({
        'appearance': {'contactLayout': 'bad'},
      }).contactLayout,
      'list',
    );
  });
  test(
    'layout and features survive serialization and use local leaf updates',
    () {
      final before = AboutPageSetting();
      final next = before
          .copyWith({'layout': 'boutique'})
          .withAppearance({
            'contactLayout': 'visit',
            'highlightLayout': 'numbered',
          })
          .withItems('highlights', [
            const AboutContentItem(
              id: 'feature',
              title: '獨立房間',
              text: '依店內實際安排提供',
            ),
          ]);
      final loaded = AboutPageSetting.fromMap(next.toMap());
      expect(loaded.contactLayout, 'visit');
      expect(loaded.highlightLayout, 'numbered');
      expect(loaded.items('highlights').single.title, '獨立房間');
      expect(loaded.sectionOrder.first, 'contact');
      expect(
        aboutPageUpdates(
          before,
          next,
        ).keys.every((key) => key.startsWith('homeAppearance.aboutPage.')),
        isTrue,
      );
      expect(
        ShopIntroContent.about({
          'homeAppearance': {'aboutPage': next.toMap()},
        }),
        isTrue,
      );
    },
  );
  for (final layout in AboutPageSetting.layouts.keys) {
    testWidgets(
      '$layout always displays contact for empty shop and legacy hidden contact',
      (tester) async {
        await show(
          tester,
          AboutIntroView(
            shop: const {},
            setting: AboutPageSetting.fromMap({
              'layout': layout,
              'visibility': {'contact': false},
            }),
            theme: theme,
            preview: true,
          ),
        );
        expect(find.text('店家資訊'), findsOneWidget);
        expect(find.text('請洽店家確認'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final layout in AboutPageSetting.contactLayouts.keys) {
    testWidgets(
      '$layout contact supports narrow and large text, and wide screens',
      (tester) async {
        for (final width in [320.0, 1100.0]) {
          await show(
            tester,
            SingleChildScrollView(
              child: AboutShopInfoSection(
                shopId: '',
                shopData: info,
                theme: theme,
                layout: layout,
                previewOnly: true,
              ),
            ),
            width: width,
            scale: 1.3,
          );
          expect(find.text('店家資訊'), findsOneWidget);
          expect(find.text('暖日貓咪旅店'), findsOneWidget);
          expect(find.text('02-12345678'), findsOneWidget);
          expect(find.text('測試字號'), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (final button in tester.widgetList<OutlinedButton>(
            find.byType(OutlinedButton),
          )) {
            expect(button.onPressed, isNotNull);
            button.onPressed!();
          }
        }
      },
    );
  }
  for (final style in AboutPageSetting.highlightLayouts.keys) {
    testWidgets(
      '$style renders supplied features and hides empty or invisible ones',
      (tester) async {
        final setting = AboutPageSetting()
            .withItems('highlights', [
              const AboutContentItem(
                id: 'one',
                title: '獨立空間',
                text: '每間房配置依現場介紹為準',
                icon: 'home',
              ),
              const AboutContentItem(id: 'empty'),
              const AboutContentItem(
                id: 'hidden',
                title: '不應出現',
                visible: false,
              ),
            ])
            .withAppearance({'highlightLayout': style});
        await show(
          tester,
          AboutIntroView(
            shop: info,
            setting: setting,
            theme: theme,
            preview: true,
          ),
          width: 320,
          scale: 1.3,
        );
        expect(find.text('店家特色'), findsOneWidget);
        expect(find.text('獨立空間'), findsOneWidget);
        expect(find.text('不應出現'), findsNothing);
        expect(
          find.byKey(const ValueKey('about-highlights-empty')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'published page with only contact details still shows information',
    (tester) async {
      await show(
        tester,
        ShopAboutPage(
          shopId: 'shop',
          theme: theme,
          shopStream: Stream.value(info),
        ),
      );
      expect(find.text('店家資訊'), findsOneWidget);
      expect(find.text('02-12345678'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'disabled external links and invalid URLs never produce outgoing actions',
    (tester) async {
      await show(
        tester,
        AboutShopInfoSection(
          shopId: '',
          theme: theme,
          shopData: {...info, 'externalLinksEnabled': false},
        ),
      );
      expect(find.text('Instagram'), findsNothing);
      expect(find.text('LINE'), findsNothing);
      expect(find.text('開啟地圖'), findsNothing);
      expect(find.text('撥打電話'), findsNothing);
      expect(find.text('複製地址'), findsOneWidget);
      await show(
        tester,
        AboutShopInfoSection(
          shopId: '',
          theme: theme,
          shopData: {
            ...info,
            'igUrl': 'javascript:alert(1)',
            'lineUrl': 'not a url',
          },
        ),
      );
      expect(find.text('Instagram'), findsNothing);
      expect(find.text('LINE'), findsNothing);
    },
  );
  test(
    'address accepts existing full addresses without duplicating districts',
    () {
      expect(
        aboutShopAddress({
          'city': '新竹縣',
          'district': '新埔鎮',
          'address': '新埔鎮育賢街55號',
        }),
        '新竹縣新埔鎮育賢街55號',
      );
      expect(
        aboutShopAddress({
          'city': '新竹縣',
          'district': '新埔鎮',
          'address': '新竹縣新埔鎮育賢街55號',
        }),
        '新竹縣新埔鎮育賢街55號',
      );
      expect(aboutShopAddress({}), '');
    },
  );
  for (final width in [390.0, 1100.0]) {
    testWidgets('feature guide composition at $width', (tester) async {
      final setting = AboutPageSetting.fromMap({'layout': 'highlights'})
          .withItems('highlights', [
            const AboutContentItem(
              id: 'room',
              title: '空間與住宿',
              text: '介紹實際房型、休息空間與店內安排。',
              icon: 'home',
            ),
            const AboutContentItem(
              id: 'care',
              title: '照護與陪伴',
              text: '說明每日觀察與照護服務的實際方式。',
              icon: 'heart',
            ),
            const AboutContentItem(
              id: 'clean',
              title: '清潔與管理',
              text: '分享用品更換與環境清潔的實際流程。',
              icon: 'clean',
            ),
          ]);
      await show(
        tester,
        AboutIntroView(
          shop: {
            ...info,
            'aboutTitle': '認識我們的貓咪旅店',
            'aboutDescription': '從店家特色到聯絡資訊，找到適合毛孩的住宿安排。',
          },
          setting: setting,
          theme: theme,
          preview: true,
        ),
        width: width,
      );
      expect(find.text('店家資訊'), findsOneWidget);
      expect(find.text('空間與住宿'), findsOneWidget);
      expect(tester.takeException(), isNull);
      const capture = String.fromEnvironment('ABOUT_CAPTURE_DIR');
      if (capture.isNotEmpty) {
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(Uri.file('$capture/about-${width.toInt()}.png')),
        );
      }
    });
  }
}
