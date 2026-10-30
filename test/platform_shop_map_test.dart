import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_map_location.dart';
import 'package:petnest_saas/features/platform/models/public_map_shop.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_map_page.dart';

PublicMapShop shop(
  String id, {
  bool public = true,
  ShopMapLocation? point = const ShopMapLocation(25, 121),
  bool open = true,
}) => PublicMapShop(
  id: id,
  name: '店家$id',
  address: '新竹市東區測試路',
  area: '新竹市東區',
  imageUrl: '',
  services: const ['貓咪旅宿'],
  isOpen: open,
  isPublic: public,
  location: point,
);
void main() {
  test(
    'coordinate validation rejects missing, unconfirmed and nonfinite values',
    () {
      expect(
        ShopMapLocation.fromMap({'latitude': 25, 'longitude': 121}),
        isNull,
      );
      expect(ShopMapLocation.parse(double.nan, 121), isNull);
      expect(ShopMapLocation.parse(91, 121), isNull);
      expect(ShopMapLocation.parse(25, -181), isNull);
      expect(
        ShopMapLocation.fromMap({
          'confirmed': true,
          'latitude': 25,
          'longitude': 121,
        })?.longitude,
        121,
      );
    },
  );
  test(
    'filters exclude private shops and respect bounds, services and opening',
    () {
      final data = [
        shop('public'),
        shop('private', public: false),
        shop('missing', point: null),
        shop('closed', open: false),
        shop('far', point: const ShopMapLocation(22, 120)),
      ];
      expect(filterMapShops(data).any((s) => s.id == 'private'), isFalse);
      expect(
        filterMapShops(data, bounds: [24, 120.5, 26, 122]).map((s) => s.id),
        ['public', 'closed'],
      );
      expect(
        filterMapShops(data, openOnly: true).any((s) => s.id == 'closed'),
        isFalse,
      );
      expect(filterMapShops(data, category: '寵物美容'), isEmpty);
      expect(const ShopMapLocation(0, 179).within(-1, 170, 1, -170), isTrue);
    },
  );
  Future<void> pump(
    WidgetTester tester,
    Size size,
    Stream<List<PublicMapShop>> stream, {
    double scale = 1,
    Future<void> Function(String)? onOpen,
    bool preview = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: PlatformShopMapPage(
          shops: stream,
          onOpenShop: onOpen ?? (_) async {},
          mapPreviewBuilder: preview
              ? (shops, onSelect) => ColoredBox(
                  color: Colors.blueGrey.shade50,
                  child: Center(
                    child: Wrap(
                      children: [
                        for (final s in shops)
                          TextButton(
                            key: ValueKey('pin-${s.id}'),
                            onPressed: () => onSelect(s.id),
                            child: Text('標記${s.id}'),
                          ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('map and list fit $width without a network map', (
      tester,
    ) async {
      await pump(
        tester,
        Size(width, 844),
        Stream.value([
          shop('s1'),
          shop('s2', point: null),
          shop('private', public: false),
        ]),
      );
      expect(find.byKey(const ValueKey('pin-s1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-private')), findsNothing);
      expect(find.text('店家private'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('pin-s1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'unpublishing removes both marker and selected card immediately',
    (tester) async {
      final stream = StreamController<List<PublicMapShop>>();
      addTearDown(stream.close);
      stream.add([shop('s1')]);
      await pump(tester, const Size(390, 844), stream.stream);
      await tester.tap(find.byKey(const ValueKey('pin-s1')));
      await tester.pumpAndSettle();
      expect(find.text('店家s1'), findsOneWidget);
      stream.add([shop('s1', public: false)]);
      await tester.pumpAndSettle();
      expect(find.text('店家s1'), findsNothing);
      expect(find.byKey(const ValueKey('pin-s1')), findsNothing);
    },
  );
  testWidgets('missing key keeps public list usable', (tester) async {
    String? opened;
    await pump(
      tester,
      const Size(390, 844),
      Stream.value([shop('s1')]),
      preview: false,
      onOpen: (id) async {
        opened = id;
      },
    );
    expect(find.text('地圖服務尚未啟用'), findsOneWidget);
    await tester.tap(find.text('進入店家').first);
    await tester.pumpAndSettle();
    expect(opened, 's1');
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text and selected shop remain scrollable', (tester) async {
    await pump(
      tester,
      const Size(320, 800),
      Stream.value([shop('s1')]),
      scale: 1.5,
    );
    await tester.tap(find.byKey(const ValueKey('pin-s1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
