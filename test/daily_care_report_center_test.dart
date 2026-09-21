// 檔案名稱：test/daily_care_report_center_test.dart
// 功能說明：每日回報中心資格、場次、排序與 Dashboard 文案，不連真實 Firebase。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/services/daily_care_report_center_service.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_report_center_page.dart';

void main() {
  final DateTime today = DateTime(2026, 9, 21);
  const DailyCareSettingModel enabledSetting = DailyCareSettingModel(
    enabled: true,
    sessionCount: 5,
    daycareEnabled: true,
  );

  Map<String, dynamic> stayBooking({
    String id = 'stay-1',
    Map<String, dynamic>? entitlement,
    String status = 'checked_in',
    DateTime? checkIn,
    DateTime? checkOut,
  }) {
    return <String, dynamic>{
      'bookingId': id,
      'status': status,
      'bookingKind': BookingKind.accommodation,
      'roomId': 'r-1',
      'roomName': 'A1',
      'customerName': '王小明',
      'petIds': <String>['p1'],
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{'name': '小米', 'petId': 'p1'},
      ],
      'startDate': checkIn ?? DateTime(2026, 9, 20),
      'endDate': checkOut ?? DateTime(2026, 9, 22),
      if (entitlement != null) 'dailyCareEntitlement': entitlement,
    };
  }

  Map<String, dynamic> daycareBooking({
    String id = 'day-1',
    Map<String, dynamic>? entitlement,
    String status = 'checked_in',
    String serviceDate = '2026/09/21',
  }) {
    return <String, dynamic>{
      'bookingId': id,
      'status': status,
      'bookingKind': BookingKind.daycare,
      'serviceType': DailyCareServiceTypes.daycare,
      'customerName': '李安親',
      'petIds': <String>['d1'],
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{'name': '橘子', 'petId': 'd1'},
      ],
      'serviceDate': serviceDate,
      if (entitlement != null) 'dailyCareEntitlement': entitlement,
    };
  }

  Map<String, dynamic> entitled({int reports = 2, List<String>? labels}) {
    return <String, dynamic>{
      'enabled': true,
      'finalReports': reports,
      'sessionLabels': labels ?? <String>['上午場', '下午場'],
    };
  }

  test('店家開關關閉時 snapshot 為空且 Dashboard 不顯示', () {
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: const DailyCareSettingModel(enabled: false),
          checkedIn: <Map<String, dynamic>>[
            stayBooking(entitlement: entitled()),
          ],
          canOperate: true,
          today: today,
        );
    expect(snapshot.settingEnabled, isFalse);
    expect(snapshot.items, isEmpty);
    expect(snapshot.pendingCount, 0);
  });

  test('住宿沒有有效 entitlement 不列入', () {
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(),
            stayBooking(
              id: 'stay-off',
              entitlement: <String, dynamic>{
                'enabled': false,
                'finalReports': 2,
              },
            ),
          ],
          canOperate: true,
          today: today,
        );
    expect(snapshot.items, isEmpty);
  });

  test('住宿場次數以 entitlement.finalReports 為準，不受 setting.sessionCount 影響', () {
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(entitlement: entitled(reports: 2)),
          ],
          canOperate: true,
          today: today,
        );
    expect(snapshot.totalCount, 2);
    expect(snapshot.pendingCount, 2);
    expect(
      snapshot.items.map((DailyCareReportCenterItem e) => e.sessionIndex),
      <int>[0, 1],
    );
    expect(snapshot.items.first.sessionName, '上午場');
    expect(snapshot.items.first.roomId, 'r-1');
    expect(snapshot.items.first.roomName, 'A1');
    expect(snapshot.items.first.petIds, <String>['p1']);
    expect(
      snapshot.items.first.serviceType,
      DailyCareServiceTypes.accommodation,
    );
  });

  test('deterministic recordId 存在視為已完成，不存在為待填，待填排前面', () {
    final String completedId = DailyCareRecordService.recordId(
      bookingId: 'stay-1',
      recordDate: today,
      sessionIndex: 0,
    );
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(entitlement: entitled()),
          ],
          canOperate: true,
          today: today,
          completedIds: <String>{completedId},
          updatedAtById: <String, DateTime?>{
            completedId: DateTime(2026, 9, 21, 10, 30),
          },
        );
    expect(snapshot.completedCount, 1);
    expect(snapshot.pendingCount, 1);
    expect(snapshot.items.first.isCompleted, isFalse);
    expect(snapshot.items.last.isCompleted, isTrue);
    expect(snapshot.items.last.updatedAt, DateTime(2026, 9, 21, 10, 30));
  });

  test('安親符合 canOperate 且為今日服務才列入，serviceType 為 daycare', () {
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            daycareBooking(entitlement: entitled(reports: 1)),
            daycareBooking(
              id: 'day-old',
              entitlement: entitled(reports: 1),
              serviceDate: '2026/09/20',
            ),
            daycareBooking(
              id: 'day-wait',
              entitlement: entitled(reports: 1),
              status: 'pending',
            ),
          ],
          canOperate: true,
          today: today,
        );
    expect(snapshot.totalCount, 1);
    expect(snapshot.items.single.serviceType, DailyCareServiceTypes.daycare);
    expect(snapshot.items.single.placeLabel, '安親');
    expect(snapshot.items.single.roomId, isEmpty);
    expect(snapshot.items.single.petIds, <String>['d1']);
  });

  test('安親 daycareEnabled 關閉則不列入', () {
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: const DailyCareSettingModel(
            enabled: true,
            daycareEnabled: false,
          ),
          checkedIn: <Map<String, dynamic>>[
            daycareBooking(entitlement: entitled(reports: 1)),
          ],
          canOperate: true,
          today: today,
        );
    expect(snapshot.items, isEmpty);
  });

  test('Dashboard 副標題與 badge 使用待填數', () {
    final DailyCareReportCenterSnapshot pending =
        DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
          DailyCareReportCenterItem(
            id: 'a',
            shopId: 's1',
            bookingId: 'b1',
            sessionIndex: 0,
            sessionName: '第 1 場',
            recordDate: today,
            entitlement: const DailyCareEntitlement(
              enabled: true,
              finalReports: 1,
            ),
            isCompleted: false,
          ),
          DailyCareReportCenterItem(
            id: 'b',
            shopId: 's1',
            bookingId: 'b1',
            sessionIndex: 1,
            sessionName: '第 2 場',
            recordDate: today,
            entitlement: const DailyCareEntitlement(
              enabled: true,
              finalReports: 1,
            ),
            isCompleted: true,
          ),
        ]);
    expect(pending.pendingCount, 1);
    expect(
      DailyCareReportCenterMenuCopy.subtitle(
        profileComplete: true,
        snapshot: pending,
      ),
      '待填 1 場・已完成 1 場',
    );
    expect(
      DailyCareReportCenterMenuCopy.subtitle(
        profileComplete: false,
        snapshot: pending,
      ),
      '請先完成基本資料',
    );
    final DailyCareReportCenterSnapshot done =
        DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
          pending.items.last,
        ]);
    expect(
      DailyCareReportCenterMenuCopy.subtitle(
        profileComplete: true,
        snapshot: done,
      ),
      '今日回報已完成',
    );
  });

  test('今日日期使用 Taipei helper 而不是直接 DateTime.now 日曆', () {
    final DateTime utcLate = DateTime.utc(2026, 9, 20, 16, 30);
    expect(DailyCareDateHelper.todayInTaipei(utcLate), DateTime(2026, 9, 21));
  });

  test('recordId 為 bookingId_yyyyMMdd_sessionIndex，不新增 collection', () {
    expect(
      DailyCareRecordService.recordId(
        bookingId: 'stay-1',
        recordDate: today,
        sessionIndex: 1,
      ),
      'stay-1_20260921_1',
    );
  });
}
