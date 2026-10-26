// Offline visual QA of the real management pages. Data and save callbacks are
// injected; no Firebase initialization, production reads or writes are used.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

const _shop = <String, dynamic>{
  'name': '暖日貓咪旅店',
  'aboutTitle': '安心相伴，像家一樣的旅程',
  'aboutDescription': '我們為每隻貓咪準備安靜、獨立的休息空間，從生活習慣開始，認識每一位入住的小客人。',
  'aboutMessage': '把日常交給我們照顧，讓您安心出門。\n每天觀察飲食與精神狀態，並與飼主分享照護紀錄。',
  'phone': '02-0000-0000',
  'licenseNumber': '本機預覽資料',
  'environmentIntro': <String, dynamic>{
    'heroTitle': '為貓咪準備的自在空間',
    'heroSubtitle': '獨立房間、柔和採光與每日清潔，陪伴貓咪慢慢熟悉新環境。',
    'bannerTitle': '安靜、舒適與安心照護',
    'bottomNote': '歡迎事先預約參觀，了解空間配置與照護方式。',
    'heroImageUrl': '',
    'bannerImageUrl': '',
    'galleryImages': <dynamic>[],
    'features': <Map<String, dynamic>>[
      <String, dynamic>{
        'title': '獨立休息空間',
        'description': '保有自己的氣味與作息，讓貓咪安心適應。',
        'imageUrl': '',
        'layout': 'imageRight',
      },
    ],
    'facilityKeys': <String>['air_cleaner', 'sunlight', 'disinfect'],
  },
};

TextStyle _font(TextStyle? style, double weight) =>
    (style ?? const TextStyle()).copyWith(
      fontFamily: 'NotoSansTC',
      fontVariations: [ui.FontVariation('wght', weight)],
    );

