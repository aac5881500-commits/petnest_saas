// 檔案名稱：test/daily_care_report_center_layout_test.dart
// 功能說明：每日回報中心訂單摘要卡與手機／平板／桌機寬度不 overflow。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
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
  }) {
    return DailyCareReportCenterItem(
      id: '${bookingId}_$sessionIndex',
      shopId: 's1',
      bookingId: bookingId,
      sessionIndex: sessionIndex,
      sessionName: daycare ? '日間安親' : (sessionIndex == 0 ? '晨間照護' : '晚間照護'),
      recordDate: recordDate ?? today,
      entitlement: const DailyCareEntitlement(enabled: true, finalReports: 2),
      isCompleted: completed,
      reportsLocked: false,
      photoCount: completed ? 1 : 0,
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
    expect(find.text('填寫'), findsWidgets);
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
    expect(find.text('查看／編輯'), findsOneWidget);
    expect(find.textContaining('照片 1/3 張'), findsWidgets);
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
    expect(find.textContaining('未完成｜訂單已結清｜已鎖定'), findsOneWidget);
    expect(find.textContaining('已完成｜照片 3/3 張｜唯讀'), findsOneWidget);
  });
}
