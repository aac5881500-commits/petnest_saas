// 檔案名稱：test/daily_care_journal_preview_test.dart
// 功能說明：設定即時預覽為完整手機 viewport，含安全區；日期場次隨內容捲動

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_journal_layout.dart';
import 'package:petnest_saas/core/models/daily_care_photo_model.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/widgets/daily_care_card_surface.dart';
import 'package:petnest_saas/core/widgets/daily_care_journal_renderer.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_full_journal_preview.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester, {
    DailyCarePreviewPhoneSize phoneSize = DailyCarePreviewPhoneSize.standard,
    DailyCareSettingModel setting = const DailyCareSettingModel(),
    bool isDaycare = false,
    String shopName = '毛孩旅館',
    bool usePhoneFrame = true,
    bool singleDayMode = false,
    bool singleSessionMode = false,
    bool showPhotos = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 1100,
            child: DailyCareFullJournalPreview(
              setting: setting,
              isDaycare: isDaycare,
              sessionLabels: const <String>['上午場', '下午場'],
              sessionIndex: 0,
              showPhotos: showPhotos,
              usePhoneFrame: usePhoneFrame,
              shopName: shopName,
              phoneSize: phoneSize,
              singleDayMode: singleDayMode,
              singleSessionMode: singleSessionMode,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('預設標準手機 393×852 含系統列、AppBar 與返回', (WidgetTester tester) async {
    await pumpPreview(tester);

    expect(find.byType(DailyCareJournalRenderer), findsOneWidget);
    expect(find.byType(AppBar), findsWidgets);
    expect(find.byType(BackButtonIcon), findsWidgets);
    expect(find.byType(DailyCarePreviewStatusBar), findsOneWidget);
    expect(find.text('10:32'), findsWidgets);
    expect(find.text('毛孩旅館'), findsWidgets);
    expect(find.text('住宿照護紀錄'), findsWidgets);
    expect(find.textContaining('毛孩旅館・'), findsNothing);
    expect(find.text('安親'), findsNothing);
    expect(find.textContaining('預覽倍率'), findsNothing);
    expect(find.text('小米'), findsWidgets);
    expect(find.textContaining('28°C'), findsOneWidget);
    expect(find.text('環境狀況'), findsWidgets);
    expect(find.text('大小便狀況'), findsWidgets);
    expect(find.text('溫度'), findsOneWidget);
    expect(find.text('濕度'), findsOneWidget);
    expect(find.text('大便'), findsWidgets);
    expect(find.text('尿尿'), findsWidgets);
    expect(find.textContaining('填寫 10:32'), findsOneWidget);
    expect(find.text('✓ 已填寫'), findsWidgets);
    expect(find.text('上午場'), findsWidgets);
    expect(find.text('下午場'), findsWidgets);
    expect(find.text('晚上場'), findsWidgets);

    final BuildContext rendererContext = tester.element(
      find.byType(DailyCareJournalRenderer),
    );
    expect(MediaQuery.sizeOf(rendererContext), const Size(393, 852));
    expect(
      MediaQuery.textScalerOf(rendererContext),
      const TextScaler.linear(1),
    );
    expect(tester.getSize(find.byType(DailyCareJournalRenderer)).width, 393);
  });

  testWidgets('三種預覽尺寸會同時改變寬與高', (WidgetTester tester) async {
    await pumpPreview(tester, phoneSize: DailyCarePreviewPhoneSize.small);
    BuildContext ctx = tester.element(find.byType(DailyCareJournalRenderer));
    expect(MediaQuery.sizeOf(ctx), const Size(360, 780));

    await pumpPreview(tester);
    ctx = tester.element(find.byType(DailyCareJournalRenderer));
    expect(MediaQuery.sizeOf(ctx), const Size(393, 852));

    await pumpPreview(tester, phoneSize: DailyCarePreviewPhoneSize.large);
    ctx = tester.element(find.byType(DailyCareJournalRenderer));
    expect(MediaQuery.sizeOf(ctx), const Size(430, 932));
  });

  testWidgets('歡迎文字不再顯示', (WidgetTester tester) async {
    await pumpPreview(tester);
    expect(find.text('今天也請放心把毛孩交給我們照顧。'), findsNothing);
  });

  testWidgets('上滑後日期與場次會跟著內容滑走', (WidgetTester tester) async {
    await pumpPreview(tester);
    final Finder sessions = find.byKey(
      const ValueKey<String>('journal-header-sessions'),
    );
    expect(sessions, findsOneWidget);
    await tester.drag(
      find.byType(DailyCareJournalRenderer),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(sessions, findsNothing);
  });

  testWidgets('單日模式隱藏日期列，單場模式隱藏場次列', (WidgetTester tester) async {
    await pumpPreview(tester, singleDayMode: true, singleSessionMode: true);
    expect(find.text('下午場'), findsNothing);
    expect(find.text('晚上場'), findsNothing);
    expect(find.text('住宿照護紀錄'), findsWidgets);

    await pumpPreview(tester, singleDayMode: false, singleSessionMode: false);
    expect(find.text('下午場'), findsWidgets);
    expect(find.text('晚上場'), findsWidgets);
    await tester.tap(find.text('晚上場').first);
    await tester.pump();
    expect(find.textContaining('晚上場'), findsWidgets);
  });

  testWidgets('安親示範走同一套 renderer，僅標題與資料不同', (WidgetTester tester) async {
    await pumpPreview(
      tester,
      isDaycare: true,
      usePhoneFrame: false,
      setting: const DailyCareSettingModel(photoEnabled: true),
    );

    expect(find.byType(DailyCareJournalRenderer), findsOneWidget);
    expect(find.byType(DailyCarePreviewStatusBar), findsNothing);
    expect(find.text('本次安親回報'), findsWidgets);
    expect(find.text('今日尚未上傳照護照片'), findsNothing);
  });

  testWidgets('預覽框外有裝置備註，正式 renderer 沒有', (WidgetTester tester) async {
    await pumpPreview(tester);
    expect(find.text(DailyCareFullJournalPreview.deviceNote), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DailyCareJournalRenderer),
        matching: find.text(DailyCareFullJournalPreview.deviceNote),
      ),
      findsNothing,
    );
  });

  testWidgets('日期、場次、房間卡套用頁首設定，不使用粉灰底', (WidgetTester tester) async {
    await pumpPreview(tester);
    expect(
      find.byKey(const ValueKey<String>('journal-header-dates')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('journal-header-sessions')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('journal-header-hero')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('journal-header-dates')),
        matching: find.byType(DailyCareCardSurface),
      ),
      findsNothing,
    );

    await pumpPreview(
      tester,
      setting: const DailyCareSettingModel(
        journalHeader: DailyCareJournalHeaderStyle(useCardBackground: true),
        cardBackgroundType: DailyCareJournalTheme.cardTypePreset,
        cardBackgroundPreset: DailyCareJournalTheme.cardPresetPaw,
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('journal-header-dates')),
        matching: find.byType(DailyCareCardSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('journal-header-sessions')),
        matching: find.byType(DailyCareCardSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('journal-header-hero')),
        matching: find.byType(DailyCareCardSurface),
      ),
      findsOneWidget,
    );

    final Iterable<Material> materials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(DailyCareJournalRenderer),
        matching: find.byType(Material),
      ),
    );
    expect(
      materials.any((Material item) => item.color == const Color(0xFFEDE7E0)),
      isFalse,
    );
  });

  testWidgets('環境與大小便同列同高，三種預覽尺寸可見且不 overflow', (WidgetTester tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is FlutterError &&
          details.exception.toString().contains('overflowed')) {
        fail(details.exception.toString());
      }
      FlutterError.presentError(details);
    };

    for (final DailyCarePreviewPhoneSize size
        in DailyCarePreviewPhoneSize.all) {
      await pumpPreview(tester, phoneSize: size);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('daily-care-pinned-row')),
        findsOneWidget,
      );
      final Size env = tester.getSize(
        find.byKey(const ValueKey<String>('journal-card-environment')),
      );
      final Size toilet = tester.getSize(
        find.byKey(const ValueKey<String>('journal-card-toilet')),
      );
      expect(env.width, greaterThan(100));
      expect(toilet.width, greaterThan(100));
      expect(env.height, greaterThan(80));
      expect(toilet.height, greaterThan(80));
      expect(env.width, closeTo(toilet.width, 1));
      expect(env.height, closeTo(toilet.height, 1));
      expect(
        tester.getTopLeft(find.text('生活狀況').first).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey<String>('daily-care-pinned-row')),
              )
              .dy,
        ),
      );
    }
  });

  testWidgets('今日概況啟用但空白仍顯示無；大小便為左右名稱在上', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DailyCareStayInfo stay = DailyCareStayInfo(
      roomName: 'A1',
      pets: <DailyCareStayPet>[DailyCareStayPet(name: '小米', photoUrl: '')],
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 16),
    );
    final DailyCareRecordModel record = DailyCareRecordModel(
      id: 'r1',
      shopId: 's1',
      bookingId: 'b1',
      roomId: 'room',
      roomName: 'A1',
      recordDate: DateTime(2026, 9, 16),
      sessionIndex: 0,
      sessionName: '上午場',
      values: const <String, dynamic>{
        'temperature': '28',
        'humidity': '60',
        'stool': '正常',
        'urine': '正常',
        'generalNote': '   ',
      },
      petNotes: const <String, String>{},
      photoCount: 0,
      createdAt: DateTime(2026, 9, 16, 10),
      updatedAt: DateTime(2026, 9, 16, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 780,
            child: DailyCareJournalRenderer(
              setting: const DailyCareSettingModel(),
              stay: stay,
              dateKeys: const <String>['2026/09/16'],
              selectedDateKey: '2026/09/16',
              sessionTabs: const <DailyCareJournalSessionTab>[
                DailyCareJournalSessionTab(sessionIndex: 0, sessionName: '上午場'),
              ],
              selectedSessionIndex: 0,
              record: record,
              fallbackRoomName: 'A1',
              showPhotoSection: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('journal-card-general-note')),
      findsOneWidget,
    );
    expect(find.text('今日概況'), findsOneWidget);
    expect(find.text('無'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('journal-toilet-horizontal')),
      findsOneWidget,
    );
    final Offset stool = tester.getTopLeft(find.text('大便').last);
    final Offset urine = tester.getTopLeft(find.text('尿尿').last);
    final Offset stoolValue = tester.getTopLeft(find.text('正常').first);
    expect(stoolValue.dy, greaterThan(stool.dy));
    expect(urine.dx, greaterThan(stool.dx));
    expect((urine.dy - stool.dy).abs(), lessThan(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('同場有照片時摘要不顯示尚未上傳', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DailyCareStayInfo stay = DailyCareStayInfo(
      roomName: 'A1',
      pets: <DailyCareStayPet>[DailyCareStayPet(name: '小米', photoUrl: '')],
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 16),
    );
    final DailyCareRecordModel record = DailyCareRecordModel(
      id: 'r1',
      shopId: 's1',
      bookingId: 'b1',
      roomId: 'room',
      roomName: 'A1',
      recordDate: DateTime(2026, 9, 16, 8, 30),
      sessionIndex: 0,
      sessionName: '上午場',
      values: const <String, dynamic>{
        'temperature': '28',
        'humidity': '60',
        'stool': '正常',
        'urine': '正常',
      },
      petNotes: const <String, String>{},
      photoCount: 1,
      createdAt: DateTime(2026, 9, 16, 10),
      updatedAt: DateTime(2026, 9, 16, 10),
    );
    final DailyCarePhotoModel sessionPhoto = DailyCarePhotoModel(
      id: 'p1',
      shopId: 's1',
      bookingId: 'b1',
      roomId: 'room',
      roomName: 'A1',
      recordDate: DateTime(2026, 9, 16, 12),
      sessionIndex: 0,
      sessionName: '上午場',
      previewUrl: '',
      previewStoragePath: '',
      createdAt: DateTime(2026, 9, 16, 12),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            height: 852,
            child: DailyCareJournalRenderer(
              setting: const DailyCareSettingModel(),
              stay: stay,
              dateKeys: const <String>['2026/09/16'],
              selectedDateKey: '2026/09/16',
              sessionTabs: const <DailyCareJournalSessionTab>[
                DailyCareJournalSessionTab(sessionIndex: 0, sessionName: '上午場'),
              ],
              selectedSessionIndex: 0,
              record: record,
              fallbackRoomName: 'A1',
              photos: <DailyCarePhotoModel>[sessionPhoto],
              showPhotoSection: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(DailyCareJournalRenderer.emptyBookingPhotosLabel),
      findsNothing,
    );
    expect(
      find.text(DailyCareJournalRenderer.emptySessionPhotosLabel),
      findsNothing,
    );
    expect(find.textContaining('尚未上傳'), findsNothing);
  });

  testWidgets('本場沒照片但訂單其他場有時顯示本場尚無', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DailyCareStayInfo stay = DailyCareStayInfo(
      roomName: 'A1',
      pets: <DailyCareStayPet>[DailyCareStayPet(name: '小米', photoUrl: '')],
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 16),
    );
    final DailyCareRecordModel record = DailyCareRecordModel(
      id: 'r1',
      shopId: 's1',
      bookingId: 'b1',
      roomId: 'room',
      roomName: 'A1',
      recordDate: DateTime(2026, 9, 16),
      sessionIndex: 0,
      sessionName: '上午場',
      values: const <String, dynamic>{
        'temperature': '28',
        'humidity': '60',
        'stool': '正常',
        'urine': '正常',
      },
      petNotes: const <String, String>{},
      photoCount: 0,
      createdAt: DateTime(2026, 9, 16, 10),
      updatedAt: DateTime(2026, 9, 16, 10),
    );
    final DailyCarePhotoModel otherSession = DailyCarePhotoModel(
      id: 'p2',
      shopId: 's1',
      bookingId: 'b1',
      roomId: 'room',
      roomName: 'A1',
      recordDate: DateTime(2026, 9, 16),
      sessionIndex: 1,
      sessionName: '下午場',
      previewUrl: '',
      previewStoragePath: '',
      createdAt: DateTime(2026, 9, 16, 15),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            height: 852,
            child: DailyCareJournalRenderer(
              setting: const DailyCareSettingModel(),
              stay: stay,
              dateKeys: const <String>['2026/09/16'],
              selectedDateKey: '2026/09/16',
              sessionTabs: const <DailyCareJournalSessionTab>[
                DailyCareJournalSessionTab(sessionIndex: 0, sessionName: '上午場'),
                DailyCareJournalSessionTab(sessionIndex: 1, sessionName: '下午場'),
              ],
              selectedSessionIndex: 0,
              record: record,
              fallbackRoomName: 'A1',
              photos: <DailyCarePhotoModel>[otherSession],
              showPhotoSection: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(DailyCareJournalRenderer.emptySessionPhotosLabel),
      findsOneWidget,
    );
    expect(
      find.text(DailyCareJournalRenderer.emptyBookingPhotosLabel),
      findsNothing,
    );
  });

  testWidgets('預覽有兩個模擬按鈕且無照片時仍保留', (WidgetTester tester) async {
    await pumpPreview(tester, showPhotos: false);
    await tester.drag(
      find.byType(DailyCareJournalRenderer),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        DailyCarePreviewServiceButtons.photosButtonKey,
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        DailyCarePreviewServiceButtons.cameraButtonKey,
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final FilledButton photosBtn = tester.widget<FilledButton>(
      find.byKey(
        DailyCarePreviewServiceButtons.photosButtonKey,
        skipOffstage: false,
      ),
    );
    final OutlinedButton cameraBtn = tester.widget<OutlinedButton>(
      find.byKey(
        DailyCarePreviewServiceButtons.cameraButtonKey,
        skipOffstage: false,
      ),
    );
    photosBtn.onPressed?.call();
    cameraBtn.onPressed?.call();
    expect(find.byType(DailyCareFullJournalPreview), findsOneWidget);
    expect(
      find.text(
        DailyCareJournalRenderer.emptyBookingPhotosLabel,
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text(DailyCareFullJournalPreview.deviceNote), findsOneWidget);
  });

  testWidgets('預覽隔離桌機文字倍率並依 360 邏輯寬排版', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(300, 900),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: DailyCareFullJournalPreview(
                setting: const DailyCareSettingModel(),
                isDaycare: false,
                sessionLabels: const <String>[],
                sessionIndex: 0,
                phoneSize: DailyCarePreviewPhoneSize.small,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final BuildContext rendererContext = tester.element(
      find.byType(DailyCareJournalRenderer),
    );
    expect(MediaQuery.sizeOf(rendererContext), const Size(360, 780));
    expect(
      MediaQuery.textScalerOf(rendererContext),
      const TextScaler.linear(1),
    );
    expect(find.text('飼料'), findsOneWidget);
    expect(find.text('逗貓棒'), findsOneWidget);
    expect(find.text('貓薄荷'), findsOneWidget);
    expect(find.text('偏少'), findsWidgets);
  });

  testWidgets('360／393／430 正常字體下單位不拆行且項目名稱可見', (WidgetTester tester) async {
    const List<double> widths = <double>[360, 393, 430];
    const List<String> names = <String>[
      '飲水',
      '飼料',
      '罐頭',
      '零食',
      '逗貓棒',
      '貓抓板',
      '貓跳台',
      '玩具球',
      '貓屋',
      '貓薄荷',
      '木天蓼',
      '貓草',
    ];
    for (final double width in widths) {
      await _pumpJournalAt(tester, width: width);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(DailyCareJournalRenderer)),
        ),
        const TextScaler.linear(1),
      );
      final Size tempSize = tester.getSize(
        find.byKey(const ValueKey<String>('journal-metric-溫度')),
      );
      final Size humidSize = tester.getSize(
        find.byKey(const ValueKey<String>('journal-metric-濕度')),
      );
      expect(tempSize.height, lessThan(22 * 1.1 + 10));
      expect(humidSize.height, lessThan(22 * 1.1 + 10));
      expect(find.text('28°C'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('大便'), findsWidgets);
      expect(find.text('尿尿'), findsWidgets);
      final Size env = tester.getSize(
        find.byKey(const ValueKey<String>('journal-card-environment')),
      );
      final Size toilet = tester.getSize(
        find.byKey(const ValueKey<String>('journal-card-toilet')),
      );
      expect(env.width, greaterThan(100));
      expect(toilet.width, greaterThan(100));
      expect(env.height, greaterThan(80));
      expect(toilet.height, greaterThan(80));
      expect(env.height, closeTo(toilet.height, 1));
      expect(env.width, closeTo(toilet.width, 1));
      expect(
        tester.getTopLeft(find.text('生活狀況').first).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey<String>('daily-care-pinned-row')),
              )
              .dy,
        ),
      );
      for (final String name in names) {
        final Finder item = find.text(name, skipOffstage: false);
        expect(item, findsWidgets, reason: '$name @ $width');
        expect(tester.getSize(item.first).width, greaterThan(0));
        expect(tester.getSize(item.first).height, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpJournalAt(
  WidgetTester tester, {
  required double width,
  String humidity = '30',
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final DailyCareStayInfo stay = DailyCareStayInfo(
    roomName: 'A1',
    pets: <DailyCareStayPet>[DailyCareStayPet(name: '小米', photoUrl: '')],
    startDate: DateTime(2026, 9, 16),
    endDate: DateTime(2026, 9, 16),
  );
  final DailyCareRecordModel record = DailyCareRecordModel(
    id: 'r1',
    shopId: 's1',
    bookingId: 'b1',
    roomId: 'room',
    roomName: 'A1',
    recordDate: DateTime(2026, 9, 16),
    sessionIndex: 0,
    sessionName: '上午場',
    values: <String, dynamic>{
      'temperature': '28',
      'humidity': humidity,
      'stool': '正常',
      'urine': '偏少',
      'water': '正常',
      'dryFood': '正常',
      'wetFood': '偏少',
      'snack': '正常',
      'wandToy': '有',
      'scratchBoard': '有',
      'jumpPlatform': '無',
      'toyBall': '有',
      'catHouse': '有',
      'catnip': '無',
      'silverVine': '無',
      'catGrass': '有',
    },
    petNotes: const <String, String>{},
    photoCount: 0,
    createdAt: DateTime(2026, 9, 16, 10),
    updatedAt: DateTime(2026, 9, 16, 10),
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 1600),
        textScaler: const TextScaler.linear(1.0),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 1600,
            child: DailyCareJournalRenderer(
              setting: const DailyCareSettingModel(),
              stay: stay,
              dateKeys: const <String>['2026/09/16'],
              selectedDateKey: '2026/09/16',
              sessionTabs: const <DailyCareJournalSessionTab>[
                DailyCareJournalSessionTab(sessionIndex: 0, sessionName: '上午場'),
              ],
              selectedSessionIndex: 0,
              record: record,
              fallbackRoomName: 'A1',
              showPhotoSection: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
