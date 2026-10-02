import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
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

    final StoreBrandStyle withLogo = StoreBrandStyle.fromMap(
      <String, dynamic>{'homepageBrandLogoPlacement': 'leading'},
      logoUrl: 'https://example.com/logo.png',
    );
    expect(withLogo.markType, 'logo');

    final StoreBrandStyle iconOnly = StoreBrandStyle.fromMap(
      <String, dynamic>{
        'showLeftHeaderIcon': false,
        'showRightHeaderIcon': true,
        'rightHeaderIcon': 'star',
      },
    );
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
    final TestGesture gesture = await tester.startGesture(start + const Offset(4, 4));
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
    expect(find.byKey(const ValueKey<String>('store-brand-handle-left')), findsNothing);
  });

  testWidgets('brand row sits above the next section and keeps one home block', (
    WidgetTester tester,
  ) async {
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
  });

  testWidgets('brand settings card fits a narrow phone width', (WidgetTester tester) async {
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
}
