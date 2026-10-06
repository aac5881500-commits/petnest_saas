// 檔案名稱：test/explore_shop_card_test.dart
// 功能說明：確認探索店家精簡卡在手機與桌機寬度下不會溢出。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/compact_shop_card.dart';
import 'package:petnest_saas/features/platform/widgets/explore_section_header.dart';
import 'package:petnest_saas/features/platform/widgets/explore_sidebar.dart';
import 'package:petnest_saas/features/platform/widgets/my_shops_section.dart';

void main() {
  test('探索欄數依螢幕寬度', () {
    expect(exploreShopColumns(320), 2);
    expect(exploreShopColumns(899), 2);
    expect(exploreShopColumns(900), 3);
    expect(exploreShopColumns(1199), 3);
    expect(exploreShopColumns(1200), 4);
    expect(exploreShopColumns(1599), 4);
    expect(exploreShopColumns(1600), 5);
    expect(exploreShopColumns(1920), 5);
  });

  testWidgets('精簡店家卡在各寬度都放得下', (WidgetTester tester) async {
    const List<double> widths = <double>[
      320,
      360,
      390,
      430,
      768,
      900,
      1024,
      1440,
      1920,
    ];
    for (final double width in widths) {
      final bool roomy = width >= 900;
      final int columns = exploreShopColumns(width);
      final double pane = roomy
          ? (width - 56).clamp(0, 1200).toDouble()
          : width;
      final double imageAspect = roomy ? 1.72 : 1.65;
      await tester.binding.setSurfaceSize(Size(pane, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double aspect = compactShopCardAspectRatio(
                  gridWidth: constraints.maxWidth,
                  columns: columns,
                  textScale: MediaQuery.textScalerOf(context).scale(1),
                  imageAspect: imageAspect,
                  roomy: roomy,
                );
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: aspect,
                  ),
                  itemCount: 4,
                  itemBuilder: (BuildContext context, int index) {
                    return CompactShopCard(
                      name: '貓厝邊寵物旅宿名稱很長很長很長',
                      meta: const Text(
                        '尚無評價 · 台北市北投區',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      services: compactServiceLine(<String>[
                        '貓咪旅宿',
                        '安親',
                        '美容',
                        '醫院',
                        '賣場',
                      ]),
                      hours: index.isEven ? '10:00–20:00' : '',
                      roomy: roomy,
                      imageUrl: '',
                      logoUrl: '',
                      isOpen: index.isEven,
                      onTap: () {},
                      onFavorite: () {},
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '寬度 $width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('我的旅店列在窄螢幕不會溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyShopsSection(
            shops: <ExploreStayShop>[
              ExploreStayShop(
                shopId: 'shop-1',
                name: '貓厝邊',
                imageUrl: '',
                count: 3,
                latest: DateTime(2026, 9, 28),
              ),
            ],
            onOpen: (_) {},
            onBookAgain: (_) {},
            onViewAll: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('我的旅店'), findsOneWidget);
    expect(find.text('再次預約'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('會員面板在窄寬度不會溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreMemberPanel(
            onClose: () {},
            onMyStays: () {},
            onBookings: () {},
            onFavorites: () {},
            onRecent: () {},
            loggedIn: true,
            showRecentEmpty: true,
            stays: <ExploreStayShop>[
              ExploreStayShop(
                shopId: 'shop-1',
                name: '貓厝邊寵物旅宿名稱很長很長',
                imageUrl: '',
                count: 6,
                latest: DateTime(2026, 9, 28),
              ),
            ],
            onOpenStay: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('我的旅店'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);
    expect(find.text('你還沒有瀏覽過店家'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
