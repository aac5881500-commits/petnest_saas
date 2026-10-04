import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_layout_canvas.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('small entry cards keep one height with or without a subtitle', (
    WidgetTester tester,
  ) async {
    Future<double> height({required bool showSubtitle}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 180,
                child: ModernHomeEntryCard(
                  cardKey: const Key('height-card'),
                  theme: HomeThemeModel.modernDefault,
                  title: '很長的房型介紹標題用來確認兩行省略',
                  subtitle: showSubtitle ? '很長的副標題用來確認仍然是同一張卡片高度' : '',
                  showSubtitle: showSubtitle,
                  cardSize: 'small',
                  surface: 'filled',
                  icon: Icons.meeting_room_outlined,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byKey(const Key('height-card'))).height;
    }

    final double withSubtitle = await height(showSubtitle: true);
    final double withoutSubtitle = await height(showSubtitle: false);
    expect(withSubtitle, closeTo(kModernHomeSmallCardHeight, 0.5));
    expect(withoutSubtitle, closeTo(kModernHomeSmallCardHeight, 0.5));
    expect((withSubtitle - withoutSubtitle).abs(), lessThanOrEqualTo(0.5));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: Column(
                children: <Widget>[
                  ModernHomeEntryCard(
                    cardKey: const Key('wide-card'),
                    theme: HomeThemeModel.modernDefault,
                    title: '標準橫卡',
                    subtitle: '一行簡介',
                    showSubtitle: true,
                    cardSize: 'wide',
                    surface: 'filled',
                    icon: Icons.home_outlined,
                    showArrow: true,
                    onTap: () {},
                  ),
                  ModernHomeEntryCard(
                    cardKey: const Key('single-card'),
                    theme: HomeThemeModel.modernDefault,
                    title: '長卡',
                    subtitle: '',
                    showSubtitle: false,
                    cardSize: 'single',
                    surface: 'translucent',
                    icon: Icons.favorite_border_rounded,
                    actionLabel: '',
                    showArrow: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('wide-card'))).height,
      closeTo(kModernHomeWideCardHeight, 0.5),
    );
    expect(
      tester.getSize(find.byKey(const Key('single-card'))).height,
      greaterThanOrEqualTo(kModernHomeSingleCardMinHeight - 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging half cards reorders without a framework assertion', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      await _dragHalfCards(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a long press drags a section on touch platforms', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      final _DragHostState host = await _pumpHost(tester);
      await _dragSection(
        tester,
        sectionId: 'about',
        target: _above(tester, 'rooms'),
        kind: PointerDeviceKind.touch,
        hold: const Duration(milliseconds: 600),
      );
      expect(tester.takeException(), isNull);
      expect(host.selected, 'about');
      expect(host.order.first, 'about');
      expect(host.order.toSet().length, host.order.length);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('dragging does not jump the list back to the top', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      await _pumpHost(tester, shopInfoHeight: 700, height: 360);
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      scrollable.position.jumpTo(80);
      await tester.pump();
      expect(scrollable.position.pixels, 80);
      final Rect viewport = tester.getRect(find.byType(ListView));
      await _dragSection(tester, sectionId: 'rooms', target: viewport.center);
      expect(scrollable.position.pixels, greaterThan(40));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _dragHalfCards(WidgetTester tester) async {
  final _DragHostState host = await _pumpHost(tester);
  final double roomsHeight = tester
      .getSize(find.byKey(const Key('card-rooms')))
      .height;
  final double facilitiesHeight = tester
      .getSize(find.byKey(const Key('card-facilities')))
      .height;
  final double aboutHeight = tester
      .getSize(find.byKey(const Key('card-about')))
      .height;
  expect(roomsHeight, closeTo(kModernHomeSmallCardHeight, 0.5));
  expect((roomsHeight - facilitiesHeight).abs(), lessThanOrEqualTo(0.5));
  expect((roomsHeight - aboutHeight).abs(), lessThanOrEqualTo(0.5));

  await _dragSection(
    tester,
    sectionId: 'about',
    target: _above(tester, 'rooms'),
  );
  expect(tester.takeException(), isNull);
  expect(host.selected, 'about');
  expect(host.order, <String>['about', 'rooms', 'facilities']);
  expect(host.order.toSet().length, host.order.length);
  expect(
    find.byKey(const ValueKey<String>('home-section-about')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('home-section-rooms')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('home-section-facilities')),
    findsOneWidget,
  );
  expect(
    tester
        .getTopLeft(find.byKey(const ValueKey<String>('home-section-about')))
        .dy,
    closeTo(
      tester
          .getTopLeft(find.byKey(const ValueKey<String>('home-section-rooms')))
          .dy,
      0.5,
    ),
  );
  expect(
    tester
        .getTopLeft(find.byKey(const ValueKey<String>('home-section-about')))
        .dx,
    lessThan(
      tester
          .getTopLeft(find.byKey(const ValueKey<String>('home-section-rooms')))
          .dx,
    ),
  );
  expect(
    tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('home-section-facilities')),
        )
        .dy,
    greaterThan(
      tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('home-section-about')),
              )
              .dy +
          40,
    ),
  );

  for (int round = 0; round < 4; round++) {
    await tester.pump();
    final bool aboutFirst = host.order.first == 'about';
    await _dragSection(
      tester,
      sectionId: 'about',
      target: aboutFirst
          ? _below(tester, host.order.last)
          : _above(tester, host.order.first),
    );
    expect(tester.takeException(), isNull);
    expect(host.selected, 'about');
    expect(host.order.toSet().length, host.order.length);
    expect(
      find.byKey(const ValueKey<String>('home-section-about')),
      findsOneWidget,
    );
  }

  final Size card = tester.getSize(
    find.byKey(const ValueKey<String>('home-section-about')),
  );
  final TestGesture feedbackGesture = await tester.startGesture(
    tester.getCenter(find.byKey(const Key('home-section-drag-about'))),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await feedbackGesture.moveBy(const Offset(0, -30));
  await tester.pump();
  final Iterable<Positioned> feedback = tester
      .widgetList<Positioned>(find.byType(Positioned))
      .where((Positioned item) => item.width != null && item.height != null);
  expect(feedback, isNotEmpty);
  expect(feedback.first.height!, closeTo(card.height, 8));
  expect(feedback.first.height!, lessThan(180));
  await feedbackGesture.up();
  await tester.pump();
  expect(tester.takeException(), isNull);

  host.aboutHalf = false;
  host.rebuild();
  await tester.pump();
  await _dragSection(
    tester,
    sectionId: 'about',
    target: _below(tester, 'rooms'),
  );
  expect(tester.takeException(), isNull);
  expect(host.selected, 'about');
  expect(host.order.toSet().length, host.order.length);

  host.showAbout = false;
  host.rebuild();
  await tester.pump();
  expect(find.byKey(const Key('card-about')), findsNothing);
  expect(tester.takeException(), isNull);
  host.showAbout = true;
  host.rebuild();
  await tester.pump();
  expect(find.byKey(const Key('card-about')), findsOneWidget);
  expect(
    find.byKey(const ValueKey<String>('home-section-about')),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}

Future<_DragHostState> _pumpHost(
  WidgetTester tester, {
  double height = 700,
  double shopInfoHeight = 0,
}) async {
  final _DragHost host = _DragHost(
    height: height,
    shopInfoHeight: shopInfoHeight,
  );
  await tester.pumpWidget(host);
  await tester.pump();
  return tester.state<_DragHostState>(find.byType(_DragHost));
}

Offset _above(WidgetTester tester, String sectionId) {
  final Rect rect = tester.getRect(
    find.byKey(ValueKey<String>('home-section-$sectionId')),
  );
  return Offset(rect.left + 16, rect.top - 28);
}

Offset _below(WidgetTester tester, String sectionId) {
  final Rect rect = tester.getRect(
    find.byKey(ValueKey<String>('home-section-$sectionId')),
  );
  return Offset(rect.left + 16, rect.bottom + 36);
}

Future<void> _dragSection(
  WidgetTester tester, {
  required String sectionId,
  required Offset target,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
  Duration hold = Duration.zero,
}) async {
  final Finder handle = find.byKey(Key('home-section-drag-$sectionId'));
  expect(handle, findsOneWidget);
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(handle),
    kind: kind,
  );
  await tester.pump(
    hold == Duration.zero ? const Duration(milliseconds: 20) : hold,
  );
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

class _DragHost extends StatefulWidget {
  const _DragHost({required this.height, required this.shopInfoHeight});

  final double height;
  final double shopInfoHeight;

  @override
  State<_DragHost> createState() => _DragHostState();
}

class _DragHostState extends State<_DragHost> {
  List<String> order = <String>['rooms', 'facilities', 'about'];
  String? selected;
  bool aboutHalf = true;
  bool showAbout = true;

  void rebuild() {
    setState(() {});
  }

  List<String> get _visible {
    if (showAbout) {
      return order;
    }
    return order.where((String id) => id != 'about').toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: widget.height,
          child: HomeLayoutCanvas(
            background: Colors.white,
            sectionIds: _visible,
            sectionOrder: order,
            spanOf: (String sectionId) {
              if (sectionId == 'about' && !aboutHalf) {
                return HomeSectionSpan.full;
              }
              return HomeSectionSpan.half;
            },
            pinFooter: false,
            shopInfo: widget.shopInfoHeight <= 0
                ? null
                : SizedBox(height: widget.shopInfoHeight),
            bottomInset: 12,
            selectedSectionId: selected,
            onSelectSection: (String sectionId) {
              setState(() => selected = sectionId);
            },
            onSectionOrderChanged: (List<String> next) {
              setState(() => order = next);
            },
            focusSectionId: null,
            focusSectionToken: 0,
            buildSection: (String sectionId) {
              if (sectionId == 'header' || sectionId == 'footer') {
                return const SizedBox(height: 36);
              }
              return ModernHomeEntryCard(
                cardKey: Key('card-$sectionId'),
                theme: HomeThemeModel.modernDefault,
                title: sectionId,
                subtitle: '副標',
                showSubtitle: true,
                cardSize: 'small',
                surface: 'filled',
                icon: Icons.pets_outlined,
                onTap: () {},
              );
            },
          ),
        ),
      ),
    );
  }
}
