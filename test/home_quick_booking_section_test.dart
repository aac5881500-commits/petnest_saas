import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_layout_canvas.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_quick_booking_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/quick_booking_section_settings_panel.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HomeThemeModel theme = HomeThemeModel.modernDefault;

  test('defaults and missing maps stay off the homepage', () {
    const HomeQuickBookingSectionSetting fresh =
        HomeQuickBookingSectionSetting();
    expect(fresh.showOnHome, isFalse);
    expect(fresh.layout, HomeQuickBookingLayouts.serviceSplit);
    expect(fresh.title, '快速預約');
    expect(fresh.subtitle, '選擇服務，開始安排毛孩行程');
    expect(fresh.buttonText, '我要預約');
    expect(fresh.showAccommodation, isTrue);
    expect(fresh.showDaycare, isTrue);
    expect(fresh.surfaceStyle, HomeQuickBookingSurfaces.solid);
    expect(fresh.schemaVersion, 1);
    final HomeQuickBookingSectionSetting loaded =
        HomeQuickBookingSectionSetting.fromMap(null);
    expect(loaded.toMap()['showOnHome'], isFalse);
    expect(loaded.layout, HomeQuickBookingLayouts.serviceSplit);
    final HomeQuickBookingSectionSetting partial =
        HomeQuickBookingSectionSetting.fromMap(<String, dynamic>{
          'showOnHome': true,
          'title': '標' * 20,
          'subtitle': '副' * 40,
          'buttonText': '鈕' * 12,
          'surfaceStyle': 'glass',
          'textAlign': 'middle',
        });
    expect(partial.showOnHome, isTrue);
    expect(partial.title, '標' * 16);
    expect(partial.subtitle, '副' * 36);
    expect(partial.buttonText, '鈕' * 10);
    expect(partial.surfaceStyle, HomeQuickBookingSurfaces.solid);
    expect(partial.textAlign, HomeQuickBookingTextAligns.left);
    expect(partial.copyWith(showOnHome: false).showOnHome, isFalse);
  });

  test('unknown layout returns to service split and spans follow the card', () {
    expect(
      HomeQuickBookingLayouts.migrate('poster'),
      HomeQuickBookingLayouts.serviceSplit,
    );
    expect(
      HomeQuickBookingSectionSetting.fromMap(<String, dynamic>{
        'layout': 'poster',
      }).layout,
      HomeQuickBookingLayouts.serviceSplit,
    );
    const HomeRoomSectionSetting rooms = HomeRoomSectionSetting();
    const HomeEnvironmentSectionSetting environment =
        HomeEnvironmentSectionSetting();
    HomeSectionSpan span(HomeQuickBookingSectionSetting setting) {
      return homeSectionSpan(
        sectionId: 'quickBooking',
        rooms: rooms,
        environment: environment,
        quickBooking: setting,
      );
    }

    expect(
      span(
        const HomeQuickBookingSectionSetting(
          layout: HomeQuickBookingLayouts.compactCard,
        ),
      ),
      HomeSectionSpan.half,
    );
    expect(
      span(
        const HomeQuickBookingSectionSetting(
          layout: HomeQuickBookingLayouts.singleLine,
        ),
      ),
      HomeSectionSpan.full,
    );
    expect(span(const HomeQuickBookingSectionSetting()), HomeSectionSpan.full);
  });

  test('old orders gain quick booking without showing it', () {
    final List<String> order = HomeSectionOrder.normalize(<String>[
      'banners',
      'facilities',
      'rooms',
    ]);
    expect(order.contains('quickBooking'), isTrue);
    expect(order.indexOf('quickBooking'), order.indexOf('banners') + 1);
    expect(
      order.indexOf('facilities'),
      greaterThan(order.indexOf('quickBooking')),
    );
    final List<String> hidden = HomeSectionOrder.visible(
      order,
      showAnnouncements: false,
    );
    expect(hidden.contains('quickBooking'), isFalse);
    final HomeQuickBookingSectionSetting setting =
        const HomeQuickBookingSectionSetting(showOnHome: true);
    expect(
      homeQuickBookingVisible(
        setting: setting,
        editorPreview: false,
        accommodationAvailable: true,
        daycareAvailable: false,
      ),
      isTrue,
    );
    expect(
      homeQuickBookingVisible(
        setting: setting,
        editorPreview: false,
        accommodationAvailable: false,
        daycareAvailable: true,
      ),
      isTrue,
    );
    expect(
      homeQuickBookingVisible(
        setting: setting,
        editorPreview: false,
        accommodationAvailable: false,
        daycareAvailable: false,
      ),
      isFalse,
    );
    expect(
      homeQuickBookingVisible(
        setting: const HomeQuickBookingSectionSetting(),
        editorPreview: true,
        accommodationAvailable: true,
        daycareAvailable: true,
      ),
      isFalse,
    );
    final List<String> live = HomeSectionOrder.visible(
      HomeSectionOrder.defaultOrder,
      showAnnouncements: true,
      showQuickBooking: homeQuickBookingVisible(
        setting: setting,
        editorPreview: false,
        accommodationAvailable: false,
        daycareAvailable: false,
      ),
    );
    expect(live.contains('quickBooking'), isFalse);
  });

  test('booking entry follows the real service switches', () {
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.automatic,
        accommodationOn: true,
        daycareOn: true,
      ),
      BookingEntryDestination.chooser,
    );
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.automatic,
        accommodationOn: true,
        daycareOn: false,
      ),
      BookingEntryDestination.accommodation,
    );
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.automatic,
        accommodationOn: false,
        daycareOn: true,
      ),
      BookingEntryDestination.daycare,
    );
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.automatic,
        accommodationOn: false,
        daycareOn: false,
      ),
      BookingEntryDestination.paused,
    );
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.accommodation,
        accommodationOn: false,
        daycareOn: true,
      ),
      BookingEntryDestination.paused,
    );
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.daycare,
        accommodationOn: true,
        daycareOn: false,
      ),
      BookingEntryDestination.paused,
    );
    expect(
      bookingEntryPausedMessage(BookingEntryInitialService.accommodation),
      '目前暫停住宿預約',
    );
    expect(
      bookingEntryPausedMessage(BookingEntryInitialService.daycare),
      '目前暫停安親預約',
    );
    expect(
      bookingEntryPausedMessage(BookingEntryInitialService.automatic),
      '目前暫停開放預約',
    );
  });

  testWidgets('cards stay inside a phone width and one service fills the row', (
    WidgetTester tester,
  ) async {
    Future<void> pump(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 320, child: child)),
        ),
      );
      await tester.pump();
    }

    await pump(
      ModernHomeQuickBookingSection(
        theme: theme,
        setting: HomeQuickBookingSectionSetting(
          showOnHome: true,
          layout: HomeQuickBookingLayouts.compactCard,
          subtitle: '很長的說明' * 8,
        ),
        accommodationAvailable: true,
        daycareAvailable: true,
        preview: false,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('home-quick-booking-card'))).height,
      closeTo(kModernHomeSmallCardHeight, 0.5),
    );

    int opens = 0;
    await pump(
      ModernHomeQuickBookingSection(
        theme: theme,
        setting: const HomeQuickBookingSectionSetting(
          showOnHome: true,
          layout: HomeQuickBookingLayouts.serviceSplit,
        ),
        accommodationAvailable: true,
        daycareAvailable: false,
        preview: true,
        onOpenAccommodation: () => opens++,
      ),
    );
    expect(find.byKey(const Key('home-quick-booking-daycare')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('home-quick-booking-stay'))).width,
      greaterThan(250),
    );
    await tester.tap(find.byKey(const Key('home-quick-booking-stay')));
    await tester.pump();
    expect(opens, 0);
    expect(tester.takeException(), isNull);

    await pump(
      ModernHomeQuickBookingSection(
        theme: theme,
        setting: const HomeQuickBookingSectionSetting(showOnHome: true),
        accommodationAvailable: false,
        daycareAvailable: false,
        preview: true,
      ),
    );
    expect(find.text(kHomeQuickBookingClosedMessage), findsOneWidget);
    expect(
      tester.getSize(find.text(kHomeQuickBookingClosedMessage)).height,
      greaterThan(12),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last visible service switch stays on', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _PanelHost host = _PanelHost();
    await tester.pumpWidget(host);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).maxLength,
      16,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).maxLength,
      10,
    );
    await tester.tap(find.text('顯示住宿預約'));
    await tester.pump();
    final _PanelHostState state = tester.state(find.byType(_PanelHost));
    expect(state.setting.showAccommodation, isFalse);
    await tester.tap(find.text('顯示寵物安親'));
    await tester.pump();
    expect(state.setting.showDaycare, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging quick booking updates the saved order', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    try {
      final _DragHost host = _DragHost();
      await tester.pumpWidget(host);
      await tester.pump();
      expect(find.byTooltip('拖曳整個快速預約區塊'), findsOneWidget);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const Key('home-section-drag-quickBooking')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      final Rect rooms = tester.getRect(
        find.byKey(const ValueKey<String>('home-section-rooms')),
      );
      await gesture.moveTo(Offset(rooms.left + 12, rooms.bottom + 24));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      final _DragHostState state = tester.state(find.byType(_DragHost));
      expect(tester.takeException(), isNull);
      expect(state.order, <String>['rooms', 'quickBooking']);
      expect(state.order.toSet().length, state.order.length);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _PanelHost extends StatefulWidget {
  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  HomeQuickBookingSectionSetting setting = const HomeQuickBookingSectionSetting(
    showOnHome: true,
    layout: HomeQuickBookingLayouts.serviceSplit,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: QuickBookingSectionSettingsPanel(
          setting: setting,
          theme: HomeThemeModel.modernDefault,
          accommodationAvailable: true,
          daycareAvailable: true,
          onChanged: (HomeQuickBookingSectionSetting value) {
            setState(() => setting = value);
          },
        ),
      ),
    );
  }
}

class _DragHost extends StatefulWidget {
  @override
  State<_DragHost> createState() => _DragHostState();
}

class _DragHostState extends State<_DragHost> {
  List<String> order = <String>['quickBooking', 'rooms'];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 640,
          child: HomeLayoutCanvas(
            background: Colors.white,
            sectionIds: order,
            sectionOrder: order,
            spanOf: (String id) {
              return id == 'quickBooking'
                  ? HomeSectionSpan.half
                  : HomeSectionSpan.full;
            },
            pinFooter: false,
            shopInfo: null,
            bottomInset: 12,
            selectedSectionId: null,
            onSelectSection: (_) {},
            onSectionOrderChanged: (List<String> next) {
              setState(() => order = next);
            },
            focusSectionId: null,
            focusSectionToken: 0,
            buildSection: (String sectionId) {
              return const SizedBox(height: 104, width: double.infinity);
            },
          ),
        ),
      ),
    );
  }
}
