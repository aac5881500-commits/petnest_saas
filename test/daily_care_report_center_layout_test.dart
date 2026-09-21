// 檔案名稱：test/daily_care_report_center_layout_test.dart
// 功能說明：每日回報中心房卡呈現與手機／平板／桌機寬度不 overflow。

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
  }) {
    return DailyCareReportCenterItem(
      id: '${bookingId}_$sessionIndex',
      shopId: 's1',
      bookingId: bookingId,
      sessionIndex: sessionIndex,
      sessionName: daycare ? '日間安親' : (sessionIndex == 0 ? '晨間照護' : '晚間照護'),
      recordDate: today,
      entitlement: const DailyCareEntitlement(enabled: true, finalReports: 2),
      isCompleted: completed,
      roomName: roomName,
      roomTypeName: '豪華套房',
      bookingCode: 'PN1001',
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
      ),
    ]);
  }

  Future<void> pumpBoard(
    WidgetTester tester, {
    required Size size,
    DailyCareReportCenterStatusFilter status =
        DailyCareReportCenterStatusFilter.pending,
    DailyCareReportCenterTypeFilter type = DailyCareReportCenterTypeFilter.all,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: DailyCareReportCenterBoard(
              snapshot: snapshot(),
              setting: setting,
              status: status,
              type: type,
              onStatus: (_) {},
              onType: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('同一訂單多場次只顯示一張房間卡', (WidgetTester tester) async {
    await pumpBoard(tester, size: const Size(400, 900));
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('晨間照護 待填'), findsOneWidget);
    expect(find.text('晚間照護 已完成'), findsOneWidget);
    expect(find.text('立即填寫'), findsWidgets);
    expect(find.textContaining('小米、橘子 +1'), findsOneWidget);
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

  testWidgets('待填空狀態與已完成空狀態有文案', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(
            body: DailyCareReportCenterBoard(
              snapshot: DailyCareReportCenterSnapshot.fromItems(
                <DailyCareReportCenterItem>[
                  item(
                    bookingId: 'stay-1',
                    sessionIndex: 0,
                    completed: true,
                    pets: const <String>['小米'],
                  ),
                ],
              ),
              setting: setting,
              status: DailyCareReportCenterStatusFilter.pending,
              type: DailyCareReportCenterTypeFilter.all,
              onStatus: (_) {},
              onType: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('今天沒有待填的照護回報'), findsOneWidget);
    expect(find.textContaining('已完成'), findsWidgets);
  });
}
