import 'package:petnest_saas/features/platform/widgets/explore_section_header.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/platform/widgets/explore_discovery_header.dart';
import 'package:petnest_saas/features/platform/widgets/compact_shop_card.dart';
import 'package:petnest_saas/features/platform/widgets/explore_sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> pump(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    VoidCallback? onMember,
    VoidCallback? onMap,
    ValueChanged<String>? onCategory,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader(
        'jfOpenHuninn',
      )..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: PetNestAppTheme.build().copyWith(
          textTheme: PetNestAppTheme.build().textTheme.apply(
            fontFamily: 'jfOpenHuninn',
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('explore-capture'),
          child: Scaffold(
            body: SafeArea(
              child: _Fixture(
                onMember: onMember ?? () {},
                onMap: onMap ?? () {},
                onCategory: onCategory ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 768.0, 900.0, 1440.0, 1920.0]) {
    testWidgets('discovery header and cards fit $width', (tester) async {
      await pump(tester, Size(width, 1100));
      expect(tester.takeException(), isNull);
      expect(
        find.text(width < 600 ? '為毛孩找到合適的店' : '為毛孩，找一間合適的好店'),
        findsOneWidget,
      );
      expect(find.text(width < 600 ? '全部服務' : '寵物賣場'), findsOneWidget);
      final output = const String.fromEnvironment('EXPLORE_PREVIEW_DIR');
      if (output.isNotEmpty && (width == 390 || width == 1440)) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('explore-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/explore_${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets(
    'phone shows shops sooner and every category remains selectable',
    (tester) async {
      String? selected;
      await pump(
        tester,
        const Size(390, 844),
        onCategory: (value) => selected = value,
      );
      final headerHeight = tester
          .getSize(find.byType(ExploreDiscoveryHeader))
          .height;
      expect(headerHeight, lessThan(300));
      expect(tester.getTopLeft(find.text('探索更多店家')).dy, lessThan(360));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('寵物賣場').last);
      await tester.pumpAndSettle();
      expect(selected, '寵物賣場');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large text can scroll without clipping', (tester) async {
    await pump(tester, const Size(320, 800), scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('search and category filters can be reset together', (
    tester,
  ) async {
    String? category;
    await pump(tester, const Size(768, 1100), onCategory: (v) => category = v);
    await tester.enterText(find.byType(TextField), '新竹');
    await tester.pumpAndSettle();
    expect(find.byTooltip('清除搜尋'), findsOneWidget);
    await tester.tap(find.text('貓咪旅宿').first);
    await tester.pumpAndSettle();
    expect(category, '貓咪旅宿');
    await tester.tap(find.text('只看營業中'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    await tester.tap(find.text('清除全部條件'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).selected,
      isFalse,
    );
    expect(find.text('清除全部條件'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('member and map actions remain accessible', (tester) async {
    var member = 0;
    var map = 0;
    await pump(
      tester,
      const Size(390, 1100),
      onMember: () => member++,
      onMap: () => map++,
    );
    await tester.tap(find.byTooltip('我的 PetNest／會員選單'));
    expect(member, 1);
    await tester.tap(find.byTooltip('依店家地址看地圖'));
    expect(map, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('result count identifies filtered and total shops', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExploreResultsHeading(count: 2, total: 6, filtered: true),
        ),
      ),
    );
    expect(find.text('符合條件的店家'), findsOneWidget);
    expect(find.text('找到 2 間 · 共 6 間公開店家'), findsOneWidget);
  });
}

class _Fixture extends StatefulWidget {
  const _Fixture({
    required this.onMember,
    required this.onMap,
    required this.onCategory,
  });
  final VoidCallback onMember, onMap;
  final ValueChanged<String> onCategory;
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  final search = TextEditingController();
  String category = '全部';
  bool open = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Row(
      children: [
        if (desktop)
          SizedBox(
            width: 56,
            child: ExploreMemberRail(
              onToggle: widget.onMember,
              onMyStays: () {},
              onBookings: () {},
              onFavorites: () {},
              onRecent: () {},
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final columns = exploreShopColumns(bounds.maxWidth);
                  final ratio = compactShopCardAspectRatio(
                    gridWidth: bounds.maxWidth,
                    columns: columns,
                    textScale: MediaQuery.textScalerOf(context).scale(1),
                    imageAspect: desktop ? 1.72 : 1.65,
                    roomy: desktop,
                  );
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: ExploreDiscoveryHeader(
                            search: search,
                            categories: const [
                              '全部',
                              '貓咪旅宿',
                              '狗狗旅宿',
                              '寵物美容',
                              '動物醫院',
                              '寵物賣場',
                            ],
                            category: category,
                            openOnly: open,
                            onSearch: () => setState(() {}),
                            onCategory: (value) {
                              setState(() => category = value);
                              widget.onCategory(value);
                            },
                            onOpenOnly: (value) => setState(() => open = value),
                            onReset: () => setState(() {
                              search.clear();
                              category = '全部';
                              open = false;
                            }),
                            onMap: widget.onMap,
                            onMember: widget.onMember,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                          child: ExploreResultsHeading(
                            count: 6,
                            total: 6,
                            filtered: false,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: ratio,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => CompactShopCard(
                              name: ['貓日子旅宿', '暖暖毛孩之家', '森林寵物美容'][index % 3],
                              meta: Text(
                                [
                                  '尚無評價 · 新竹市東區',
                                  '尚無評價 · 台北市北投區',
                                  '尚無評價 · 新北市板橋區',
                                ][index % 3],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              services: compactServiceLine(['貓咪旅宿', '寵物美容']),
                              hours: '09:00–18:00',
                              roomy: desktop,
                              imageUrl: '',
                              logoUrl: '',
                              isOpen: index.isEven,
                              onTap: () {},
                              onFavorite: () {},
                            ),
                            childCount: 6,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
