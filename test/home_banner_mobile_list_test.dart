// 檔案名稱：test/home_banner_mobile_list_test.dart
// 功能說明：手機海報卡集中在上方；桌機三欄可同時看到預覽、清單與設定。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_media_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StoreBannerModel banner({
    required String id,
    required String title,
    bool enabled = true,
    bool published = false,
  }) {
    return StoreBannerModel(
      id: id,
      title: title,
      enabled: enabled,
      renderedImageUrl: published ? 'https://example.com/$id.jpg' : '',
    );
  }

  Future<void> pumpList(
    WidgetTester tester, {
    required List<StoreBannerModel> banners,
    Size size = const Size(390, 844),
    bool omitLivePreview = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ShopMediaPage(
          key: ValueKey<String>('${size.width}-${banners.length}'),
          shopId: 'shop-1',
          seedBanners: banners,
          omitLivePreview: omitLivePreview,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('390px 海報卡較大並集中在上方', (WidgetTester tester) async {
    await pumpList(
      tester,
      banners: <StoreBannerModel>[banner(id: 'a', title: '寵物生活選品')],
    );

    expect(find.text('首頁活動海報'), findsNothing);
    expect(find.text('1. 選擇背景圖片'), findsNothing);
    expect(find.text('已建立的海報'), findsOneWidget);
    expect(find.text('長按拖曳可調整順序'), findsNothing);
    expect(find.text('點選可編輯海報內容'), findsOneWidget);
    expect(find.text('還可新增 4 張'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('home-banner-card-a'))).height,
      inInclusiveRange(108, 116),
    );
    expect(
      tester.getSize(find.byKey(const Key('home-banner-add-card'))).height,
      inInclusiveRange(84, 92),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('已停用'), findsOneWidget);
    expect(find.text('編輯活動海報'), findsNothing);

    await tester.tap(find.text('寵物生活選品'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('編輯活動海報'), findsOneWidget);
  });

  testWidgets('兩張可排序，五張隱藏新增卡且不 overflow', (WidgetTester tester) async {
    await pumpList(
      tester,
      banners: <StoreBannerModel>[
        banner(id: 'a', title: '海報甲', published: true),
        banner(id: 'b', title: ''),
      ],
    );
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(find.text('長按拖曳可調整順序'), findsOneWidget);
    expect(find.text('已發布'), findsOneWidget);
    expect(find.text('海報 2'), findsOneWidget);
    expect(find.text('還可新增 3 張'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpList(
      tester,
      size: const Size(390, 700),
      banners: <StoreBannerModel>[
        banner(id: 'a', title: '一', published: true),
        banner(id: 'b', title: '二'),
        banner(id: 'c', title: '三'),
        banner(id: 'd', title: '四', enabled: false),
        banner(id: 'e', title: '五'),
      ],
    );
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('新增活動海報'), findsNothing);
    expect(find.text('已停用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增活動海報會進入編輯頁', (WidgetTester tester) async {
    await pumpList(tester, banners: const <StoreBannerModel>[]);
    await tester.tap(find.text('新增活動海報'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('編輯活動海報'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1440px 左預覽、中清單、右設定同時可見', (WidgetTester tester) async {
    await pumpList(
      tester,
      size: const Size(1440, 900),
      omitLivePreview: true,
      banners: <StoreBannerModel>[
        banner(id: 'a', title: '寵物生活選品', published: true),
        banner(id: 'b', title: '第二張'),
      ],
    );

    expect(find.text('手機'), findsOneWidget);
    expect(find.text('正在編輯：寵物生活選品'), findsOneWidget);
    expect(find.text('發布海報'), findsOneWidget);
    expect(find.text('請選擇一張海報'), findsNothing);
    expect(find.text('第二張'), findsOneWidget);

    await tester.tap(find.text('第二張'));
    await tester.pump();
    expect(find.text('正在編輯：第二張'), findsOneWidget);
    expect(find.text('發布海報'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1200px 兩欄預覽與設定不 overflow', (WidgetTester tester) async {
    await pumpList(
      tester,
      size: const Size(1200, 800),
      omitLivePreview: true,
      banners: <StoreBannerModel>[
        banner(id: 'a', title: '寵物生活選品'),
        banner(id: 'b', title: '第二張'),
      ],
    );
    expect(find.text('正在編輯：寵物生活選品'), findsOneWidget);
    expect(find.text('發布海報'), findsOneWidget);
    expect(find.text('手機'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
