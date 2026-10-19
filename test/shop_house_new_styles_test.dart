import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/models/shop_house_appearance.dart';
import 'package:petnest_saas/core/models/shop_house_local_assets.dart';
import 'package:petnest_saas/features/auth/widgets/shop_entry_panel.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('optional styles keep all warm defaults and cover nine placements', () {
    expect(ShopHousePlacements.known, hasLength(9));
    expect(ShopHouseLocalAsset.warmWoodEntries, hasLength(7));
    for (final style in ['romantic_garden', 'modern_japanese']) {
      final entries = ShopHouseLocalAsset.entries
          .where((e) => e.directory == style)
          .toList();
      expect(entries, hasLength(10));
      expect(
        entries.expand((e) => e.placements).toSet(),
        ShopHousePlacements.known.toSet(),
      );
      expect(entries.map((e) => e.fileName).toSet(), hasLength(10));
      expect(entries.where((e) => e.device == 'desktop'), hasLength(1));
      expect(entries.where((e) => e.device == 'phone'), hasLength(1));
      expect(entries.every((e) => e.displayName.isNotEmpty), isTrue);
    }
    expect(ShopHouseLocalAsset.defaultPath(ShopHousePlacements.wall), isNull);
    expect(
      ShopHouseLocalAsset.defaultPath(ShopHousePlacements.decorationTop),
      isNull,
    );
    expect(
      ShopHouseLocalAsset.defaultPath(ShopHousePlacements.roof),
      endsWith('warm_wood/roof_wide.png'),
    );
  });
  for (final style in ['romantic_garden', 'modern_japanese']) {
    for (final width in <double>[320, 390, 430, 1440]) {
      for (final useLogo in [true, false]) {
        testWidgets(
          '$style $width Logo=$useLogo real artwork fits existing house',
          (tester) async {
            final font = FontLoader('StylePreview')
              ..addFont(
                rootBundle.load(
                  'assets/fonts/NotoSansTC-VariableFont_wght.ttf',
                ),
              );
            await font.load();
            final signFont = FontLoader('NotoSerifTC')
              ..addFont(
                rootBundle.load(
                  'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
                ),
              );
            await signFont.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
            final entries = ShopHouseLocalAsset.entries
                .where((e) => e.directory == style)
                .toList();
            final networkBytes = <String, List<int>>{};
            final assets = <PlatformMediaAsset>[];
            var appearance = ShopHouseAppearance.empty;
            for (final entry in entries) {
              final bytes = (await rootBundle.load(
                entry.path,
              )).buffer.asUint8List();
              expect(bytes.length, lessThan(5 * 1024 * 1024));
              final codec = (await tester.runAsync(
                () => ui.instantiateImageCodec(bytes),
              ))!;
              final frame = (await tester.runAsync(
                () => codec.getNextFrame(),
              ))!;
              final image = frame.image;
              final url = 'https://example.invalid/styles/${entry.fileName}';
              networkBytes[url] = bytes;
              assets.add(
                PlatformMediaAsset.fromMap(entry.fileName, {
                  'name': entry.label,
                  'category': PlatformMediaCategories.shopHouse,
                  'placements': entry.placements,
                  'device': entry.device,
                  'enabled': true,
                  'imageUrl': url,
                  'sourceFileName': entry.fileName,
                  'width': image.width,
                  'height': image.height,
                  'fileBytes': bytes.length,
                }),
              );
              if (entry.device == 'phone') {
                appearance = appearance.copyWith(
                  roofPhoneAssetId: entry.fileName,
                );
              } else {
                appearance = appearance.withPlacement(
                  entry.placements.single,
                  entry.fileName,
                );
              }
              if (entry.placements.single == ShopHousePlacements.windowFrame) {
                final pixels = (await tester.runAsync(
                  () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
                ))!;
                for (
                  var y = (image.height * .20).round();
                  y < image.height * .75;
                  y += 8
                ) {
                  for (
                    var x = (image.width * .22).round();
                    x < image.width * .78;
                    x += 8
                  ) {
                    expect(
                      pixels.getUint8((y * image.width + x) * 4 + 3),
                      lessThan(17),
                      reason: 'Logo safe area $style ($x,$y)',
                    );
                  }
                }
              }
              if (entry.placements.single == ShopHousePlacements.roof) {
                final pixels = (await tester.runAsync(
                  () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
                ))!;
                for (
                  var y = (image.height * .84).round();
                  y < image.height * .95;
                  y += 8
                ) {
                  for (
                    var x = (image.width * .4).round();
                    x < image.width * .6;
                    x += 8
                  ) {
                    expect(
                      pixels.getUint8((y * image.width + x) * 4 + 3),
                      lessThan(17),
                      reason: 'Roof must not cover content: $style ($x,$y)',
                    );
                  }
                }
              }
              image.dispose();
              codec.dispose();
            }
            final logo = (await rootBundle.load(
              'assets/images/petnest_logo.png',
            )).buffer.asUint8List();
            networkBytes['https://example.invalid/style-logo.png'] = logo;
            debugNetworkImageHttpClientProvider = () =>
                _PhotoClient(logo, bytesByUrl: networkBytes);
            try {
              tester.view.physicalSize = Size(width, 2000);
              tester.view.devicePixelRatio = 1;
              final houseWidth = width >= 1100
                  ? (width - 56).clamp(0, 1400).toDouble()
                  : width - 32;
              final boundaryKey = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(fontFamily: 'StylePreview'),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: Center(
                        child: SizedBox(
                          width: houseWidth,
                          child: RepaintBoundary(
                            key: boundaryKey,
                            child: ShopEntryPanel(
                              shopName: useLogo ? 'PetNest 旅宿' : '貓咪旅宿',
                              shopId: 'STYLE_PREVIEW',
                              shopCode: 'STYLE_PREVIEW',
                              businessType: '貓咪旅館',
                              city: '新竹市',
                              district: '東區',
                              role: '店主',
                              coverUrl: '',
                              logoUrl: useLogo
                                  ? 'https://example.invalid/style-logo.png'
                                  : '',
                              isOpenNow: true,
                              isPublic: true,
                              enabledModules: const ['cat_hotel'],
                              openTime: '10:00',
                              closeTime: '20:00',
                              licenseNumber: '',
                              taxId: '',
                              updatedAt: null,
                              onEnter: () {},
                              onEditMedia: () {},
                              showDetails: false,
                              statsFuture: Future.value({
                                'pendingOrders': 2,
                                'transferUploadedOrders': 1,
                                'memberCount': 48,
                              }),
                              houseAppearance: appearance,
                              houseAssetsOverride: assets,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await _settleHouseImages(tester);
              final roof = tester.widget<Image>(
                find.byKey(const ValueKey('house-roof-remote')),
              );
              expect(
                (roof.image as NetworkImage).url,
                contains(width >= 1100 ? 'roof_wide' : 'roof_phone'),
              );
              expect(roof.fit, BoxFit.contain);
              expect(
                tester
                    .widget<Image>(
                      find.byKey(const ValueKey('house-base-remote')),
                    )
                    .centerSlice,
                isNotNull,
              );
              expect(
                find.byKey(const ValueKey('house-window-remote')),
                findsOneWidget,
              );
              expect(
                find.byKey(
                  ValueKey(useLogo ? 'shop-logo' : 'shop-library-default'),
                ),
                findsOneWidget,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: '$style $width Logo=$useLogo',
              );
              final previewDir = Platform.environment['PETNEST_STYLE_PREVIEW'];
              if (useLogo && previewDir != null) {
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                await tester.runAsync(() async {
                  final rendered = await boundary.toImage(pixelRatio: 1);
                  final data = (await rendered.toByteData(
                    format: ui.ImageByteFormat.png,
                  ))!;
                  await File(
                    '$previewDir/${style}_${width.toInt()}.png',
                  ).writeAsBytes(data.buffer.asUint8List());
                  rendered.dispose();
                });
              }
            } finally {
              debugNetworkImageHttpClientProvider = null;
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  }
}

class _PhotoClient implements HttpClient {
  _PhotoClient(this.bytes, {this.bytesByUrl = const {}});
  final Map<String, List<int>> bytesByUrl;
  final List<int> bytes;
  final List<Uri> requests = [];
  Uri? requested;
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    requests.add(url);
    return _PhotoRequest(bytesByUrl[url.toString()] ?? bytes, statusCode: 200);
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
