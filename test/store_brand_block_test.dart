import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editable_home_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_block.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_editor_overlay.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_settings_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

void main() {
  const HomeThemeModel theme = HomeThemeModel(
    backgroundColorValue: 0xFFFFFBF7,
    cardColorValue: 0xFFFFFFFF,
    cardBorderColorValue: 0xFFFFD9B3,
    primaryColorValue: 0xFFFF8A00,
    textColorValue: 0xFF3A2A20,
  );

  test('old brand data clamps fonts and keeps unused y', () {
    final StoreBrandStyle missing = StoreBrandStyle.fromMap(<String, dynamic>{
      'headerSubtitle': '溫暖的家',
    });
    expect(missing.x, 0.5);
    expect(missing.y, 0);
    expect(missing.markType, 'builtinIcon');
    expect(missing.nameFontSize, 18);
    expect(missing.subtitleFontSize, 12);

    final StoreBrandStyle withLogo = StoreBrandStyle.fromMap(<String, dynamic>{
      'homepageBrandLogoPlacement': 'leading',
    }, logoUrl: 'https://example.com/logo.png');
    expect(withLogo.markType, 'logo');

    final StoreBrandStyle iconOnly = StoreBrandStyle.fromMap(<String, dynamic>{
      'showLeftHeaderIcon': false,
      'showRightHeaderIcon': true,
      'rightHeaderIcon': 'star',
    });
    expect(iconOnly.markType, 'builtinIcon');
    expect(iconOnly.logoPlacement, 'trailing');
    expect(iconOnly.fallbackIcon, 'star');

    final StoreBrandStyle hidden = StoreBrandStyle.fromMap(<String, dynamic>{
      'homepageBrandLogoPlacement': 'none',
    }, logoUrl: 'https://example.com/logo.png');
    expect(hidden.markType, 'none');

    final StoreBrandStyle saved = StoreBrandStyle.fromMap(<String, dynamic>{
      'homepageBrandX': 0.2,
      'homepageBrandY': 0.4,
      'homepageBrandWidthRatio': 2,
      'homepageBrandMarkType': 'builtinIcon',
      'homepageBrandNameFontSize': 80,
      'homepageBrandSubtitleFontSize': 4,
    });
    expect(saved.x, 0.2);
    expect(saved.y, 0.4);
    expect(saved.widthRatio, 1);
    expect(saved.nameFontSize, 20);
    expect(saved.subtitleFontSize, 10);
    expect(saved.toMap()['homepageBrandY'], 0.4);
    expect(saved.toMap()['homepageBrandNameFontSize'], 20);
    expect(saved.toMap()['homepageBrandSubtitleFontSize'], 10);
  });

  test('horizontal position round-trips and ignores vertical travel', () {
    const double left = 36;
    final double x = StoreBrandGeometry.normalizeX(
      left: left,
      laneWidth: 300,
      contentWidth: 120,
    );
    expect(
      StoreBrandGeometry.leftFor(laneWidth: 300, contentWidth: 120, x: x),
      closeTo(left, 0.001),
    );
    expect(
      StoreBrandGeometry.leftFor(laneWidth: 300, contentWidth: 300, x: 1),
      0,
    );
  });

  testWidgets('dragging moves horizontally and does not jump on release', (
    WidgetTester tester,
  ) async {
    StoreBrandStyle style = const StoreBrandStyle(
      x: 0.2,
      y: 0.7,
      markType: 'none',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: 320,
                child: StoreBrandLane(
                  style: style,
                  shopName: '店',
                  subtitle: '',
                  logoUrl: '',
                  theme: theme,
                  editable: true,
                  onChanged: (StoreBrandStyle next) {
                    setState(() => style = next);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder name = find.text('店');
    final Offset start = tester.getTopLeft(name);
    final TestGesture gesture = await tester.startGesture(
      start + const Offset(4, 4),
    );
    await gesture.moveBy(const Offset(48, 30));
    await tester.pump();
    final Offset moved = tester.getTopLeft(name);
    expect(moved.dx, greaterThan(start.dx + 20));
    expect(moved.dy, closeTo(start.dy, 1));

    await gesture.up();
    await tester.pump();
    final Offset released = tester.getTopLeft(name);
    expect(released.dx, closeTo(moved.dx, 1));
    expect(released.dy, closeTo(moved.dy, 1));
    expect(style.y, 0.7);
    expect(style.x, greaterThan(0.2));
    expect(
      find.byKey(const ValueKey<String>('store-brand-handle-left')),
      findsNothing,
    );
  });

  testWidgets(
    'brand row sits above the next section and keeps one home block',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: Column(
                children: <Widget>[
                  const StoreBrandTopBar(
                    style: StoreBrandStyle(markType: 'none', nameFontSize: 20),
                    shopName: '很長的店家名稱需要換成兩行',
                    subtitle: '副標也跟著換行但是不蓋住海報',
                    logoUrl: '',
                    theme: theme,
                    backgroundColor: Color(0xFFFFFBF7),
                  ),
                  const Text('海報'),
                  const SizedBox(
                    width: 200,
                    child: StoreBrandBlock(
                      contextKind: StoreBrandDisplayContext.drawer,
                      style: StoreBrandStyle(markType: 'builtinIcon'),
                      shopName: '抽屜店名',
                      subtitle: '',
                      logoUrl: '',
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('海報')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('副標也跟著換行但是不蓋住海報')).dy,
        ),
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is StoreBrandBlock &&
              widget.contextKind == StoreBrandDisplayContext.home,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is StoreBrandBlock &&
              widget.contextKind == StoreBrandDisplayContext.drawer,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('brand settings card fits a narrow phone width', (
    WidgetTester tester,
  ) async {
    final TextEditingController subtitle = TextEditingController(text: '副標');
    addTearDown(subtitle.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ListView(
              children: <Widget>[
                StoreBrandSettingsCard(
                  style: const StoreBrandStyle(
                    markType: 'logo',
                    nameFontSize: 20,
                    subtitleFontSize: 18,
                  ),
                  theme: theme,
                  subtitleController: subtitle,
                  logoSection: const Text('Logo'),
                  hasLogo: false,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('重設位置'), findsOneWidget);
    expect(find.text('垂直位置'), findsNothing);
    expect(find.byTooltip('粉紅色 #E06B84'), findsNWidgets(2));
    expect(find.text('店名字體大小 20 px'), findsOneWidget);
    expect(find.text('副標字體大小 18 px'), findsOneWidget);
    expect(find.text('請先上傳店家 Logo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand lane wins a horizontal drag against a tab view', (
    WidgetTester tester,
  ) async {
    StoreBrandStyle style = const StoreBrandStyle(markType: 'none', x: 0.2);
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: SizedBox(
              width: 360,
              height: 240,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return TabBarView(
                    children: <Widget>[
                      StoreBrandLane(
                        style: style,
                        shopName: '店',
                        subtitle: '',
                        logoUrl: '',
                        theme: theme,
                        editable: true,
                        onChanged: (StoreBrandStyle next) {
                          setState(() => style = next);
                        },
                      ),
                      const Center(child: Text('隔壁分頁')),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final TabController controller = DefaultTabController.of(
      tester.element(find.byType(TabBarView)),
    );
    final Offset start = tester.getCenter(find.text('店'));
    final TestGesture gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(90, 6));
    await tester.pump();
    expect(controller.index, 0);
    expect(controller.animation!.value, closeTo(0, 0.02));
    expect(find.text('隔壁分頁').hitTestable(), findsNothing);

    await gesture.up();
    await tester.pump();
    expect(controller.index, 0);
    expect(controller.animation!.value, closeTo(0, 0.02));
    expect(find.text('隔壁分頁').hitTestable(), findsNothing);
    expect(style.x, greaterThan(0.2));
  });

  testWidgets('dragging the brand does not select the home section', (
    WidgetTester tester,
  ) async {
    int selects = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 160,
            child: EditableHomeSection(
              sectionId: 'header',
              onSelect: () => selects++,
              child: const StoreBrandLane(
                style: StoreBrandStyle(markType: 'none', x: 0.2),
                shopName: '店',
                subtitle: '',
                logoUrl: '',
                theme: theme,
                editable: true,
                onChanged: _ignoreBrandChange,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('店'));
    await tester.pump();
    expect(selects, 1);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('店')),
    );
    await gesture.moveBy(const Offset(70, 4));
    await tester.pump();
    expect(selects, 1);
    await gesture.up();
    await tester.pump();
    expect(selects, 1);
  });

  testWidgets('dragging right keeps the brand block width', (
    WidgetTester tester,
  ) async {
    const String name = '很長的店家名稱在識別列裡保持同一寬度';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox(
            width: 320,
            child: StoreBrandLane(
              style: StoreBrandStyle(markType: 'none', x: 0),
              shopName: name,
              subtitle: '副標也留在同一行',
              logoUrl: '',
              theme: theme,
              editable: true,
              onChanged: _ignoreBrandChange,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder block = find.byType(StoreBrandBlock);
    final double before = tester.getSize(block).width;
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text(name)),
    );
    await gesture.moveBy(const Offset(120, 2));
    await tester.pump();
    final double during = tester.getSize(block).width;
    await gesture.up();
    await tester.pump();
    final double after = tester.getSize(block).width;
    expect(during, closeTo(before, 1));
    expect(after, closeTo(before, 1));
  });

  testWidgets('releasing the brand keeps the last dragged position', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: StoreBrandLane(
              style: StoreBrandStyle(markType: 'none', x: 0.15),
              shopName: '店',
              subtitle: '',
              logoUrl: '',
              theme: theme,
              editable: true,
              onChanged: _ignoreBrandChange,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder name = find.text('店');
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(name),
    );
    await gesture.moveBy(const Offset(80, 3));
    await tester.pump();
    final double during = tester.getTopLeft(name).dx;
    await gesture.up();
    await tester.pump();
    expect((tester.getTopLeft(name).dx - during).abs(), lessThan(1));
  });

  test('subtitle policy keeps 24 graphemes', () {
    expect(StoreBrandTextPolicy.sanitizeSubtitle('  貓' * 1), '貓');
    expect(
      StoreBrandTextPolicy.sanitizeSubtitle('字' * 40).characters.length,
      24,
    );
    final String mixed = StoreBrandTextPolicy.sanitizeSubtitle(
      '${'貓' * 23}😀 extra',
    );
    expect(mixed.characters.length, 24);
    expect(mixed.endsWith('😀'), isTrue);
    expect(mixed.contains('extra'), isFalse);
  });

  testWidgets('home name is one line and drawer name stays two', (
    WidgetTester tester,
  ) async {
    const String longName = '很長很長的店家名稱一定放不進一行所以要省略';
    const String longSubtitle =
        '副標很長需要省略副標很長需要省略副標很長需要省略副標很長需要省略副標很長需要省略副標很長需要省略';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: Column(
              children: <Widget>[
                const StoreBrandBlock(
                  contextKind: StoreBrandDisplayContext.home,
                  style: StoreBrandStyle(
                    markType: 'builtinIcon',
                    nameFontSize: 20,
                    subtitleFontSize: 18,
                  ),
                  shopName: longName,
                  subtitle: longSubtitle,
                  logoUrl: '',
                  theme: theme,
                ),
                const SizedBox(
                  width: 200,
                  child: StoreBrandBlock(
                    contextKind: StoreBrandDisplayContext.drawer,
                    style: StoreBrandStyle(markType: 'none', nameFontSize: 16),
                    shopName: longName,
                    subtitle: '側邊欄副標',
                    logoUrl: '',
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final Text homeName = tester.widget<Text>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is StoreBrandBlock &&
              widget.contextKind == StoreBrandDisplayContext.home,
        ),
        matching: find.text(longName),
      ),
    );
    expect(homeName.maxLines, 1);
    expect(homeName.softWrap, isFalse);
    expect(homeName.overflow, TextOverflow.ellipsis);
    final RenderParagraph homeParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is StoreBrandBlock &&
              widget.contextKind == StoreBrandDisplayContext.home,
        ),
        matching: find.text(longName),
      ),
    );
    expect(homeParagraph.didExceedMaxLines, isTrue);
    expect(homeParagraph.size.height, lessThan(20 * 1.2 * 1.6));

    final Text drawerName = tester.widget<Text>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is StoreBrandBlock &&
              widget.contextKind == StoreBrandDisplayContext.drawer,
        ),
        matching: find.text(longName),
      ),
    );
    expect(drawerName.maxLines, 2);
    expect(drawerName.softWrap, isTrue);

    final Text subtitle = tester.widget<Text>(find.text(longSubtitle));
    expect(subtitle.maxLines, 2);
    expect(subtitle.softWrap, isTrue);
    expect(subtitle.overflow, TextOverflow.ellipsis);
    final RenderParagraph subtitleParagraph = tester
        .renderObject<RenderParagraph>(find.text(longSubtitle));
    expect(subtitleParagraph.didExceedMaxLines, isTrue);
    expect(subtitleParagraph.size.height, lessThan(18 * 1.2 * 2.5));
  });

  testWidgets('subtitle field accepts 24 graphemes and drops the 25th', (
    WidgetTester tester,
  ) async {
    final TextEditingController subtitle = TextEditingController(
      text: StoreBrandTextPolicy.sanitizeSubtitle('舊' * 40),
    );
    addTearDown(subtitle.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ListView(
              children: <Widget>[
                StoreBrandSettingsCard(
                  style: const StoreBrandStyle(markType: 'none'),
                  theme: theme,
                  subtitleController: subtitle,
                  logoSection: const Text('Logo'),
                  hasLogo: false,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(subtitle.text.characters.length, 24);

    const String twentyFour = '一二三四五六七八九十一二三四五六七八九十一二三四';
    expect(twentyFour.characters.length, 24);
    await tester.enterText(find.byType(TextField), twentyFour);
    await tester.pump();
    expect(subtitle.text.characters.length, 24);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '$twentyFour五');
    await tester.pump();
    expect(subtitle.text.characters.length, 24);
    expect(subtitle.text, twentyFour);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreBrandChange(StoreBrandStyle style) {}
