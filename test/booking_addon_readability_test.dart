import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addon_section.dart';

Map<String, dynamic> data() => {
  'enabled': true,
  'timeOptions': [
    {'label': '正常入住', 'price': 0, 'desc': '請於店家一般營業時間內抵達。'},
  ],
  'valueServices': [
    {
      'id': 'welcome',
      'name': '貓咪迎賓點心組',
      'price': 100,
      'desc': '為貓咪的小旅行準備一份點心驚喜。若有飲食限制，請於預約備註告知。',
    },
  ],
  'customServices': [
    {
      'id': 'care',
      'name': '專屬照護安排',
      'price': 200,
      'desc': '每隻貓咪都有自己的生活習慣。請填寫照護需求，與店家確認可提供的內容。',
    },
  ],
  'dailyTimedServices': [
    {
      'id': 'play',
      'name': '每日專屬陪玩時光',
      'price': 50,
      'desc': '依貓咪個性與當天狀態安排陪伴互動，選擇每天需要的時段即可。',
      'timeSlots': [
        {'id': 'am', 'label': '10:00'},
        {'id': 'pm', 'label': '16:00'},
      ],
    },
  ],
};
Widget content({
  required Map<String, Map<String, Map<String, List<String>>>> daily,
  required VoidCallback changed,
}) => BookingAddonSection(
  showAddons: false,
  addonLoading: false,
  addonData: data(),
  selectedPetIds: const ['p1'],
  pets: const [
    {'petId': 'p1', 'name': '奶茶'},
  ],
  selectedTimeAddon: null,
  selectedValueServices: const [],
  selectedCustomServices: const {},
  selectedDailyTimedServices: daily,
  startDate: DateTime(2026, 11, 4),
  endDate: DateTime(2026, 11, 6),
  onToggleShowAddons: () {},
  onSelectTimeAddon: (_) {},
  onToggleValueService: (_) {},
  onToggleCustomService: (_) {},
  onToggleCustomPet: (_, id, value) {},
  onDailyTimedServicesChanged: changed,
);
void main() {
  setUpAll(() async {
    for (final entry in {
      'BookingPreview': 'BOOKING_PREVIEW_FONT',
      'MaterialIcons': 'BOOKING_PREVIEW_ICONS',
    }.entries) {
      final path = Platform.environment[entry.value];
      if (path == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(ByteData.sublistView(await File(path).readAsBytes())),
        );
      await loader.load();
    }
  });
  testWidgets(
    'all categories show content immediately and daily slots stay interactive',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final daily = <String, Map<String, Map<String, List<String>>>>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, change) => SingleChildScrollView(
                child: content(daily: daily, changed: () => change(() {})),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNothing);
      for (final name in ['正常入住', '貓咪迎賓點心組', '專屬照護安排', '每日專屬陪玩時光']) {
        expect(find.text(name), findsOneWidget);
      }
      final pet = find.byType(CheckboxListTile);
      await tester.ensureVisible(pet);
      await tester.pumpAndSettle();
      await tester.tap(pet);
      await tester.pumpAndSettle();
      expect(find.text('11/4（週三）'), findsOneWidget);
      expect(find.text('11/5（週四）'), findsOneWidget);
      expect(find.text('11/6（週五）'), findsNothing);
      final slot = find.widgetWithText(FilterChip, '10:00').first;
      await tester.ensureVisible(slot);
      await tester.pumpAndSettle();
      await tester.tap(slot);
      await tester.pumpAndSettle();
      expect(daily['play']?['p1']?['2026-11-04'], ['am']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'descriptions and prices fit narrow screens at 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: content(daily: {}, changed: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('render expanded add-on content', (tester) async {
    final output = Platform.environment['BOOKING_ADDON_READABLE_OUTPUT'];
    if (output == null) return;
    await tester.binding.setSurfaceSize(const Size(500, 2100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'BookingPreview'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFFFF9F0),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: content(daily: {}, changed: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
