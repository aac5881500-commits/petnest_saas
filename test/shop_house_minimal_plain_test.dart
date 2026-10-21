import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/models/shop_house_appearance.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_card_media_page.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_qr_page.dart';
import 'package:petnest_saas/features/auth/widgets/shop_entry_panel.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_media.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_mode_selector.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_scene.dart';

ShopHouseAppearance _appearance(String prefix) => ShopHouseAppearance(
  roofAssetId: '$prefix-roof',
  roofPhoneAssetId: '$prefix-phone',
  wallAssetId: '$prefix-wall',
  windowFrameAssetId: '$prefix-window',
  decorationLeftAssetId: '$prefix-left',
  decorationRightAssetId: '$prefix-right',
  decorationTopAssetId: '$prefix-top',
  baseAssetId: '$prefix-base',
  sceneBackgroundAssetId: '$prefix-scene',
  defaultPhotoAssetId: '$prefix-photo',
);

ShopEntryPanel _panel(
  ShopHouseAppearance appearance, {
  String cover = '',
  String logo = '',
  VoidCallback? enter,
  bool edit = false,
  VoidCallback? onEdit,
  List<PlatformMediaAsset>? assets,
}) => ShopEntryPanel(
  shopName: '暖日・貓咪旅宿',
  shopId: 'SHOP0003',
  shopCode: 'SHOP0003',
  businessType: '貓咪旅館',
  city: '新竹市',
  district: '東區',
  role: '店主',
  coverUrl: cover,
  logoUrl: logo,
  isOpenNow: true,
  isPublic: true,
  enabledModules: const ['cat_hotel'],
  openTime: '10:00',
  closeTime: '20:00',
  licenseNumber: '',
  taxId: '',
  updatedAt: null,
  onEnter: enter ?? () {},
  onEditMedia: onEdit ?? () {},
  allowPhotoHint: edit,
  showDetails: false,
  statsFuture: Future.value({
    'pendingOrders': 2,
    'transferUploadedOrders': 1,
    'memberCount': 48,
  }),
  houseAppearance: appearance,
  houseAssetsOverride: assets,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy stays house; toggling mode and serialization preserve all ten image IDs',
    () {
      expect(ShopHouseAppearance.fromMap({}).isMinimalPlain, isFalse);
      for (final prefix in ['warm', 'romantic_garden', 'modern_japanese']) {
        final original = _appearance(prefix);
        final plain = ShopHouseAppearance.fromMap(
          original.copyWith(mode: ShopHouseAppearance.minimalPlainMode).toMap(),
        );
        expect(plain.isMinimalPlain, isTrue);
        expect(plain.selectedIds.toList(), original.selectedIds.toList());
        expect(
          plain.copyWith(mode: ShopHouseAppearance.houseMode).toMap(),
          original.toMap(),
        );
      }
    },
  );

  for (final width in <double>[320, 390, 430, 1440]) {
    testWidgets(
      'plain $width has no decorative tree, queries or reserved height',
      (tester) async {
        for (final family in ['MinimalPreview', 'NotoSerifTC']) {
          final font = FontLoader(family)
            ..addFont(
              rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
            );
          await font.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        // Non-empty asset IDs with no Firebase initialization prove decoration reads are bypassed.
        final appearance = _appearance(
          'saved',
        ).copyWith(mode: ShopHouseAppearance.minimalPlainMode);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'MinimalPreview'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: _panel(appearance),
                  ),
                ),
              ),
            ),
          ),
        );
        await _settleHouseImages(tester);
        expect(find.byType(ShopHouseScene), findsNothing);
        expect(find.byType(ShopHouseCourtyard), findsNothing);
        expect(find.byType(ShopHouseDecoration), findsNothing);
        expect(find.byType(ShopHouseMediaBuilder), findsNothing);
        for (final key in [
          'house-window-artwork',
          'house-window-remote',
          'house-base-artwork',
          'house-roof-artwork',
        ]) {
          expect(find.byKey(ValueKey(key)), findsNothing);
        }
        expect(find.text('店家編號 SHOP0003'), findsOneWidget);
        expect(find.text('48'), findsOneWidget);
        expect(find.text('今天店裡'), findsOneWidget);
        final card = tester.getRect(
          find.byKey(const ValueKey('minimal-plain-card')),
        );
        final photo = tester.getRect(find.byType(ShopHouseDisplayWindow));
        expect(photo.top - card.top, lessThan(32));
        expect(card.height, lessThan(width >= 1000 ? 650 : 1000));
        final title = tester.getRect(find.text('暖日・貓咪旅宿'));
        expect(
          width >= 1000 ? title.left > photo.right : title.top > photo.bottom,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['PETNEST_PLAIN_PREVIEW'];
        if (directory != null) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$directory/plain_${width.toInt()}.png',
            ).writeAsBytes(data.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }

  testWidgets(
    'plain photo first, logo contain fallback, owner edit and entry/share remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = (await rootBundle.load(
        'assets/images/petnest_logo.png',
      )).buffer.asUint8List();
      debugNetworkImageHttpClientProvider = () => _PhotoClient(bytes);
      var entered = 0, edited = 0;
      final plain = _appearance(
        'saved',
      ).copyWith(mode: ShopHouseAppearance.minimalPlainMode);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: _panel(
                  plain,
                  cover: 'https://example.invalid/photo.png',
                  logo: 'https://example.invalid/logo.png',
                  edit: true,
                  enter: () => entered++,
                  onEdit: () => edited++,
                ),
              ),
            ),
          ),
        );
        await _settleHouseImages(tester);
        expect(
          tester
              .widget<Image>(find.byKey(const ValueKey('shop-uploaded-photo')))
              .fit,
          BoxFit.cover,
        );
        expect(find.byKey(const ValueKey('shop-logo')), findsNothing);
        await tester.tap(find.byTooltip('編輯照片'));
        await tester.pump();
        expect(edited, 1);
        await tester.tap(find.text('進入我的店'));
        await tester.pump();
        expect(entered, 1);
        await tester.tap(find.text('分享我的店'));
        await tester.pumpAndSettle();
        expect(find.byType(MyShopQrPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: _panel(plain, logo: 'https://example.invalid/logo.png'),
              ),
            ),
          ),
        );
        await _settleHouseImages(tester);
        expect(
          tester.widget<Image>(find.byKey(const ValueKey('shop-logo'))).fit,
          BoxFit.contain,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  for (final prefix in ['warm', 'romantic_garden', 'modern_japanese']) {
    testWidgets(
      '$prefix settings apply, reload and switch back preserve image choices',
      (tester) async {
        var saved = _appearance(prefix).toMap();
        var saves = 0;
        Widget page(int revision) => MaterialApp(
          home: MyShopCardMediaPage(
            key: ValueKey(revision),
            shopId: 'TEST',
            houseAppearance: saved,
            houseAssetsOverride: const [],
            saveHouseAppearance: (value) async {
              saved = value.toMap();
              saves++;
            },
          ),
        );
        final original = Map<String, dynamic>.from(saved);
        await tester.pumpWidget(page(0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('select-house-mode-minimal_plain')),
        );
        await tester.pump();
        expect(saves, 0);
        await tester.ensureVisible(
          find.byKey(const ValueKey('apply-house-mode')),
        );
        await tester.tap(find.byKey(const ValueKey('apply-house-mode')));
        await tester.pumpAndSettle();
        expect(saved['mode'], 'minimal_plain');
        expect(saves, 1);
        await tester.pumpWidget(page(1));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ShopHouseModeSelector>(find.byType(ShopHouseModeSelector))
              .mode,
          'minimal_plain',
        );
        await tester.tap(find.byKey(const ValueKey('select-house-mode-house')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('apply-house-mode')));
        await tester.pumpAndSettle();
        expect(saves, 2);
        expect(saved, original);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _PhotoClient implements HttpClient {
  _PhotoClient(this.bytes);
  final List<int> bytes;
  final List<Uri> requests = [];
  Uri? requested;
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    requests.add(url);
    return _PhotoRequest(bytes, statusCode: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    tester.element(find.byType(ShopEntryPanel).first),
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
