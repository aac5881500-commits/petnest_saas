// 檔案名稱：test/daily_care_report_center_test.dart
// 功能說明：每日回報中心資格、場次、排序與 Dashboard 文案，不連真實 Firebase。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_photo_model.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_session_status.dart';
import 'package:petnest_saas/core/services/daily_care_report_write_access.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_date_group.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_room_group.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/services/daily_care_report_center_service.dart';
import 'package:petnest_saas/core/services/daily_care_report_eligibility.dart';
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
      'bookingCode': 'PN1001',
      'roomTypeName': '豪華套房',
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': '小米',
          'petId': 'p1',
          'photoUrl': 'https://img.example/cat.png',
        },
      ],
      'startDate': checkIn ?? DateTime(2026, 9, 20),
      'endDate': checkOut ?? DateTime(2026, 9, 22),
      'dailyCareEntitlement': ?entitlement,
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
      'scheduledStartAt': DateTime(2026, 9, 21, 1, 0),
      'scheduledEndAt': DateTime(2026, 9, 21, 10, 0),
      'dailyCareEntitlement': ?entitlement,
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

  test('舊住宿訂單沒有快照時依住宿設定 fallback 列入', () {
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
    expect(
      snapshot.items.any(
        (DailyCareReportCenterItem item) => item.bookingId == 'stay-1',
      ),
      isTrue,
    );
    expect(
      snapshot.items.any(
        (DailyCareReportCenterItem item) => item.bookingId == 'stay-off',
      ),
      isTrue,
    );
    expect(snapshot.totalCount, DailyCareReportMode.maxSessions * 4);
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
    expect(snapshot.totalCount, 4);
    expect(snapshot.pendingCount, 4);
    expect(
      snapshot.items.map((DailyCareReportCenterItem e) => e.sessionIndex),
      <int>[0, 1, 0, 1],
    );
    expect(snapshot.items.first.sessionName, '上午場');
    expect(snapshot.items.first.roomId, 'r-1');
    expect(snapshot.items.first.roomName, 'A1');
    expect(snapshot.items.first.petIds, <String>['p1']);
    expect(snapshot.items.first.bookingCode, 'PN1001');
    expect(snapshot.items.first.roomTypeName, '豪華套房');
    expect(snapshot.items.first.petPhotoUrl, 'https://img.example/cat.png');
    expect(snapshot.items.first.stayDayTotal, 2);
    expect(snapshot.items.first.stayDayIndex, 1);
    expect(
      snapshot.items.map((DailyCareReportCenterItem e) => e.recordDate).toSet(),
      <DateTime>{DateTime(2026, 9, 20), DateTime(2026, 9, 21)},
    );
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
    expect(snapshot.pendingCount, 3);
    expect(snapshot.items.first.isCompleted, isFalse);
    expect(snapshot.items.last.isCompleted, isTrue);
    expect(snapshot.items.last.updatedAt, DateTime(2026, 9, 21, 10, 30));
  });

  test('安親已開始即可列入，含昨日服務日；pending 未開始不列入', () {
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
    expect(snapshot.totalCount, 2);
    expect(
      snapshot.items.map((DailyCareReportCenterItem e) => e.bookingId).toSet(),
      <String>{'day-1', 'day-old'},
    );
    expect(
      snapshot.items.every(
        (DailyCareReportCenterItem item) =>
            item.serviceType == DailyCareServiceTypes.daycare,
      ),
      isTrue,
    );
    expect(snapshot.items.first.placeLabel, '安親');
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

  test('住宿與安親同時列入，互不因對方關閉而消失', () {
    final DailyCareReportCenterSnapshot both =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(entitlement: entitled(reports: 2)),
            daycareBooking(entitlement: entitled(reports: 1)),
          ],
          canOperate: true,
          today: today,
        );
    expect(
      both.items.any(
        (DailyCareReportCenterItem item) =>
            item.serviceType == DailyCareServiceTypes.accommodation,
      ),
      isTrue,
    );
    expect(
      both.items.any(
        (DailyCareReportCenterItem item) =>
            item.serviceType == DailyCareServiceTypes.daycare,
      ),
      isTrue,
    );
    expect(both.totalCount, 5);
    expect(both.stayCount, 4);
    expect(both.daycareCount, 1);

    final DailyCareReportCenterSnapshot daycareOnly =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: const DailyCareSettingModel(
            enabled: false,
            daycareEnabled: true,
            daycareSessionCount: 1,
          ),
          checkedIn: <Map<String, dynamic>>[
            stayBooking(entitlement: entitled(reports: 2)),
            daycareBooking(entitlement: entitled(reports: 1)),
          ],
          canOperate: true,
          today: today,
        );
    expect(daycareOnly.settingEnabled, isTrue);
    expect(
      daycareOnly.items.every(
        (DailyCareReportCenterItem item) => item.isDaycare,
      ),
      isTrue,
    );
    expect(daycareOnly.totalCount, 1);
  });

  test('昨日未填住宿回報會列入，日期標題為 9/23（週三）', () {
    final DateTime now = DateTime(2026, 9, 24);
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(
              entitlement: entitled(
                reports: 3,
                labels: <String>['上午場', '下午場', '晚上場'],
              ),
              checkIn: DateTime(2026, 9, 23),
              checkOut: DateTime(2026, 9, 24),
              status: 'checked_out',
            ),
          ],
          canOperate: true,
          today: now,
        );
    // 訂單已結束：只算歷史未完成，不再是可執行的待填工作。
    expect(snapshot.pendingCount, 0);
    expect(snapshot.historyIncompleteCount, 3);
    expect(
      snapshot.items.every(
        (DailyCareReportCenterItem item) =>
            item.reportsLocked && !item.canOperate,
      ),
      isTrue,
    );
    expect(
      snapshot.items.every(
        (DailyCareReportCenterItem item) =>
            item.isHistoryIncomplete && !item.isPendingFill && !item.canFill,
      ),
      isTrue,
    );
    expect(snapshot.items.first.statusLabel, '歷史未完成・已鎖定');
    expect(snapshot.completedCount, 0);
    expect(snapshot.hasError, isFalse);
    expect(
      snapshot.items.every(
        (DailyCareReportCenterItem item) =>
            item.recordDate == DateTime(2026, 9, 23),
      ),
      isTrue,
    );
    expect(snapshot.items.first.recordDateHeading, '9/23（週三）');
    expect(
      snapshot.items.map((DailyCareReportCenterItem e) => e.sessionName),
      <String>['上午場', '下午場', '晚上場'],
    );
  });

  test('已退房的已完成回報仍會出現在中心', () {
    final DateTime careDay = DateTime(2026, 9, 23);
    final String filled = DailyCareRecordService.recordId(
      bookingId: 'stay-1',
      recordDate: careDay,
      sessionIndex: 0,
    );
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(
              entitlement: entitled(reports: 2),
              checkIn: careDay,
              checkOut: DateTime(2026, 9, 24),
              status: 'checked_out',
            ),
          ],
          canOperate: true,
          today: DateTime(2026, 9, 24),
          completedIds: <String>{filled},
        );
    expect(snapshot.pendingCount, 0);
    expect(snapshot.historyIncompleteCount, 1);
    expect(snapshot.completedCount, 1);
    expect(snapshot.items.first.sessionIndex, 1);
    expect(snapshot.items.last.isCompleted, isTrue);
  });

  test('已存紀錄即以 bookingId＋日期＋場次合併為已完成，即使文件 id 不同', () {
    final DateTime careDay = DateTime(2026, 9, 23);
    final DailyCareRecordModel saved = DailyCareRecordModel(
      id: 'legacy-random-id',
      shopId: 's1',
      bookingId: 'stay-1',
      roomId: 'r-1',
      roomName: 'A1',
      recordDate: careDay,
      sessionIndex: 0,
      sessionName: '上午場',
      values: const <String, dynamic>{'water': 'ok'},
      petNotes: const <String, String>{},
      photoCount: 0,
      createdAt: DateTime(2026, 9, 23, 9),
      updatedAt: DateTime(2026, 9, 23, 9),
    );
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(
              entitlement: entitled(reports: 2),
              checkIn: careDay,
              checkOut: DateTime(2026, 9, 24),
            ),
          ],
          canOperate: true,
          today: careDay,
          records: <DailyCareRecordModel>[saved],
        );
    expect(snapshot.completedCount, 1);
    expect(snapshot.pendingCount, 1);
    expect(snapshot.items.first.isCompleted, isFalse);
    expect(snapshot.items.last.isCompleted, isTrue);
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
      '目前沒有待填回報',
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

  DailyCareReportCenterItem session({
    required String id,
    required String bookingId,
    required int sessionIndex,
    required bool completed,
    String roomName = 'A1',
    bool daycare = false,
    String customer = '王小明',
    DateTime? daycareStart,
    String sessionName = '',
    DateTime? recordDate,
  }) {
    return DailyCareReportCenterItem(
      id: id,
      shopId: 's1',
      bookingId: bookingId,
      sessionIndex: sessionIndex,
      sessionName: sessionName.isEmpty
          ? '第 ${sessionIndex + 1} 場'
          : sessionName,
      recordDate: recordDate ?? today,
      entitlement: const DailyCareEntitlement(enabled: true, finalReports: 2),
      isCompleted: completed,
      roomName: roomName,
      customerName: customer,
      serviceType: daycare
          ? DailyCareServiceTypes.daycare
          : DailyCareServiceTypes.accommodation,
      daycareStartAt: daycareStart,
    );
  }

  test('同一訂單多場次回報組成一張房間卡並計算 completed / pending', () {
    final List<DailyCareReportCenterRoomGroup> groups =
        DailyCareReportCenterGrouping.groupByBooking(
          <DailyCareReportCenterItem>[
            session(
              id: 'a0',
              bookingId: 'stay-1',
              sessionIndex: 1,
              completed: true,
            ),
            session(
              id: 'a1',
              bookingId: 'stay-1',
              sessionIndex: 0,
              completed: false,
            ),
            session(
              id: 'b0',
              bookingId: 'stay-2',
              sessionIndex: 0,
              completed: true,
              roomName: 'B2',
            ),
          ],
        );
    expect(groups.length, 2);
    final DailyCareReportCenterRoomGroup stay1 = groups.firstWhere(
      (DailyCareReportCenterRoomGroup g) => g.bookingId == 'stay-1',
    );
    expect(
      stay1.sessions.map((DailyCareReportCenterItem e) => e.sessionIndex),
      <int>[0, 1],
    );
    expect(stay1.pendingCount, 1);
    expect(stay1.completedCount, 1);
    expect(stay1.nextPending?.sessionIndex, 0);
    expect(stay1.primaryActionLabel, '立即填寫');
    expect(stay1.primaryActionSession.sessionIndex, 0);
  });

  test('多場待填按鈕為填寫下一場，並帶正確 sessionIndex', () {
    final DailyCareReportCenterRoomGroup group =
        DailyCareReportCenterGrouping.groupByBooking(
          <DailyCareReportCenterItem>[
            session(
              id: 'a0',
              bookingId: 'stay-1',
              sessionIndex: 0,
              completed: false,
            ),
            session(
              id: 'a1',
              bookingId: 'stay-1',
              sessionIndex: 1,
              completed: false,
            ),
          ],
        ).single;
    expect(group.pendingCount, 2);
    expect(group.primaryActionLabel, '填寫下一場');
    expect(group.primaryActionSession.sessionIndex, 0);
  });

  test('篩選待填／已完成與住宿／安親以房間卡為單位', () {
    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[
      session(
        id: 'a0',
        bookingId: 's-a',
        sessionIndex: 0,
        completed: false,
        roomName: 'A10',
      ),
      session(
        id: 'a1',
        bookingId: 's-a',
        sessionIndex: 1,
        completed: true,
        roomName: 'A10',
      ),
      session(
        id: 'b0',
        bookingId: 's-b',
        sessionIndex: 0,
        completed: true,
        roomName: 'A2',
      ),
      session(
        id: 'd0',
        bookingId: 'd-1',
        sessionIndex: 0,
        completed: false,
        daycare: true,
        customer: '李安親',
        daycareStart: DateTime(2026, 9, 21, 8),
      ),
    ];
    final List<DailyCareReportCenterRoomGroup> pendingStay =
        DailyCareReportCenterGrouping.visible(
          items: items,
          status: DailyCareReportCenterStatusFilter.pending,
        );
    expect(
      pendingStay.map((DailyCareReportCenterRoomGroup g) => g.bookingId),
      <String>['s-a', 'd-1'],
    );
    final List<DailyCareReportCenterRoomGroup> done =
        DailyCareReportCenterGrouping.visible(
          items: items,
          status: DailyCareReportCenterStatusFilter.completed,
        );
    expect(
      done.map((DailyCareReportCenterRoomGroup g) => g.bookingId),
      <String>['s-b'],
    );
    final List<DailyCareReportCenterRoomGroup> all =
        DailyCareReportCenterGrouping.visible(
          items: items,
          status: DailyCareReportCenterStatusFilter.all,
        );
    expect(
      all.map((DailyCareReportCenterRoomGroup g) => g.bookingId).toSet(),
      <String>{'s-a', 's-b', 'd-1'},
    );
  });

  test('排序：待填較多在前，住宿房號自然排序，安親在住宿後，全完成最後', () {
    final List<DailyCareReportCenterRoomGroup> groups =
        DailyCareReportCenterGrouping.visible(
          items: <DailyCareReportCenterItem>[
            session(
              id: 'done',
              bookingId: 'z',
              sessionIndex: 0,
              completed: true,
              roomName: 'A1',
            ),
            session(
              id: 'a2-0',
              bookingId: 'a2',
              sessionIndex: 0,
              completed: false,
              roomName: 'A2',
            ),
            session(
              id: 'a10-0',
              bookingId: 'a10',
              sessionIndex: 0,
              completed: false,
              roomName: 'A10',
            ),
            session(
              id: 'a10-1',
              bookingId: 'a10',
              sessionIndex: 1,
              completed: false,
              roomName: 'A10',
            ),
            session(
              id: 'day',
              bookingId: 'day',
              sessionIndex: 0,
              completed: false,
              daycare: true,
              daycareStart: DateTime(2026, 9, 21, 9),
            ),
          ],
          status: DailyCareReportCenterStatusFilter.all,
        );
    expect(
      groups.map((DailyCareReportCenterRoomGroup g) => g.bookingId).toList(),
      <String>['a10', 'a2', 'day', 'z'],
    );
  });

  test('依日期分組，標題為月日與星期', () {
    final List<DailyCareReportCenterDateGroup> groups =
        DailyCareReportCenterDateGrouping.visible(
          items: <DailyCareReportCenterItem>[
            session(
              id: 'new',
              bookingId: 's-new',
              sessionIndex: 0,
              completed: false,
              recordDate: DateTime(2026, 9, 24),
            ),
            session(
              id: 'old',
              bookingId: 's-old',
              sessionIndex: 1,
              completed: false,
              recordDate: DateTime(2026, 9, 23),
            ),
            session(
              id: 'done',
              bookingId: 's-done',
              sessionIndex: 0,
              completed: true,
              recordDate: DateTime(2026, 9, 23),
            ),
          ],
          status: DailyCareReportCenterStatusFilter.all,
        );
    expect(
      groups.map((DailyCareReportCenterDateGroup g) => g.heading),
      <String>['9/23（週三）', '9/24（週四）'],
    );
    expect(groups.first.bookings.first.bookingId, 's-old');
    expect(groups.first.bookings.last.bookingId, 's-done');
    expect(groups.last.bookings.single.bookingId, 's-new');
  });

  test('鎖定未完成算歷史未完成，不算待填，且只在對應篩選出現', () {
    final DailyCareReportCenterItem locked = session(
      id: 'locked',
      bookingId: 's-locked',
      sessionIndex: 0,
      completed: false,
    ).copyWith(reportsLocked: true, canOperate: false);
    final DailyCareReportCenterItem pending = session(
      id: 'pending',
      bookingId: 's-pending',
      sessionIndex: 0,
      completed: false,
    );
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterSnapshot.fromItems(<DailyCareReportCenterItem>[
          locked,
          pending,
        ]);

    expect(locked.status, DailyCareReportCenterItemStatus.historyIncomplete);
    expect(locked.isPendingFill, isFalse);
    expect(locked.canFill, isFalse);
    expect(pending.status, DailyCareReportCenterItemStatus.pending);
    expect(snapshot.pendingCount, 1);
    expect(snapshot.historyIncompleteCount, 1);
    expect(snapshot.completedCount, 0);
    expect(snapshot.totalCount, 2);

    final List<String> pendingOnly = snapshot
        .filtered(status: DailyCareReportCenterStatusFilter.pending)
        .map((DailyCareReportCenterItem item) => item.bookingId)
        .toList();
    expect(pendingOnly, <String>['s-pending']);

    final List<String> historyOnly = snapshot
        .filtered(status: DailyCareReportCenterStatusFilter.historyIncomplete)
        .map((DailyCareReportCenterItem item) => item.bookingId)
        .toList();
    expect(historyOnly, <String>['s-locked']);

    expect(
      snapshot
          .filtered(status: DailyCareReportCenterStatusFilter.all)
          .map((DailyCareReportCenterItem item) => item.bookingId)
          .toSet(),
      <String>{'s-locked', 's-pending'},
    );

    final List<DailyCareReportCenterDateGroup> historyGroups =
        DailyCareReportCenterDateGrouping.visible(
          items: <DailyCareReportCenterItem>[locked, pending],
          status: DailyCareReportCenterStatusFilter.historyIncomplete,
        );
    expect(
      historyGroups.single.bookings
          .map((DailyCareReportCenterBookingDayGroup g) => g.bookingId)
          .toList(),
      <String>['s-locked'],
    );
  });

  test('混合已完成與鎖定未完成時，統計與日期標題數字正確', () {
    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[
      session(
        id: 'done',
        bookingId: 's-mix',
        sessionIndex: 0,
        completed: true,
      ).copyWith(reportsLocked: true, canOperate: false),
      session(
        id: 'missed',
        bookingId: 's-mix',
        sessionIndex: 1,
        completed: false,
      ).copyWith(reportsLocked: true, canOperate: false),
    ];
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterSnapshot.fromItems(items);
    expect(snapshot.pendingCount, 0);
    expect(snapshot.historyIncompleteCount, 1);
    expect(snapshot.completedCount, 1);

    final DailyCareReportCenterDateGroup group =
        DailyCareReportCenterDateGrouping.visible(
          items: items,
          status: DailyCareReportCenterStatusFilter.all,
        ).single;
    expect(group.pendingCount, 0);
    expect(group.historyIncompleteCount, 1);
    expect(group.title, '9/21（週一）  已完成 1 場・歷史未完成 1 場');
    expect(group.bookings.single.progressLabel, '已填 1/2 場');
    expect(group.bookings.single.missingLabel, '尚缺 1 場');

    // 只剩鎖定未完成時，標題不可再寫成待填。
    final DailyCareReportCenterDateGroup onlyHistory =
        DailyCareReportCenterDateGrouping.visible(
          items: <DailyCareReportCenterItem>[items.last],
          status: DailyCareReportCenterStatusFilter.all,
        ).single;
    expect(onlyHistory.title, '9/21（週一）  歷史未完成 1 場');

    final DailyCareReportCenterDateGroup onlyPending =
        DailyCareReportCenterDateGrouping.visible(
          items: <DailyCareReportCenterItem>[
            session(
              id: 'p',
              bookingId: 's-p',
              sessionIndex: 0,
              completed: false,
            ),
          ],
          status: DailyCareReportCenterStatusFilter.all,
        ).single;
    expect(onlyPending.title, '9/21（週一）  待填 1 場');
  });

  test('住宿場次數為照護日期乘每日 finalReports，不硬寫', () {
    final Map<String, dynamic> booking = stayBooking(
      checkIn: DateTime(2026, 9, 21),
      checkOut: DateTime(2026, 9, 22),
      entitlement: entitled(reports: 3, labels: <String>['上午場', '下午場', '晚場']),
    );
    expect(DailyCareReportEligibility.stayScheduledSessionTotal(booking), 3);
  });

  test('第一個未完成場次依既有紀錄判斷，全完成才回到第 0 場', () {
    expect(
      DailyCareReportEligibility.firstIncompleteSessionIndex(
        sessionCount: 3,
        completedIndexes: const <int>{},
      ),
      0,
    );
    expect(
      DailyCareReportEligibility.firstIncompleteSessionIndex(
        sessionCount: 3,
        completedIndexes: const <int>{0},
      ),
      1,
    );
    expect(
      DailyCareReportEligibility.firstIncompleteSessionIndex(
        sessionCount: 3,
        completedIndexes: const <int>{0, 1},
      ),
      2,
    );
    expect(
      DailyCareReportEligibility.firstIncompleteSessionIndex(
        sessionCount: 3,
        completedIndexes: const <int>{0, 1, 2},
      ),
      0,
    );
  });

  test('完成場次照片數依 daily_care_photos 計算，結清後鎖定不可寫', () {
    final DateTime day = DateTime(2026, 9, 21);
    final String recordId = DailyCareRecordService.recordId(
      bookingId: 'stay-1',
      recordDate: day,
      sessionIndex: 0,
    );
    final DailyCarePhotoModel photo = DailyCarePhotoModel(
      id: 'p1',
      shopId: 's1',
      bookingId: 'stay-1',
      roomId: 'r-1',
      roomName: 'A1',
      recordDate: day,
      sessionIndex: 0,
      sessionName: '上午場',
      previewUrl: 'https://img.example/1.jpg',
      previewStoragePath: 'path',
      createdAt: day,
      dailyCareRecordId: recordId,
    );
    final DailyCareReportCenterSnapshot snapshot =
        DailyCareReportCenterService.buildTodaySnapshot(
          shopId: 's1',
          setting: enabledSetting,
          checkedIn: <Map<String, dynamic>>[
            stayBooking(
              entitlement: entitled(reports: 2, labels: <String>['上午場', '下午場']),
              status: 'completed',
              checkIn: day,
              checkOut: DateTime(2026, 9, 22),
            ),
          ],
          canOperate: true,
          today: day,
          records: <DailyCareRecordModel>[
            DailyCareRecordModel(
              id: recordId,
              shopId: 's1',
              bookingId: 'stay-1',
              roomId: 'r-1',
              roomName: 'A1',
              recordDate: day,
              sessionIndex: 0,
              sessionName: '上午場',
              values: const <String, dynamic>{'temperature': '26'},
              petNotes: const <String, String>{},
              photoCount: 0,
              createdAt: day,
              updatedAt: day,
            ),
          ],
          photos: <DailyCarePhotoModel>[photo],
        );
    final DailyCareReportCenterItem filled = snapshot.items.firstWhere(
      (DailyCareReportCenterItem item) => item.sessionIndex == 0,
    );
    final DailyCareReportCenterItem pending = snapshot.items.firstWhere(
      (DailyCareReportCenterItem item) => item.sessionIndex == 1,
    );
    expect(filled.isCompleted, isTrue);
    expect(filled.photoCount, 1);
    expect(filled.reportsLocked, isTrue);
    expect(filled.canOperate, isFalse);
    expect(pending.isCompleted, isFalse);
    expect(
      DailyCareSessionStatus.sessionLine(
        completed: true,
        photoCount: 1,
        locked: false,
      ),
      '已完成｜照片 1/3 張',
    );
    expect(
      DailyCareSessionStatus.sessionLine(
        completed: true,
        photoCount: 3,
        locked: true,
      ),
      '已完成｜照片 3/3 張｜唯讀',
    );
    expect(
      DailyCareSessionStatus.bookingLockBanner(missingCount: 2),
      '已結清｜尚缺 2 場回報（已鎖定）',
    );
    expect(
      DailyCareReportWriteAccess.canWrite(<String, dynamic>{
        'status': 'checked_in',
      }),
      isTrue,
    );
    expect(
      DailyCareReportWriteAccess.canWrite(<String, dynamic>{
        'status': 'checked_in',
        'settlementConfirmed': true,
      }),
      isFalse,
    );
    expect(
      DailyCareReportWriteAccess.canWrite(<String, dynamic>{
        'status': 'checked_out',
      }),
      isFalse,
    );
    expect(
      DailyCareReportWriteAccess.canWrite(<String, dynamic>{
        'bookingKind': 'daycare',
        'status': 'completed',
      }),
      isFalse,
    );
  });
}
