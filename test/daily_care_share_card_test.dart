// 檔案名稱：test/daily_care_share_card_test.dart
// 功能說明：分享海報不含照片、雙欄、概況限行，以及未完成不可分享。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_report_data.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_report_export_service.dart';
import 'package:petnest_saas/core/widgets/daily_care_card_surface.dart';
import 'package:petnest_saas/core/widgets/daily_care_illustrations.dart';
import 'package:petnest_saas/core/widgets/daily_care_share_card.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_session_actions.dart';

final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  DailyCareReportField field(String label, String value) {
    return DailyCareReportField(
      label: label,
      value: value,
      badge: DailyCareReportBadgeKind.none,
    );
  }

  DailyCareReportData posterData({String note = '今天精神不錯。'}) {
    return DailyCareReportData(
      shopName: '測試店家',
      shopLogoUrl: '',
      brandColor: const Color(0xFF6D4C41),
      title: '每日照護回報',
      headerDateText: '2026/10/03',
      roomName: 'A3',
      roomTypeName: '舒適標準房',
      petNames: '喵喵',
      checkInText: '2026/10/01',
      checkOutText: '2026/10/04',
      nightsText: '3 晚',
      bookingCode: 'PN1001',
      generatedAtText: '2026/10/03 23:00',
      isFullStay: false,
      kind: DailyCareReportExportKind.singleDay,
      days: <DailyCareReportDay>[
        DailyCareReportDay(
          dateKey: '2026/10/03',
          dateTitle: '2026/10/03',
          sessions: <DailyCareReportSession>[
            DailyCareReportSession(
              sessionName: '測試員1',
              updatedAtText: '23:00 更新',
              generalNote: note,
              groups: <DailyCareReportGroup>[
                DailyCareReportGroup(
                  title: '環境狀況',
                  fields: <DailyCareReportField>[
                    field('室內溫度', '28°C'),
                    field('室內濕度', '30%'),
                  ],
                ),
                DailyCareReportGroup(
                  title: '大小便狀況',
                  fields: <DailyCareReportField>[
                    field('大便', '正常'),
                    field('尿尿', '偏少'),
                  ],
                ),
                DailyCareReportGroup(
                  title: '生活狀況',
                  fields: <DailyCareReportField>[
                    field('飼料', '正常'),
                    field('罐頭', '偏少'),
                    field('零食', '偏多'),
                  ],
                ),
                DailyCareReportGroup(
                  title: '活動與玩樂',
                  fields: <DailyCareReportField>[
                    field('逗貓棒', '無'),
                    field('玩具球', '有'),
                  ],
                ),
                DailyCareReportGroup(
                  title: '放鬆與用品',
                  fields: <DailyCareReportField>[
                    field('貓薄荷', '無'),
                    field('木天蓼', '有'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required DailyCareReportData data,
    bool daycare = false,
    ImageProvider? logo,
  }) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: DailyCareShareCard(
              data: data,
              setting: const DailyCareSettingModel(),
              guestName: '劉志晟',
              daycare: daycare,
              logoProvider: logo,
            ),
          ),
        ),
      ),
    );
  }

  test('照護分類環境與大小便、生活與活動成對', () {
    final List<DailyCareShareBand> rows = DailyCareShareLayout.bands(
      posterData().days.first.sessions.first.groups,
    );
    expect(rows[0].paired, isTrue);
    expect(rows[0].left.title, '環境狀況');
    expect(rows[0].right!.title, '大小便狀況');
    expect(rows[1].paired, isTrue);
    expect(rows[1].left.title, '生活狀況');
    expect(rows[1].right!.title, '活動與玩樂');
    expect(rows[2].paired, isFalse);
    expect(rows[2].left.title, '放鬆與用品');
  });

  test('未完成場次不會進入分享資料', () {
    final DateTime day = DateTime(2026, 10, 3);
    DailyCareRecordModel record({required int index, DateTime? completedAt}) {
      return DailyCareRecordModel(
        id: 'r$index',
        shopId: 's1',
        bookingId: 'b1',
        roomId: 'room',
        roomName: 'A3',
        recordDate: day,
        sessionIndex: index,
        sessionName: '晚場',
        values: const <String, dynamic>{},
        petNotes: const <String, String>{},
        photoCount: 2,
        createdAt: day,
        updatedAt: day,
        completedAt: completedAt,
      );
    }

    final List<DailyCareRecordModel> scoped = completedSessionRecords(
      records: <DailyCareRecordModel>[
        record(index: 0),
        record(index: 1, completedAt: day),
      ],
      onlyDate: day,
      onlySessionIndex: 0,
    );
    expect(scoped, isEmpty);

    final List<DailyCareRecordModel> done = completedSessionRecords(
      records: <DailyCareRecordModel>[
        record(index: 0),
        record(index: 1, completedAt: day),
      ],
      onlyDate: day,
      onlySessionIndex: 1,
    );
    expect(done, hasLength(1));
    expect(done.single.sessionIndex, 1);
  });

  test('顧客端預覽沿用正式回報頁', () {
    final String source = File(
      'lib/features/booking/pages/customer_daily_care_page.dart',
    ).readAsStringSync();
    expect(source.contains('DailyCareJournalRenderer('), isTrue);
    expect(source.contains('DailyCareCustomerPreviewCopy.title'), isTrue);
    expect(source.contains('previewMode'), isTrue);
    expect(DailyCareCustomerPreviewCopy.hint, '此畫面模擬顧客目前看到的回報');
    expect(DailyCareCustomerPreviewCopy.pending, '預覽中・尚未完成');
  });

  testWidgets('分享圖沒有照片與操作按鈕，概況最多六行', (WidgetTester tester) async {
    final String longNote = List<String>.filled(20, '今天的核心就是把結算做完。').join('\n');
    await pumpCard(
      tester,
      data: posterData(note: longNote),
      logo: MemoryImage(_onePixelPng),
    );

    expect(find.text('照護照片'), findsNothing);
    expect(find.text('查看全部照護照片'), findsNothing);
    expect(find.text('重新讀取攝影機'), findsNothing);
    expect(find.text('分享本場'), findsNothing);
    expect(find.text('返回'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(DailyCareJournalPageBackground), findsOneWidget);
    expect(find.text('測試店家'), findsWidgets);
    expect(find.text('每日照護回報'), findsOneWidget);
    expect(find.text('DAILY CARE'), findsNothing);
    expect(find.text('PetNest 每日照護回報'), findsNothing);
    expect(find.text('感謝您的入住'), findsNothing);
    expect(find.textContaining('今天也有好好照顧喵喵'), findsOneWidget);
    expect(find.text('喵喵'), findsWidgets);
    expect(find.text('飼主：劉志晟'), findsOneWidget);
    expect(find.text('A3・舒適標準房'), findsOneWidget);
    expect(find.text('測試員1'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
    expect(find.text('偏少'), findsWidgets);
    expect(find.text('偏多'), findsOneWidget);
    expect(find.text('有'), findsWidgets);
    expect(find.text('無'), findsWidgets);
    expect(find.byType(DailyCareTitleIcon), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('daily-care-share-toilet')),
      findsOneWidget,
    );
    expect(find.text('入住日期'), findsNothing);
    expect(find.text('訂單編號'), findsNothing);
    expect(find.textContaining('回報編號 PN1001'), findsOneWidget);

    final Text note = tester.widget<Text>(
      find.byKey(const ValueKey<String>('daily-care-share-note')),
    );
    expect(note.data, longNote);
    expect(note.maxLines, isNull);
    expect(note.overflow, isNull);
    expect(note.style?.fontSize, 13);

    final double environmentHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('daily-care-share-card-環境狀況')),
        )
        .height;
    final double toiletHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('daily-care-share-card-大小便狀況')),
        )
        .height;
    expect(environmentHeight, toiletHeight);

    final Align signature = tester.widget<Align>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('daily-care-share-signature'),
            ),
            matching: find.byType(Align),
          )
          .first,
    );
    expect(signature.alignment, Alignment.centerRight);

    expect(
      find.byKey(const ValueKey<String>('daily-care-share-pair-環境狀況')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('daily-care-share-pair-生活狀況')),
      findsOneWidget,
    );

    final Size size = tester.getSize(find.byType(DailyCareShareCard));
    expect(size.width, DailyCareShareLayout.logicalWidth);
    expect(size.height, greaterThan(0));

    final Size logo = tester.getSize(
      find.byKey(const ValueKey<String>('daily-care-share-logo')),
    );
    expect(logo.width, DailyCareShareCard.logoSize);
    expect(logo.height, DailyCareShareCard.logoSize);
    expect(find.byType(ClipOval), findsNothing);
  });

  test('大小便有值就進分享圖，空白不補假狀態', () {
    DailyCareRecordModel care(Map<String, dynamic> values) {
      final DateTime day = DateTime(2026, 10, 3);
      return DailyCareRecordModel(
        id: 'r',
        shopId: 's1',
        bookingId: 'b1',
        roomId: 'room',
        roomName: 'A3',
        recordDate: day,
        sessionIndex: 0,
        sessionName: '晚場',
        values: values,
        petNotes: const <String, String>{},
        photoCount: 0,
        createdAt: day,
        updatedAt: day,
      );
    }

    final DailyCareReportSession filled = DailyCareReportExportService.instance
        .buildStoredSession(
          record: care(<String, dynamic>{'stool': '正常', 'urine': '偏少'}),
          setting: const DailyCareSettingModel(),
        );
    final DailyCareReportGroup toilet = filled.groups.singleWhere(
      (DailyCareReportGroup group) => group.title == '大小便狀況',
    );
    expect(toilet.fields.map((DailyCareReportField field) => field.value), [
      '正常',
      '偏少',
    ]);

    final DailyCareReportSession empty = DailyCareReportExportService.instance
        .buildStoredSession(
          record: care(<String, dynamic>{'dryFood': '正常'}),
          setting: const DailyCareSettingModel(),
        );
    expect(
      empty.groups.where(
        (DailyCareReportGroup group) => group.title == '大小便狀況',
      ),
      isEmpty,
    );
  });

  testWidgets('沒有 LOGO 時文字直接補位', (WidgetTester tester) async {
    await pumpCard(tester, data: posterData());
    expect(
      find.byKey(const ValueKey<String>('daily-care-share-logo')),
      findsNothing,
    );
    expect(find.text('測試店家'), findsWidgets);
    expect(find.text('DAILY CARE'), findsNothing);
    final Text note = tester.widget<Text>(
      find.byKey(const ValueKey<String>('daily-care-share-note')),
    );
    expect(note.style?.fontSize, 13);
    expect(note.maxLines, isNull);
  });

  testWidgets('安親分享圖使用安親致謝，不寫入住', (WidgetTester tester) async {
    await pumpCard(tester, data: posterData(), daycare: true);
    expect(find.textContaining('今天的照護時光順利完成'), findsOneWidget);
    expect(find.text('感謝您的入住'), findsNothing);
    expect(find.text('PetNest 每日照護回報'), findsNothing);
    expect(find.textContaining('今天也有好好照顧'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄寬兩顆按鈕不溢位，未完成不能分享', (WidgetTester tester) async {
    var previewed = false;
    var shared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: DailyCareSessionActionButtons(
                completed: false,
                onPreview: () => previewed = true,
                onShare: () => shared = true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('顧客端預覽'), findsOneWidget);
    expect(find.text('分享本場'), findsOneWidget);

    final FilledButton share = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('daily-care-share-session')),
    );
    expect(share.onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey<String>('daily-care-customer-preview')),
    );
    expect(previewed, isTrue);
    expect(shared, isFalse);
  });
}