TextTheme _textTheme(TextTheme original) => original.copyWith(
  displayLarge: _font(original.displayLarge, 700),
  displayMedium: _font(original.displayMedium, 700),
  displaySmall: _font(original.displaySmall, 700),
  headlineLarge: _font(original.headlineLarge, 700),
  headlineMedium: _font(original.headlineMedium, 700),
  headlineSmall: _font(original.headlineSmall, 700),
  titleLarge: _font(original.titleLarge, 700),
  titleMedium: _font(original.titleMedium, 600),
  titleSmall: _font(original.titleSmall, 600),
  bodyLarge: _font(original.bodyLarge, 400),
  bodyMedium: _font(original.bodyMedium, 400),
  bodySmall: _font(original.bodySmall, 400),
  labelLarge: _font(original.labelLarge, 600),
  labelMedium: _font(original.labelMedium, 500),
  labelSmall: _font(original.labelSmall, 500),
);

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final text = FontLoader('NotoSansTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    final rounded = FontLoader('jfOpenHuninn')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    final serif = FontLoader('NotoSerifTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSerifTC-VariableFont_wght.ttf'),
      );
    final handwriting = FontLoader('KleeOne')
      ..addFont(rootBundle.load('assets/fonts/KleeOne-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/KleeOne-SemiBold.ttf'));
    final song = FontLoader('ChironSungHK')
      ..addFont(rootBundle.load('assets/fonts/ChironSungHKVF.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([
      text.load(),
      rounded.load(),
      serif.load(),
      handwriting.load(),
      song.load(),
      icons.load(),
    ]);
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['PETNEST_MANAGEMENT_PREVIEW'];
  if (directory == null || directory.trim().isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Widget _previewApp(GlobalKey capture, Size viewport, Widget page) {
  final base = PetNestAppTheme.build();
  return RepaintBoundary(
    key: capture,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // Loaded font and explicit weight axes are scoped to this test fixture.
      theme: base.copyWith(
        textTheme: _textTheme(base.textTheme),
        primaryTextTheme: _textTheme(base.primaryTextTheme),
        appBarTheme: base.appBarTheme.copyWith(
          titleTextStyle: _font(base.appBarTheme.titleTextStyle, 700),
          toolbarTextStyle: _font(base.appBarTheme.toolbarTextStyle, 400),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: viewport, textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: page,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final viewport in <String, Size>{
    'phone_320': const Size(320, 900),
    'phone_390': const Size(390, 900),
    'desktop_1280': const Size(1280, 1000),
  }.entries) {
    for (final about in [true, false]) {
      final name = '${about ? 'about' : 'environment'}_manage_${viewport.key}';
      testWidgets('內附字體的店家介紹管理預覽 $name', (tester) async {
        tester.view.physicalSize = viewport.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _loadFonts(tester);
        var writes = 0;
        final capture = GlobalKey();
        final Widget page = about
            ? ShopAboutManagePage(
                shopId: 'offline-preview',
                shopStream: Stream.value(_shop),
                saveAbout: (_) async {
                  writes++;
                },
              )
            : ShopEnvironmentManagePage(
                shopId: 'offline-preview',
                loadShop: () async => _shop,
                saveIntro: (_) async {
                  writes++;
                },
              );
        await tester.pumpWidget(_previewApp(capture, viewport.value, page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(about ? '關於我們管理' : '環境介紹管理'), findsOneWidget);
        expect(writes, 0);
        if (about) {
          expect(find.byType(TextField), findsWidgets);
        } else {
          // Environment management initially opens the layout tab. Capture the
          // actual overview before opening the separate cover/text editor.
          expect(
            find.text(viewport.value.width >= 1100 ? '版型與樣式' : '整頁快速範本'),
            findsWidgets,
          );
          expect(find.text('環境介紹讀取失敗'), findsNothing);
          final state =
              tester.state(find.byType(ShopEnvironmentManagePage))
                  as ShopDashboardLeaveAware;
          expect(state.dashboardHasUnsavedChanges, isFalse);
          expect(state.dashboardIsBusy, isFalse);
          if (viewport.value.width < 1100) {
            final warm = tester.getRect(
              find.widgetWithText(OutlinedButton, '溫暖旅宿'),
            );
            final minimal = tester.getRect(
              find.widgetWithText(OutlinedButton, '清爽簡約'),
            );
            final photo = tester.getRect(
              find.widgetWithText(OutlinedButton, '照片導覽'),
            );
            final care = tester.getRect(
              find.widgetWithText(OutlinedButton, '安心照護'),
            );
            expect((warm.top - minimal.top).abs(), lessThan(1));
            expect(minimal.left, greaterThanOrEqualTo(warm.right + 9));
            expect(photo.top, greaterThanOrEqualTo(warm.bottom + 9));
            expect((photo.top - care.top).abs(), lessThan(1));
            expect(warm.width, greaterThanOrEqualTo(120));
            expect(warm.height, greaterThanOrEqualTo(48));
          }
        }
        await _capture(tester, capture, name);
        if (!about) {
          final title = find.widgetWithText(TextField, '主標題');
          if (viewport.value.width >= 1100) {
            final coverTab = find.text('封面與文案').first;
            await tester.ensureVisible(coverTab);
            await tester.tap(coverTab);
            await tester.pumpAndSettle();
          } else {
            await tester.scrollUntilVisible(
              title,
              500,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 30,
            );
            await tester.pumpAndSettle();
          }
          expect(title, findsOneWidget);
          expect(
            tester.widget<TextField>(title).controller!.text,
            '為貓咪準備的自在空間',
          );
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          expect(writes, 0);
          expect(tester.takeException(), isNull);
          await _capture(tester, capture, '${name}_cover');
        }
      });
    }
    if (viewport.key == 'phone_320') continue;
    testWidgets('環境介紹讀取失敗預覽 ${viewport.key}', (tester) async {
      tester.view.physicalSize = viewport.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _loadFonts(tester);
      var writes = 0;
      final capture = GlobalKey();
      await tester.pumpWidget(
        _previewApp(
          capture,
          viewport.value,
          ShopEnvironmentManagePage(
            shopId: 'offline-preview',
            loadShop: () async => throw StateError('offline preview'),
            saveIntro: (_) async {
              writes++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('環境介紹讀取失敗'), findsOneWidget);
      expect(find.text('重新載入'), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'environment_load_error_${viewport.key}');
    });
  }
}
