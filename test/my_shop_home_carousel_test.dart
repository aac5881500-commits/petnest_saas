import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/models/shop_house_appearance.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_media.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_card_media_page.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_qr_page.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_meta_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_stat_row.dart';
import 'package:petnest_saas/features/auth/widgets/shop_entry_panel.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('today headline counts pending work, not members', () {
    expect(shopTodayHeadline(2, 1), '今天店裡有 3 件事情等你處理');
    expect(shopTodayHeadline(0, 0), '今天店裡一切順利');
    expect(shopTodayHeadline(0, 4), '今天店裡有 4 件事情等你處理');
    expect(shopTodaySubline(0, 0), '可以安心開始今天的工作。');
    expect(shopTodaySubline(1, 0), '看看有哪些事情需要留意。');
  });

  test('platform roof scales with the house and keeps image aspect', () {
    const double imageWidth = 1200;
    const double imageHeight = 480;
    const double aspect = imageWidth / imageHeight;
    for (final double houseWidth in <double>[390, 430, 1280, 1440, 1920]) {
      final double height = ShopEntryPanel.platformRoofHeight(
        roofWidth: houseWidth,
        imageAspectRatio: aspect,
      );
      expect(height, houseWidth / aspect);
      expect(height * aspect, closeTo(houseWidth, 0.001));
    }
    expect(
      ShopEntryPanel.platformRoofHeight(
        roofWidth: 1440,
        imageAspectRatio: aspect,
      ),
      greaterThan(
        ShopEntryPanel.platformRoofHeight(
          roofWidth: 390,
          imageAspectRatio: aspect,
        ),
      ),
    );
    expect(
      ShopEntryPanel.platformRoofHeight(
        roofWidth: 800,
        imageAspectRatio: 1600 / 400,
      ),
      ShopEntryPanel.platformRoofHeight(
        roofWidth: 800,
        imageAspectRatio: 800 / 200,
      ),
    );
  });

  test('roof uses original aspect for desktop and mobile artwork', () {
    expect(
      ShopEntryPanel.roofZoneHeight(availableWidth: 390, wide: false),
      closeTo(390 / 3, .01),
    );
    expect(
      ShopEntryPanel.roofZoneHeight(availableWidth: 1120, wide: true),
      closeTo(1120 / 3, .01),
    );
    expect(
      ShopEntryPanel.roofZoneHeight(availableWidth: 1920, wide: true),
      greaterThan(
        ShopEntryPanel.roofZoneHeight(availableWidth: 768, wide: true),
      ),
    );
    expect(
      ShopEntryPanel.roofZoneHeight(availableWidth: 390, wide: false),
      lessThan(ShopEntryPanel.roofZoneHeight(availableWidth: 500, wide: false)),
    );
    expect(
      ShopEntryPanel.platformRoofHeight(roofWidth: 1120, imageAspectRatio: 4),
      280,
    );
    expect(
      ShopEntryPanel.platformRoofHeight(roofWidth: 390, imageAspectRatio: 3),
      130,
    );
    expect(
      ShopEntryPanel.platformRoofHeight(roofWidth: 1120, imageAspectRatio: 0),
      0,
    );
  });

  testWidgets('house hero fits phone and desktop widths', (
    WidgetTester tester,
  ) async {
    for (final double width in <double>[
      288,
      320,
      358,
      390,
      430,
      500,
      700,
      728,
      768,
      1024,
      1120,
      1280,
      1440,
      1366,
      1600,
      1920,
    ]) {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      final double height = ShopEntryPanel.heroHeightFor(width);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: height,
                child: _hero(name: '貓咪本舖貓咪本舖貓咪本舖很長的店名', hint: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'house width $width');
      expect(find.text('進入我的店'), findsOneWidget);
      expect(find.text('分享我的店'), findsOneWidget);
      expect(find.text('今天店裡'), findsOneWidget);
      expect(find.text('我的店家小檔案'), findsNothing);
      expect(find.byKey(const ValueKey('shop-default-cat')), findsOneWidget);
      expect(find.text('加入店家照片'), findsOneWidget);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('house actions keep entry callback and shop sharing route', (
    tester,
  ) async {
    int entered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: _hero(name: '木質小屋', hint: true, onEnter: () => entered++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('進入我的店'));
    await tester.tap(find.text('進入我的店'));
    expect(entered, 1);
    await tester.ensureVisible(find.text('分享我的店'));
    await tester.tap(find.text('分享我的店'));
    await tester.pumpAndSettle();
    expect(find.byType(MyShopQrPage), findsOneWidget);
    expect(
      tester.widget<MyShopQrPage>(find.byType(MyShopQrPage)).shopCode,
      'SHOP0003',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('house fits page padding at requested viewport sizes', (
    tester,
  ) async {
    final font = FontLoader('HousePreview')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    await font.load();
    final signFont = FontLoader('NotoSerifTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSerifTC-VariableFont_wght.ttf'),
      );
    await signFont.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final double width in <double>[320, 390, 430, 1280, 1440, 1920]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      final double houseWidth = width >= 1100
          ? (width - 56).clamp(0, 1400).toDouble()
          : width - 32;
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'HousePreview'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: houseWidth,
                  child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                      color: const Color(0xFFFFFCF6),
                      child: _hero(
                        name: '暖日・毛孩旅宿',
                        hint: true,
                        city: '新竹市',
                        district: '東區',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'viewport $width');
      final Rect house = tester.getRect(find.byKey(key));
      expect(house.left, greaterThanOrEqualTo(0));
      expect(house.right, lessThanOrEqualTo(width));
      expect(
        house.height,
        lessThanOrEqualTo(ShopEntryPanel.heroHeightFor(houseWidth)),
      );
      final String? preview = Platform.environment['PETNEST_HOUSE_PREVIEW'];
      if (preview != null) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$preview/house_${width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });

  testWidgets('empty window stays quiet without a photo action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: _hero(name: '貓咪本舖', hint: false)),
        ),
      ),
    );
    expect(find.text('加入店家照片'), findsNothing);
    expect(find.byKey(const ValueKey('shop-default-cat')), findsOneWidget);
  });

  testWidgets('uploaded photo keeps the original URL and media action', (
    tester,
  ) async {
    final bytes = (await rootBundle.load(
      ShopHouseArtwork.warmWood.defaultPhoto,
    )).buffer.asUint8List();
    const url = 'https://example.invalid/shop-uploaded-photo.png';
    final client = _PhotoClient(bytes);
    int edited = 0;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await HttpOverrides.runZoned(() async {
      await tester.runAsync(
        () => precacheImage(
          const NetworkImage(url),
          tester.element(find.byType(Scaffold)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _hero(
                name: '有照片的店家',
                hint: true,
                coverUrl: url,
                onEditMedia: () => edited++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.requested, Uri.parse(url));
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('shop-uploaded-photo')),
      );
      expect((image.image as NetworkImage).url, url);
      expect(find.byKey(const ValueKey('shop-default-cat')), findsNothing);
      expect(find.text('店家照片暫時無法載入'), findsNothing);
      await tester.ensureVisible(find.byTooltip('編輯照片'));
      await tester.tap(find.byTooltip('編輯照片'));
      expect(edited, 1);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets(
    'V2 logo fills the original frame without cropping or an upload overlay',
    (tester) async {
      final bytes = (await rootBundle.load(
        'assets/images/petnest_logo.png',
      )).buffer.asUint8List();
      final client = _PhotoClient(bytes);
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      try {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final family in <String>['HousePreview', 'NotoSerifTC']) {
          final font = FontLoader(family)
            ..addFont(
              rootBundle.load(
                family == 'HousePreview'
                    ? 'assets/fonts/NotoSansTC-VariableFont_wght.ttf'
                    : 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
              ),
            );
          await font.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        const logo = 'https://example.invalid/v2-shop-logo.png';
        const cover = 'https://example.invalid/v2-shop-cover.png';
        for (final width in <double>[320, 390, 430, 1280, 1440, 1920]) {
          tester.view.physicalSize = Size(width, 1400);
          tester.view.devicePixelRatio = 1;
          final houseWidth = width >= 1100
              ? (width - 56).clamp(0, 1400).toDouble()
              : width - 32;
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'HousePreview'),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: houseWidth,
                      child: RepaintBoundary(
                        key: key,
                        child: ColoredBox(
                          color: const Color(0xFFFFFCF6),
                          child: _hero(
                            name: 'PetNest 毛孩旅宿',
                            hint: true,
                            logoUrl: logo,
                            coverUrl: cover,
                            city: '新竹市',
                            district: '東區',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await _settleHouseImages(tester);
          final logoFinder = find.byKey(const ValueKey('shop-logo'));
          final image = tester.widget<Image>(logoFinder);
          expect((image.image as NetworkImage).url, logo);
          expect(image.fit, BoxFit.contain);
          expect(
            find.byKey(const ValueKey('shop-uploaded-photo')),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('shop-default-cat')), findsNothing);
          expect(find.text('加入店家照片'), findsNothing);
          expect(
            find.byKey(const ValueKey('house-window-artwork')),
            findsOneWidget,
          );
          final frame = tester.getRect(find.byType(ShopHouseDisplayWindow));
          final logoRect = tester.getRect(logoFinder);
          expect(frame.contains(logoRect.topLeft), isTrue);
          expect(frame.contains(logoRect.bottomRight), isTrue);
          final edit = tester.getRect(find.byTooltip('編輯照片'));
          expect(edit.top, greaterThanOrEqualTo(logoRect.bottom - 2));
          final enter = tester.getRect(
            find
                .ancestor(
                  of: find.text('進入我的店'),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is ButtonStyleButton,
                  ),
                )
                .first,
          );
          final share = tester.getRect(
            find
                .ancestor(
                  of: find.text('分享我的店'),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is ButtonStyleButton,
                  ),
                )
                .first,
          );
          if (width >= 1100) {
            expect(enter.center.dy, closeTo(share.center.dy, 1));
            expect(enter.width, greaterThan(180));
            expect(share.width, greaterThan(180));
          } else {
            expect(share.top, greaterThan(enter.bottom));
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('house-roof-artwork')))
                  .height,
              lessThanOrEqualTo(houseWidth * .34),
            );
          }
          final pending = tester.getRect(
            find.byKey(const ValueKey('my-shop-pending-stat')),
          );
          final transfer = tester.getRect(
            find.byKey(const ValueKey('my-shop-transfer-stat')),
          );
          final members = tester.getRect(
            find.byKey(const ValueKey('my-shop-member-stat')),
          );
          expect(transfer.width, closeTo(pending.width, .01));
          expect(members.width, closeTo(pending.width, .01));
          expect(transfer.height, pending.height);
          expect(members.height, pending.height);
          expect(find.byType(ErrorWidget), findsNothing);
          expect(
            tester.takeException(),
            isNull,
            reason: 'V2 logo viewport $width',
          );
          final preview = Platform.environment['PETNEST_HOUSE_PREVIEW'];
          if (preview != null) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$preview/house_v2_logo_${width.toInt()}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        expect(
          client.requests.any((request) => request.toString() == cover),
          isFalse,
        );
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  testWidgets(
    'V2 failed logo or photo falls back to the existing cat artwork',
    (tester) async {
      final bytes = (await rootBundle.load(
        'assets/images/petnest_logo.png',
      )).buffer.asUint8List();
      const badLogo = 'https://example.invalid/bad-logo.png';
      const badPhoto = 'https://example.invalid/bad-photo.png';
      final client = _PhotoClient(bytes, failedUrls: const {badLogo, badPhoto});
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      try {
        for (final useLogo in <bool>[true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: _hero(
                    name: '圖片暫時無法取得',
                    hint: true,
                    logoUrl: useLogo ? badLogo : '',
                    coverUrl: badPhoto,
                  ),
                ),
              ),
            ),
          );
          await _settleHouseImages(tester);
          expect(
            find.byKey(const ValueKey('shop-default-cat')),
            findsOneWidget,
          );
          expect(find.text('店家照片暫時無法載入'), findsNothing);
          expect(find.byType(ErrorWidget), findsNothing);
          expect(tester.takeException(), isNull);
        }
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  testWidgets('V2 switching shops replaces each shop logo in the same frame', (
    tester,
  ) async {
    final bytes = (await rootBundle.load(
      'assets/images/petnest_logo.png',
    )).buffer.asUint8List();
    debugNetworkImageHttpClientProvider = () => _PhotoClient(bytes);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    try {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: ShopEntryPanel.heroHeightFor(390),
              child: PageView(
                controller: controller,
                children: [
                  _hero(
                    name: '店家 A',
                    hint: true,
                    logoUrl: 'https://example.invalid/shop-a-logo.png',
                  ),
                  _hero(
                    name: '店家 B',
                    hint: true,
                    shopId: 'SHOP0004',
                    logoUrl: 'https://example.invalid/shop-b-logo.png',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settleHouseImages(tester);
      expect(
        (tester.widget<Image>(find.byKey(const ValueKey('shop-logo'))).image
                as NetworkImage)
            .url,
        'https://example.invalid/shop-a-logo.png',
      );
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      await _settleHouseImages(tester);
      expect(
        (tester.widget<Image>(find.byKey(const ValueKey('shop-logo'))).image
                as NetworkImage)
            .url,
        'https://example.invalid/shop-b-logo.png',
      );
      expect(
        find.byKey(const ValueKey('house-window-artwork')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('carousel measures natural house height without a blank gap', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in <double>[288, 358, 398, 1120, 1400]) {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      double height = ShopEntryPanel.heroHeightFor(width);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListView(
                children: [
                  SizedBox(
                    height: height,
                    child: PageView(
                      children: [
                        ShopHouseMeasuredBody(
                          onHeight: (value) {
                            if (height != value) setState(() => height = value);
                          },
                          child: _hero(name: '貓咪旅宿', hint: true),
                        ),
                      ],
                    ),
                  ),
                  const Text('小屋下方資訊', key: ValueKey('house-details')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final house = tester.getRect(find.byType(ShopHouseCourtyard));
      final details = tester.getRect(
        find.byKey(const ValueKey('house-details')),
      );
      expect(details.top, closeTo(house.bottom, .1));
      expect(tester.takeException(), isNull, reason: 'measured width $width');
    }
  });

  testWidgets('artwork keeps transparent window opening and complete assets', (
    tester,
  ) async {
    for (final path in <String>[
      ShopHouseArtwork.warmWood.roofWide,
      ShopHouseArtwork.warmWood.roofPhone,
      ShopHouseArtwork.warmWood.window,
      ShopHouseArtwork.warmWood.plants,
      ShopHouseArtwork.warmWood.base,
      ShopHouseArtwork.warmWood.defaultPhoto,
      ShopHouseCourtyard.assetPath,
    ]) {
      final bytes = await rootBundle.load(path);
      final codec = await tester.runAsync(
        () => ui.instantiateImageCodec(bytes.buffer.asUint8List()),
      );
      final frame = await tester.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, greaterThan(500));
      if (path == ShopHouseArtwork.warmWood.window) {
        final pixels = await tester.runAsync(() => frame.image.toByteData());
        final centerAlpha =
            ((frame.image.height ~/ 2) * frame.image.width +
                    frame.image.width ~/ 2) *
                4 +
            3;
        expect(pixels!.getUint8(centerAlpha), 0, reason: '照片展示窗必須真正透明');
      }
      frame.image.dispose();
      codec!.dispose();
    }
  });

  for (final failure in <String>['missing', 'empty', 'corrupt']) {
    testWidgets('house stays usable when artwork is $failure', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in <double>[320, 390, 430, 1440, 1920]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        int entered = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultAssetBundle(
              bundle: _BrokenHouseBundle(failure),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _hero(
                    name: '圖片失敗仍可使用的貓咪旅宿',
                    hint: true,
                    onEnter: () => entered++,
                  ),
                ),
              ),
            ),
          ),
        );
        final imageContext = tester.element(find.byType(ShopHouseScene));
        final configuration = createLocalImageConfiguration(imageContext);
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        await tester.runAsync(
          () => Future.wait(
            images.map((image) async {
              final settled = Completer<void>();
              final stream = image.image.resolve(configuration);
              final listener = ImageStreamListener(
                (_, _) {
                  if (!settled.isCompleted) settled.complete();
                },
                onError: (Object error, StackTrace? stack) {
                  if (!settled.isCompleted) settled.complete();
                },
              );
              stream.addListener(listener);
              await settled.future.timeout(const Duration(seconds: 10));
              stream.removeListener(listener);
            }),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('house-roof-fallback')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('house-window-fallback')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('house-base-fallback')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('house-photo-fallback')),
          findsOneWidget,
        );
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.textContaining('Unable to load asset'), findsNothing);
        final house = tester.getRect(find.byType(ShopHouseScene));
        expect(house.left, greaterThanOrEqualTo(0));
        expect(house.right, lessThanOrEqualTo(width));
        await tester.ensureVisible(find.text('進入我的店'));
        await tester.tap(find.text('進入我的店'));
        expect(entered, 1);
        await tester.ensureVisible(find.text('分享我的店'));
        await tester.tap(find.text('分享我的店'));
        await tester.pumpAndSettle();
        expect(find.byType(MyShopQrPage), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$failure at $width');
      }
    });
  }

  testWidgets('missing window decoration preserves the uploaded shop photo', (
    tester,
  ) async {
    final bytes = (await rootBundle.load(
      ShopHouseArtwork.warmWood.defaultPhoto,
    )).buffer.asUint8List();
    const url = 'https://example.invalid/photo-with-missing-frame.png';
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await HttpOverrides.runZoned(() async {
      await tester.runAsync(
        () => precacheImage(
          const NetworkImage(url),
          tester.element(find.byType(Scaffold)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _BrokenHouseBundle('missing'),
            child: Scaffold(
              body: SingleChildScrollView(
                child: _hero(name: '照片仍然保留', hint: true, coverUrl: url),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('house-window-fallback')),
        findsOneWidget,
      );
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('shop-uploaded-photo')),
      );
      expect((image.image as NetworkImage).url, url);
      expect(find.byKey(const ValueKey('house-photo-fallback')), findsNothing);
      expect(find.text('店家照片暫時無法載入'), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => _PhotoClient(bytes));
  });

  testWidgets('page view keeps a bounded height while swiping shops', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final PageController controller = PageController();
    addTearDown(controller.dispose);
    int current = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: ShopEntryPanel.heroHeightFor(390),
            child: PageView(
              controller: controller,
              onPageChanged: (int index) => current = index,
              children: <Widget>[
                _hero(name: '貓咪本舖', hint: false),
                _hero(name: '愛喵窩', hint: false, shopId: 'SHOP0004'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 800);
    await tester.pumpAndSettle();
    expect(current, 1);
    expect(find.text('愛喵窩'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop file keeps a long service list without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: SingleChildScrollView(
            child: MyShopMetaInfo(
              enabledModules: <String>[
                'cat_hotel',
                'dog_hotel',
                'grooming',
                'hospital',
                'store',
              ],
              openTime: '10:00',
              closeTime: '20:00',
              isPublic: true,
              licenseNumber: '很長的店家字號很長的店家字號',
              taxId: '12345678',
              updatedAt: null,
              city: '新竹縣新竹縣新竹縣',
              district: '新埔鎮新埔鎮新埔鎮新埔鎮',
              shopId: 'SHOP0003',
              businessType: '貓咪旅館',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('我的店家小檔案'), findsNothing);
    expect(find.text('店家編號 SHOP0003'), findsOneWidget);
    expect(find.textContaining('貓咪旅館'), findsWidgets);
    expect(find.text('營業時間'), findsOneWidget);
  });

  testWidgets(
    'garden and profile preserve all fields at phone and desktop sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = (await rootBundle.load(
        'assets/images/petnest_logo.png',
      )).buffer.asUint8List();
      debugNetworkImageHttpClientProvider = () => _PhotoClient(bytes);
      try {
        for (final width in <double>[320, 390, 430, 1280, 1440, 1920]) {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          final houseWidth = width >= 1100
              ? (width - 56).clamp(0, 1400).toDouble()
              : width - 32;
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'HousePreview'),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: houseWidth,
                      child: RepaintBoundary(
                        key: key,
                        child: ColoredBox(
                          color: const Color(0xFFF3F5ED),
                          child: _hero(
                            name: '暖日・毛孩旅宿',
                            hint: true,
                            logoUrl: 'https://example.invalid/garden-logo.png',
                            city: '新竹市',
                            district: '東區',
                            showDetails: true,
                            updatedAt: DateTime(2026, 10, 18, 12, 30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await _settleHouseImages(tester);
          expect(find.text('我的店家小檔案'), findsOneWidget);
          for (final label in <String>[
            '營業時間',
            '服務項目',
            '公開狀態',
            '店家字號',
            '統一編號',
            '地址',
          ]) {
            expect(find.text(label), findsOneWidget);
          }
          expect(find.text('10:00 - 20:00'), findsOneWidget);
          expect(find.text('A123'), findsOneWidget);
          expect(find.text('12345678'), findsOneWidget);
          expect(find.textContaining('2026/10/18 12:30'), findsOneWidget);
          expect(find.byKey(const ValueKey('shop-logo')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('house-window-artwork')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('house-courtyard-fallback')),
            findsNothing,
          );
          final first = tester.getRect(
            find.byKey(const ValueKey('shop-profile-field-0')),
          );
          final second = tester.getRect(
            find.byKey(const ValueKey('shop-profile-field-1')),
          );
          final third = tester.getRect(
            find.byKey(const ValueKey('shop-profile-field-2')),
          );
          if (width >= 1100) {
            expect(second.top, first.top);
            expect(third.top, first.top);
            expect(third.left, greaterThan(second.left));
          } else if (width >= 390) {
            expect(second.top, first.top);
            expect(third.top, greaterThan(first.bottom));
          } else {
            expect(second.top, greaterThan(first.bottom));
          }
          final courtyard = tester.getRect(find.byType(ShopHouseCourtyard));
          final profile = tester.getRect(find.byType(MyShopMetaInfo));
          expect(profile.top - courtyard.bottom, lessThan(100));
          final roof = tester.getRect(
            find.byKey(const ValueKey('house-roof-artwork')),
          );
          expect(courtyard.contains(roof.topLeft), isTrue);
          expect(courtyard.contains(roof.bottomRight), isTrue);
          expect(
            tester.getRect(find.byKey(key)).right,
            lessThanOrEqualTo(width),
          );
          expect(find.byType(ErrorWidget), findsNothing);
          expect(
            tester.takeException(),
            isNull,
            reason: 'garden/profile width $width',
          );
          final preview = Platform.environment['PETNEST_HOUSE_PREVIEW'];
          if (preview != null) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$preview/house_garden_${width.toInt()}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  testWidgets('profile shows unset values and keeps shop ID copying', (
    tester,
  ) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MyShopMetaInfo(
              enabledModules: [],
              openTime: '',
              closeTime: '',
              isPublic: false,
              licenseNumber: '',
              taxId: '',
              updatedAt: null,
              city: '',
              district: '',
              shopId: 'SHOP0012',
            ),
          ),
        ),
      ),
    );
    expect(find.text('尚未設定'), findsNWidgets(5));
    expect(find.text('最後更新 · 尚未設定'), findsOneWidget);
    expect(find.text('未公開'), findsOneWidget);
    await tester.ensureVisible(find.text('店家編號 SHOP0012'));
    await tester.tap(find.text('店家編號 SHOP0012'));
    await tester.pumpAndSettle();
    expect(copied, 'SHOP0012');
    expect(tester.takeException(), isNull);
  });
  test(
    'library placements round trip, disabled URLs and roof device fallbacks',
    () {
      expect(ShopHousePlacements.known.toSet(), hasLength(9));
      final revised = _libraryAsset('rev', ShopHousePlacements.roof).copyWith(
        imageUrl: 'https://example.invalid/roof.png?token=keep',
        updatedAt: DateTime(2026, 10, 19),
      );
      expect(Uri.parse(revised.houseImageUrl).queryParameters['token'], 'keep');
      expect(
        Uri.parse(revised.houseImageUrl).queryParameters['_petnestRev'],
        isNotEmpty,
      );
      var appearance = ShopHouseAppearance.empty;
      final assets = <PlatformMediaAsset>[];
      for (final placement in ShopHousePlacements.known) {
        appearance = appearance.withPlacement(placement, placement);
        assets.add(_libraryAsset(placement, placement));
      }
      appearance = appearance.copyWith(roofPhoneAssetId: 'phone');
      assets.add(
        _libraryAsset('phone', ShopHousePlacements.roof, device: 'phone'),
      );
      final reloaded = ShopHouseAppearance.fromMap(appearance.toMap());
      expect(reloaded.toMap(), appearance.toMap());
      final media = ShopHouseMedia(reloaded, assets);
      for (final placement in ShopHousePlacements.known) {
        expect(media.assetFor(placement)?.id, placement);
      }
      expect(
        media.assetFor(ShopHousePlacements.roof, wide: false)?.id,
        'phone',
      );
      final disabled = assets
          .map(
            (asset) =>
                asset.id == 'phone' ? asset.copyWith(enabled: false) : asset,
          )
          .toList();
      expect(
        ShopHouseMedia(
          reloaded,
          disabled,
        ).assetFor(ShopHousePlacements.roof, wide: false)?.id,
        ShopHousePlacements.roof,
      );
      expect(
        ShopHouseMedia(reloaded, [
          assets.first.copyWith(imageUrl: 'not-a-url'),
        ]).assetFor(ShopHousePlacements.roof),
        isNull,
      );
      expect(
        ShopHouseMedia(
          ShopHouseAppearance.empty,
          assets,
        ).assetFor(ShopHousePlacements.roof),
        isNull,
      );
      expect(
        PlatformMediaAsset.fromMap(
          'old',
          assets.first.toMap()..remove('device'),
        ).device,
        'any',
      );
    },
  );

  testWidgets(
    'all nine library layers render at 320 390 430 1440 and switch per shop',
    (tester) async {
      final bytes = (await rootBundle.load(
        ShopHouseArtwork.warmWood.defaultPhoto,
      )).buffer.asUint8List();
      final baseBytes = (await rootBundle.load(
        ShopHouseArtwork.warmWood.base,
      )).buffer.asUint8List();
      final client = _PhotoClient(
        bytes,
        bytesByUrl: {'https://example.invalid/house.base.png': baseBytes},
      );
      debugNetworkImageHttpClientProvider = () => client;
      try {
        var appearance = ShopHouseAppearance.empty;
        final assets = <PlatformMediaAsset>[];
        for (final placement in ShopHousePlacements.known) {
          appearance = appearance.withPlacement(placement, placement);
          assets.add(
            placement == ShopHousePlacements.base
                ? _libraryAsset(placement, placement).copyWith(
                    sourceFileName: 'base.png',
                    width: 2172,
                    height: 285,
                  )
                : _libraryAsset(placement, placement),
          );
        }
        appearance = appearance.copyWith(roofPhoneAssetId: 'phone');
        assets.add(
          _libraryAsset(
            'phone',
            ShopHousePlacements.roof,
            device: 'phone',
            width: 1681,
            height: 936,
          ),
        );
        for (final width in <double>[320, 390, 430, 1440]) {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: _hero(
                    name: '圖庫連動驗證長店名',
                    hint: false,
                    houseAppearance: appearance,
                    houseAssets: assets,
                  ),
                ),
              ),
            ),
          );
          await _settleHouseImages(tester);
          for (final key in [
            'house-roof-remote',
            'house-wall-remote',
            'house-window-remote',
            'house-base-remote',
            'house-courtyard-remote',
            'house-top-remote',
            'shop-library-default',
            ShopHousePlacements.decorationLeft,
            width >= 1000
                ? ShopHousePlacements.decorationRight
                : 'house-right-remote',
          ]) {
            expect(
              find.byKey(ValueKey(key)),
              findsOneWidget,
              reason: '$width $key',
            );
          }
          final roof = tester.widget<Image>(
            find.byKey(const ValueKey('house-roof-remote')),
          );
          expect(
            (roof.image as NetworkImage).url,
            contains(width >= 1000 ? ShopHousePlacements.roof : 'phone'),
          );
          expect(roof.fit, BoxFit.contain);
          final base = tester.widget<Image>(
            find.byKey(const ValueKey('house-base-remote')),
          );
          expect(base.centerSlice, ShopHouseArtwork.warmWood.baseCenterSlice);
          expect(base.fit, BoxFit.fill);
          expect(tester.takeException(), isNull, reason: '$width');
        }
        final other = _libraryAsset('other', ShopHousePlacements.windowFrame);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: _hero(
                  name: '另一間店',
                  shopId: 'OTHER',
                  hint: false,
                  houseAppearance: const ShopHouseAppearance(
                    windowFrameAssetId: 'other',
                  ),
                  houseAssets: [other],
                ),
              ),
            ),
          ),
        );
        await _settleHouseImages(tester);
        expect(
          (tester
                      .widget<Image>(
                        find.byKey(const ValueKey('house-window-remote')),
                      )
                      .image
                  as NetworkImage)
              .url,
          contains('other'),
        );
        expect(find.byKey(const ValueKey('house-roof-remote')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  testWidgets(
    'library network failures retain local artwork and logo photo priority',
    (tester) async {
      final bytes = (await rootBundle.load(
        ShopHouseArtwork.warmWood.defaultPhoto,
      )).buffer.asUint8List();
      final assets = [
        for (final placement in ShopHousePlacements.known)
          _libraryAsset('failure-$placement', placement),
      ];
      var appearance = ShopHouseAppearance.empty;
      for (final asset in assets) {
        appearance = appearance.withPlacement(
          asset.placements.single,
          asset.id,
        );
      }
      final client = _PhotoClient(
        bytes,
        failedUrls: {
          for (final asset in assets) asset.imageUrl,
          'https://example.invalid/logo-bad.png',
        },
      );
      debugNetworkImageHttpClientProvider = () => client;
      try {
        tester.view.physicalSize = const Size(1440, 1600);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: _hero(
                  name: '回退測試',
                  hint: false,
                  houseAppearance: appearance,
                  houseAssets: assets,
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await _settleHouseImages(tester);
        }
        for (final key in [
          'house-roof-artwork',
          'house-window-artwork',
          'house-base-artwork',
          'house-courtyard-background',
          'shop-default-cat',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget);
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: _hero(
                  name: 'Logo 順序',
                  hint: false,
                  logoUrl: 'https://example.invalid/logo-bad.png',
                  fallbackLogoUrl: 'https://example.invalid/basic-logo.png',
                  coverUrl: 'https://example.invalid/photo.png',
                  houseAppearance: appearance,
                  houseAssets: assets,
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await _settleHouseImages(tester);
        }
        final logos = tester
            .widgetList<Image>(find.byKey(const ValueKey('shop-logo')))
            .toList();
        expect(
          (logos.last.image as NetworkImage).url,
          'https://example.invalid/basic-logo.png',
        );
        expect(logos.last.fit, BoxFit.contain);
        expect(find.byKey(const ValueKey('shop-uploaded-photo')), findsNothing);
        expect(
          find.byKey(const ValueKey('house-window-artwork')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  testWidgets(
    'settings save, reload and reset use the same appearance IDs without Firebase',
    (tester) async {
      final bytes = (await rootBundle.load(
        ShopHouseArtwork.warmWood.defaultPhoto,
      )).buffer.asUint8List();
      debugNetworkImageHttpClientProvider = () => _PhotoClient(bytes);
      final roof = _libraryAsset(
        'selected-roof',
        ShopHousePlacements.roof,
        device: 'desktop',
      );
      Map<String, dynamic> saved = {};
      var saveCount = 0;
      Widget page(int revision) => MaterialApp(
        home: MyShopCardMediaPage(
          key: ValueKey(revision),
          shopId: 'TEST',
          houseAppearance: saved,
          houseAssetsOverride: [roof],
          saveHouseAppearance: (value) async {
            saved = value.toMap();
            saveCount++;
          },
        ),
      );
      try {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(page(0));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('屋頂（桌機）'), 250);
        final row = find
            .ancestor(of: find.text('屋頂（桌機）'), matching: find.byType(Row))
            .first;
        await tester.tap(find.descendant(of: row, matching: find.text('更換')));
        await tester.pumpAndSettle();
        expect(find.text('selected-roof'), findsOneWidget);
        await tester.tap(find.text('selected-roof'));
        await tester.pump();
        await tester.tap(find.text('套用'));
        await tester.pumpAndSettle();
        expect(saved['roofAssetId'], 'selected-roof');
        expect(saveCount, 1);
        await tester.pumpWidget(page(1));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('屋頂（桌機）'), 250);
        expect(find.text('目前：selected-roof'), findsOneWidget);
        final reloadedRow = find
            .ancestor(of: find.text('屋頂（桌機）'), matching: find.byType(Row))
            .first;
        await tester.tap(
          find.descendant(of: reloadedRow, matching: find.byTooltip('恢復預設')),
        );
        await tester.pumpAndSettle();
        expect(saved['roofAssetId'], isEmpty);
        expect(saveCount, 2);
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );
}

ShopEntryPanel _hero({
  required String name,
  required bool hint,
  String shopId = 'SHOP0003',
  VoidCallback? onEnter,
  String coverUrl = '',
  VoidCallback? onEditMedia,
  String logoUrl = '',
  String fallbackLogoUrl = '',
  ShopHouseAppearance houseAppearance = ShopHouseAppearance.empty,
  List<PlatformMediaAsset>? houseAssets,
  String city = '新竹縣新竹縣新竹縣',
  String district = '新埔鎮新埔鎮新埔鎮新埔鎮',
  bool showDetails = false,
  DateTime? updatedAt,
}) {
  return ShopEntryPanel(
    shopName: name,
    houseAppearance: houseAppearance,
    houseAssetsOverride: houseAssets,
    fallbackLogoUrl: fallbackLogoUrl,
    shopId: shopId,
    shopCode: shopId,
    businessType: '貓咪旅館',
    city: city,
    district: district,
    role: '店主',
    coverUrl: coverUrl,
    logoUrl: logoUrl,
    isOpenNow: true,
    isPublic: true,
    enabledModules: const <String>['cat_hotel'],
    openTime: '10:00',
    closeTime: '20:00',
    licenseNumber: 'A123',
    taxId: '12345678',
    updatedAt: updatedAt,
    showDetails: showDetails,
    allowPhotoHint: hint,
    statsFuture: Future<Map<String, int>>.value(const <String, int>{
      'pendingOrders': 2,
      'transferUploadedOrders': 1,
      'memberCount': 2,
    }),
    onEnter: onEnter ?? () {},
    onEditMedia: onEditMedia ?? () {},
  );
}

class _PhotoClient implements HttpClient {
  _PhotoClient(
    this.bytes, {
    this.failedUrls = const {},
    this.bytesByUrl = const {},
  });
  final Map<String, List<int>> bytesByUrl;
  final List<int> bytes;
  final Set<String> failedUrls;
  final List<Uri> requests = [];
  Uri? requested;
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    requests.add(url);
    return _PhotoRequest(
      bytesByUrl[url.toString()] ?? bytes,
      statusCode: failedUrls.contains(url.toString()) ? 404 : 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenHouseBundle extends CachingAssetBundle {
  _BrokenHouseBundle(this.failure);
  final String failure;

  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('assets/images/shop_house/')) {
      return rootBundle.load(key);
    }
    if (failure == 'empty') return ByteData(0);
    if (failure == 'corrupt') {
      return ByteData.sublistView(Uint8List.fromList(<int>[1, 2, 3]));
    }
    throw FlutterError('Unable to load asset: $key');
  }
}

class _PhotoRequest implements HttpClientRequest {
  _PhotoRequest(this.bytes, {this.statusCode = 200});
  final List<int> bytes;
  final int statusCode;
  @override
  Future<HttpClientResponse> close() async =>
      _PhotoResponse(bytes, statusCode: statusCode);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  _PhotoResponse(this.bytes, {this.statusCode = 200});
  final List<int> bytes;
  @override
  final int statusCode;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settleHouseImages(WidgetTester tester) async {
  final configuration = createLocalImageConfiguration(
    tester.element(find.byType(ShopHouseScene).first),
  );
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(
    () => Future.wait(
      images.map((image) async {
        final completed = Completer<void>();
        final stream = image.image.resolve(configuration);
        final listener = ImageStreamListener(
          (_, _) {
            if (!completed.isCompleted) completed.complete();
          },
          onError: (Object error, StackTrace? stack) {
            if (!completed.isCompleted) completed.complete();
          },
        );
        stream.addListener(listener);
        await completed.future.timeout(const Duration(seconds: 10));
        stream.removeListener(listener);
      }),
    ),
  );
  await tester.pumpAndSettle();
}

PlatformMediaAsset _libraryAsset(
  String id,
  String placement, {
  String device = 'any',
  int width = 1200,
  int height = 400,
}) => PlatformMediaAsset.fromMap(id, {
  'name': id,
  'category': PlatformMediaCategories.shopHouse,
  'placements': [placement],
  'imageUrl': 'https://example.invalid/$id.png',
  'enabled': true,
  'device': device,
  'width': width,
  'height': height,
});
