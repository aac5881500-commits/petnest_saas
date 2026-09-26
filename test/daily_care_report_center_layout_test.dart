// 檔案名稱：test/daily_care_report_center_layout_test.dart
// 功能說明：每日回報中心訂單摘要卡與手機／平板／桌機寬度不 overflow。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/features/room/pages/daily_care_record_edit_page.dart';
import 'package:petnest_saas/features/room/widgets/daily_care_record_editor.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_report_center_board.dart';

void main() {
  final DateTime today = DateTime(2026, 9, 21);
  const DailyCareSettingModel setting = DailyCareSettingModel(enabled: true);

  DailyCareReportCenterItem item({
    required String bookingId,
    required int sessionIndex,
    required bool completed,
    String roomName = 'A1',
    bool daycare = false,
    String customer = '王小明',
    List<String> pets = const <String>['小米', '橘子', '牛奶'],
    DateTime? recordDate,
    String? sessionName,
    DailyCareEntitlement? entitlement,
    int photoCount = -1,
    bool reportsLocked = false,
  }) {
    return DailyCareReportCenterItem(
      id: '${bookingId}_$sessionIndex',
      shopId: 's1',
      bookingId: bookingId,
      sessionIndex: sessionIndex,
      sessionName:
          sessionName ??
          (daycare ? '日間安親' : (sessionIndex == 0 ? '晨間照護' : '晚間照護')),
      recordDate: recordDate ?? today,
      entitlement:
          entitlement ??
          const DailyCareEntitlement(enabled: true, finalReports: 2),
      isCompleted: completed,
      reportsLocked: reportsLocked,
      photoCount: photoCount >= 0 ? photoCount : (completed ? 1 : 0),
      roomName: roomName,
      roomTypeName: daycare ? '日間安親方案' : '豪華套房',
      bookingCode: daycare ? 'PN2001' : 'PN1001',
      customerName: customer,
      petNames: pets,
      serviceType: daycare
          ? DailyCareServiceTypes.daycare
          : DailyCareServiceTypes.accommodation,
      checkInDate: DateTime(2026, 9, 20),
      checkOutDate: DateTime(2026, 9, 22),
      stayDayIndex: 2,
      stayDayTotal: 2,
    );
  }

  DailyCareReportCenterSnapshot snapshot() {
    return DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
      item(bookingId: 'stay-1', sessionIndex: 0, completed: false),
      item(bookingId: 'stay-1', sessionIndex: 1, completed: true),
      item(
        bookingId: 'day-1',
        sessionIndex: 0,
        completed: false,
        daycare: true,
        customer: '李安親',
        pets: const <String>['橘子'],
        roomName: '',
      ),
    ]);
  }

  Future<void> pumpBoard(
    WidgetTester tester, {
    required Size size,
    DailyCareReportCenterStatusFilter status =
        DailyCareReportCenterStatusFilter.pending,
    DailyCareReportCenterSnapshot? data,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: DailyCareReportCenterBoard(
              key: UniqueKey(),
              snapshot: data ?? snapshot(),
              setting: setting,
              status: status,
              onStatus: (_) {},
              type: DailyCareReportCenterTypeFilter.all,
              onType: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('訂單摘要卡顯示分類、訂單與進度，展開後才出現填寫', (WidgetTester tester) async {
    await pumpBoard(tester, size: const Size(400, 900));
    expect(find.textContaining('9/21（週一）'), findsWidgets);
    expect(find.text('全部 3'), findsWidgets);
    expect(find.text('住宿 2'), findsWidgets);
    expect(find.text('安親 1'), findsWidgets);
    expect(find.text('訂單 PN1001'), findsNothing);
    expect(find.text('PN1001'), findsOneWidget);
    expect(find.textContaining('A1'), findsWidgets);
    expect(find.text('填寫回報'), findsNothing);
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('晨間照護'), findsOneWidget);
    expect(find.text('待填'), findsWidgets);
    expect(find.text('已上傳 0/3'), findsOneWidget);
    expect(find.text('填寫'), findsNothing);
    expect(find.text('類型'), findsNothing);
    expect(find.text('今日回報'), findsNothing);
  });

  testWidgets('手機、平板、桌機三種寬度都不 overflow', (WidgetTester tester) async {
    for (final Size size in <Size>[
      const Size(390, 844),
      const Size(800, 1024),
      const Size(1440, 900),
      const Size(2000, 1100),
    ]) {
      await pumpBoard(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });

  testWidgets('待填空狀態與完全空白文案', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(400, 800),
      data: DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
        item(
          bookingId: 'stay-1',
          sessionIndex: 0,
          completed: true,
          pets: const <String>['小米'],
        ),
      ]),
    );
    expect(find.text('目前沒有待填的每日回報'), findsOneWidget);
    expect(find.text('今天沒有待填的照護回報'), findsNothing);

    await pumpBoard(
      tester,
      size: const Size(400, 800),
      data: DailyCareReportCenterSnapshot.fromItems(
        const <DailyCareReportCenterItem>[],
      ),
    );
    expect(find.text('目前沒有需處理的每日回報'), findsOneWidget);
  });

  testWidgets('已完成卡片可查看編輯回報', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(400, 900),
      status: DailyCareReportCenterStatusFilter.completed,
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    expect(find.text('已完成'), findsWidgets);
    expect(find.text('已上傳 1/3'), findsOneWidget);
    expect(find.text('查看／編輯'), findsNothing);
  });

  testWidgets('結清未完成顯示鎖定且沒有填寫按鈕', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(400, 900),
      status: DailyCareReportCenterStatusFilter.all,
      data: DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
        item(
          bookingId: 'stay-1',
          sessionIndex: 0,
          completed: false,
        ).copyWith(reportsLocked: true, canOperate: false),
        item(
          bookingId: 'stay-1',
          sessionIndex: 1,
          completed: true,
        ).copyWith(reportsLocked: true, canOperate: false, photoCount: 3),
      ]),
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    expect(find.text('填寫'), findsNothing);
    expect(find.text('已鎖定'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('daily-care-session-stay-1-0')),
        matching: find.text('待填'),
      ),
      findsNothing,
    );
    expect(find.text('已完成'), findsWidgets);
    expect(find.text('唯讀查看'), findsNothing);
    final InkWell lockedCard = tester.widget<InkWell>(
      find.byKey(const ValueKey<String>('daily-care-session-stay-1-0')),
    );
    expect(lockedCard.onTap, isNull);
  });

  testWidgets('桌機 1280 以上顯示中間清單與右側快速面板，點選只換右側', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(1400, 900),
      status: DailyCareReportCenterStatusFilter.all,
    );
    expect(tester.takeException(), isNull);

    // 上方統計與左側篩選都出現「歷史未完成」。
    expect(find.text('歷史未完成'), findsNWidgets(2));
    expect(find.text('待填'), findsWidgets);
    expect(find.text('已完成'), findsWidgets);

    // 中間清單顯示兩筆訂單卡。
    expect(find.text('PN1001'), findsWidgets);
    expect(find.text('PN2001'), findsWidgets);
    expect(find.textContaining('已填 '), findsWidgets);

    // 1400 右側不夠 980，維持「快速填寫／回報預覽」二選一。
    expect(find.widgetWithText(ChoiceChip, '快速填寫'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '回報預覽'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('daily-care-quick-split')),
      findsNothing,
    );
    expect(find.text('第 1 場'), findsWidgets);

    await tester.tap(find.text('PN2001').last);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('快速填寫'), findsOneWidget);
  });

  testWidgets('超寬右側並排快速填寫與回報預覽，切場次仍同步', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(2000, 1100),
      status: DailyCareReportCenterStatusFilter.all,
    );
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ChoiceChip, '快速填寫'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '回報預覽'), findsNothing);
    expect(find.text('快速填寫'), findsOneWidget);
    expect(find.text('回報預覽'), findsOneWidget);

    final Rect form = tester.getRect(
      find.byKey(const ValueKey<String>('daily-care-quick-form')),
    );
    final Rect preview = tester.getRect(
      find.byKey(const ValueKey<String>('daily-care-quick-preview')),
    );
    expect(form.width, inInclusiveRange(500, 560));
    expect(preview.width, greaterThanOrEqualTo(400));
    expect(preview.left, greaterThanOrEqualTo(form.right + 16));

    DailyCareRecordEditor editor = tester.widget<DailyCareRecordEditor>(
      find.byType(DailyCareRecordEditor),
    );
    expect(editor.sessionIndex, 0);
    expect(
      find.byKey(const ValueKey<String>('daily-care-quick-preview-stay-1_0')),
      findsOneWidget,
    );

    await tester.tap(find.text('第 2 場'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    editor = tester.widget<DailyCareRecordEditor>(
      find.byType(DailyCareRecordEditor),
    );
    expect(editor.sessionIndex, 1);
    expect(
      find.byKey(const ValueKey<String>('daily-care-quick-preview-stay-1_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('daily-care-quick-preview-stay-1_0')),
      findsNothing,
    );
    expect(find.text('快速填寫'), findsOneWidget);
    expect(find.text('回報預覽'), findsOneWidget);
  });

  testWidgets('1024～1279 維持單欄桌機清單，沒有快速面板', (WidgetTester tester) async {
    await pumpBoard(tester, size: const Size(1100, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('快速填寫'), findsNothing);
    expect(find.text('回報預覽'), findsNothing);
    expect(find.text('分類'), findsOneWidget);
  });

  testWidgets('手機統計維持三項，不出現歷史未完成欄位', (WidgetTester tester) async {
    await pumpBoard(tester, size: const Size(390, 844));
    expect(find.text('歷史未完成'), findsNothing);
    expect(find.text('待填'), findsWidgets);
    expect(find.text('總計'), findsOneWidget);
  });

  testWidgets('窄版場次小卡兩欄，極窄退回單欄，照片上限跟額度', (WidgetTester tester) async {
    const DailyCareEntitlement quota = DailyCareEntitlement(
      enabled: true,
      finalReports: 3,
      photosPerSession: 5,
    );
    final DailyCareReportCenterSnapshot data =
        DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
          item(
            bookingId: 'stay-3',
            sessionIndex: 0,
            completed: false,
            sessionName: '上午場',
            entitlement: quota,
            photoCount: 2,
          ),
          item(
            bookingId: 'stay-3',
            sessionIndex: 1,
            completed: false,
            sessionName: '下午場',
            entitlement: quota,
          ),
          item(
            bookingId: 'stay-3',
            sessionIndex: 2,
            completed: true,
            sessionName: '晚上場',
            entitlement: quota,
            photoCount: 4,
          ),
        ]);

    await pumpBoard(
      tester,
      size: const Size(390, 844),
      status: DailyCareReportCenterStatusFilter.all,
      data: data,
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('已上傳 2/5'), findsOneWidget);
    expect(find.text('已上傳 2/3'), findsNothing);

    Rect cardOf(int index) {
      return tester.getRect(
        find.byKey(ValueKey<String>('daily-care-session-stay-3-$index')),
      );
    }

    final Rect morning = cardOf(0);
    final Rect afternoon = cardOf(1);
    final Rect evening = cardOf(2);
    expect(morning.top, afternoon.top);
    expect(morning.left, lessThan(afternoon.left));
    expect(evening.top, greaterThan(morning.bottom - 1));
    expect(morning.height, greaterThanOrEqualTo(44));
    expect(afternoon.height, greaterThanOrEqualTo(44));

    await pumpBoard(
      tester,
      size: const Size(300, 900),
      status: DailyCareReportCenterStatusFilter.all,
      data: data,
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Rect narrowMorning = cardOf(0);
    final Rect narrowAfternoon = cardOf(1);
    expect(narrowAfternoon.top, greaterThan(narrowMorning.bottom - 1));
    expect(narrowMorning.left, narrowAfternoon.left);
  });

  testWidgets('點擊場次小卡仍開啟原本的填寫頁', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(390, 844),
      status: DailyCareReportCenterStatusFilter.all,
      data: DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
        item(
          bookingId: 'stay-open',
          sessionIndex: 0,
          completed: false,
          sessionName: '上午場',
        ),
        item(
          bookingId: 'stay-open',
          sessionIndex: 1,
          completed: true,
          sessionName: '下午場',
        ),
      ]),
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    final Finder opener = find.byKey(
      const ValueKey<String>('daily-care-session-stay-open-0'),
    );
    expect(opener, findsOneWidget);
    final InkWell well = tester.widget<InkWell>(opener);
    expect(well.onTap, isNotNull);
    await tester.tap(opener);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final DailyCareRecordEditPage page = tester.widget<DailyCareRecordEditPage>(
      find.byType(DailyCareRecordEditPage),
    );
    expect(page.bookingId, 'stay-open');
    expect(page.sessionIndex, 0);
    expect(page.readOnly, isFalse);
  });

  testWidgets('已完成場次小卡仍開啟原本的查看頁', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(390, 844),
      status: DailyCareReportCenterStatusFilter.completed,
      data: DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
        item(
          bookingId: 'stay-done',
          sessionIndex: 1,
          completed: true,
          sessionName: '下午場',
        ),
      ]),
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('daily-care-session-stay-done-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final DailyCareRecordEditPage completed = tester
        .widget<DailyCareRecordEditPage>(find.byType(DailyCareRecordEditPage));
    expect(completed.bookingId, 'stay-done');
    expect(completed.sessionIndex, 1);
    expect(completed.readOnly, isFalse);
  });

  testWidgets('已鎖定且已完成的場次小卡以唯讀開啟', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      size: const Size(390, 844),
      status: DailyCareReportCenterStatusFilter.all,
      data: DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
        item(
          bookingId: 'stay-locked',
          sessionIndex: 0,
          completed: true,
          sessionName: '上午場',
          reportsLocked: true,
        ),
      ]),
    );
    await tester.tap(find.text('PN1001'));
    await tester.pumpAndSettle();
    expect(find.text('已鎖定'), findsNothing);
    expect(find.text('已完成'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey<String>('daily-care-session-stay-locked-0')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final DailyCareRecordEditPage page = tester.widget<DailyCareRecordEditPage>(
      find.byType(DailyCareRecordEditPage),
    );
    expect(page.sessionIndex, 0);
    expect(page.readOnly, isTrue);
  });
}
