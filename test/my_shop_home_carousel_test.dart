import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_meta_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_stat_row.dart';
import 'package:petnest_saas/features/auth/widgets/shop_entry_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('today headline counts pending work, not members', () {
    expect(shopTodayHeadline(2, 1), '今天店裡有 3 件事情等你處理');
    expect(shopTodayHeadline(0, 0), '今天店裡一切順利');
    expect(shopTodayHeadline(0, 4), '今天店裡有 4 件事情等你處理');
    expect(shopTodaySubline(0, 0), '可以安心開始今天的工作。');
    expect(shopTodaySubline(1, 0), '看看有哪些事情需要留意。');
  });

  test('roof zone follows image ratio inside one shared range', () {
    expect(
      ShopEntryPanel.roofZoneHeight(
        availableWidth: 1120,
        wide: true,
        imageAspectRatio: 1120 / 150,
      ),
      closeTo(150, 0.01),
    );
    expect(
      ShopEntryPanel.roofZoneHeight(
        availableWidth: 390,
        wide: false,
        imageAspectRatio: 390 / 108,
      ),
      closeTo(108, 0.01),
    );
    expect(
      ShopEntryPanel.roofZoneHeight(
        availableWidth: 1120,
        wide: true,
        imageAspectRatio: 1.2,
      ),
      170,
    );
    expect(
      ShopEntryPanel.roofZoneHeight(
        availableWidth: 360,
        wide: false,
        imageAspectRatio: 40,
      ),
      90,
    );
    final double fallbackMobile = ShopEntryPanel.roofZoneHeight(
      availableWidth: 390,
      wide: false,
    );
    final double fallbackDesktop = ShopEntryPanel.roofZoneHeight(
      availableWidth: 1120,
      wide: true,
    );
    expect(fallbackMobile, inInclusiveRange(90, 130));
    expect(fallbackDesktop, inInclusiveRange(120, 170));
  });

  test('roof fit scale widens a narrow roof without passing 1.6', () {
    final double narrow = ShopEntryPanel.roofFitScaleX(
      houseWidth: 1120,
      roofHeight: 150,
      imageAspectRatio: 3,
      wide: true,
    );
    expect(narrow, ShopEntryPanel.maxRoofScaleX);
    final double fitted = ShopEntryPanel.roofFitScaleX(
      houseWidth: 1120,
      roofHeight: 150,
      imageAspectRatio: 1120 / 150,
      wide: true,
    );
    expect(fitted, closeTo(1.03, 0.01));
    final double mobile = ShopEntryPanel.roofFitScaleX(
      houseWidth: 390,
      roofHeight: 110,
      imageAspectRatio: 2.4,
      wide: false,
    );
    expect(mobile, inInclusiveRange(1, ShopEntryPanel.maxRoofScaleX));
    expect(
      ShopEntryPanel.roofFitScaleX(
        houseWidth: 1120,
        roofHeight: 150,
        imageAspectRatio: 0,
        wide: true,
      ),
      1,
    );
  });

  testWidgets('house hero fits phone and desktop widths', (
    WidgetTester tester,
  ) async {
    for (final double width in <double>[
      358,
      390,
      430,
      500,
      700,
      728,
      768,
      1024,
      1120,
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
      expect(tester.takeException(), isNull);
      expect(find.text('進入我的店'), findsOneWidget);
      expect(find.text('分享我的店'), findsOneWidget);
      expect(find.text('今天店裡'), findsOneWidget);
      expect(find.text('我的店家小檔案'), findsNothing);
      expect(find.text('你的店，從這裡開始'), findsOneWidget);
      expect(find.text('加入店家照片'), findsOneWidget);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    expect(find.text('你的店，從這裡開始'), findsOneWidget);
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
    expect(find.text('愛喵窩'), findsOneWidget);
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
}

ShopEntryPanel _hero({
  required String name,
  required bool hint,
  String shopId = 'SHOP0003',
}) {
  return ShopEntryPanel(
    shopName: name,
    shopId: shopId,
    shopCode: shopId,
    businessType: '貓咪旅館',
    city: '新竹縣新竹縣新竹縣',
    district: '新埔鎮新埔鎮新埔鎮新埔鎮',
    role: '店主',
    coverUrl: '',
    logoUrl: '',
    isOpenNow: true,
    isPublic: true,
    enabledModules: const <String>['cat_hotel'],
    openTime: '10:00',
    closeTime: '20:00',
    licenseNumber: 'A123',
    taxId: '12345678',
    updatedAt: null,
    showDetails: false,
    allowPhotoHint: hint,
    statsFuture: Future<Map<String, int>>.value(const <String, int>{
      'pendingOrders': 2,
      'transferUploadedOrders': 1,
      'memberCount': 2,
    }),
    onEnter: () {},
    onEditMedia: () {},
  );
}
