// 檔案名稱：test/booking_list_filter_counts_test.dart
// 功能說明：住宿／安親篩選膠囊條件與 chip key 必須對齊。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/services/booking_list_query_service.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/features/admin/widgets/admin_paged_booking_list.dart';
import 'package:petnest_saas/features/admin/widgets/booking_status_filter.dart';

void main() {
  test('住宿與安親 chip type 都有對應 count key', () {
    expect(
      BookingStatusFilter.stayItems.map((BookingFilterChipSpec e) => e.type),
      BookingListQueryService.stayChipKeys,
    );
    expect(
      BookingStatusFilter.daycareItems.map((BookingFilterChipSpec e) => e.type),
      BookingListQueryService.daycareChipKeys,
    );
    expect(
      BookingStatusFilter.stayItems.any(
        (BookingFilterChipSpec e) => e.type == 'checked_in' && e.label == '入住中',
      ),
      isTrue,
    );
    expect(
      BookingStatusFilter.daycareItems.any(
        (BookingFilterChipSpec e) => e.type == 'checked_in' && e.label == '安親中',
      ),
      isTrue,
    );
    expect(BookingStatusFilter.stayItems.first.label, '全部');
    expect(BookingStatusFilter.stayItems.last.label, '已取消');
    expect(
      BookingStatusFilter.stayItems.map((BookingFilterChipSpec e) => e.label),
      containsAll(<String>['結清', '今日入住', '今日退房', '未來入住']),
    );
    expect(
      BookingStatusFilter.daycareItems.map(
        (BookingFilterChipSpec e) => e.label,
      ),
      containsAll(<String>['全部', '今日安親', '今日結束', '未來安親', '結清', '已取消']),
    );
    expect(
      BookingStatusFilter.stayItems.any(
        (BookingFilterChipSpec e) => e.label == '歷史訂單',
      ),
      isFalse,
    );
    expect(BookingListQueryService.pageSize, 20);
    expect(bookingListMaxWidth, 1400);
    expect(
      BookingListQueryService.activeStatuses,
      isNot(contains('completed')),
    );
    expect(
      BookingListQueryService.activeStatuses,
      isNot(contains('cancelled')),
    );
    expect(BookingListQueryService.activeStatuses, contains('checked_out'));
  });

  test('住宿 checked_in 9/22～9/24 計入入住中，不進歷史', () {
    final Map<String, dynamic> stay = <String, dynamic>{
      'bookingKind': 'accommodation',
      'status': 'checked_in',
      'startDate': DateTime(2026, 9, 22),
      'endDate': DateTime(2026, 9, 24),
    };
    expect(DaycareStatusLabels.isHistory(stay), isFalse);
    expect(DaycareStatusLabels.matchesFilter(stay, 'checked_in'), isTrue);
    expect(DaycareStatusLabels.matchesFilter(stay, 'history'), isFalse);
    expect(DaycareStatusLabels.matchesFilter(stay, 'pending'), isFalse);
  });

  test('住宿中間日的入住中訂單不出現在今日入住／退房／未來／歷史', () {
    final DateTime today = DailyCareDateHelper.todayInTaipei();
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final Map<String, dynamic> stay = <String, dynamic>{
      'bookingKind': 'accommodation',
      'status': 'checked_in',
      'startDate': DailyCareDateHelper.taipeiDayStartUtc(yesterday),
      'endDate': DailyCareDateHelper.taipeiDayStartUtc(tomorrow),
    };
    expect(DaycareStatusLabels.matchesFilter(stay, 'checked_in'), isTrue);
    expect(DaycareStatusLabels.matchesFilter(stay, 'todayCheckIn'), isFalse);
    expect(DaycareStatusLabels.matchesFilter(stay, 'todayCheckOut'), isFalse);
    expect(DaycareStatusLabels.matchesFilter(stay, 'futureCheckIn'), isFalse);
    expect(DaycareStatusLabels.matchesFilter(stay, 'history'), isFalse);
  });

  test('住宿今日入住／退房使用台北日曆日，排除 completed', () {
    final DateTime now = DateTime.utc(2026, 9, 21, 16, 30);
    final DateTime taipeiTodayStart = DailyCareDateHelper.taipeiDayStartUtc(
      DailyCareDateHelper.todayInTaipei(now),
    );
    expect(DailyCareDateHelper.isOnTaipeiToday(taipeiTodayStart, now), isTrue);
    expect(
      DailyCareDateHelper.calendarDateInTaipei(DateTime.utc(2026, 9, 21, 16)),
      DateTime(2026, 9, 22),
    );

    final Map<String, dynamic> todayStay = <String, dynamic>{
      'status': 'checked_in',
      'startDate': DateTime.utc(2026, 9, 21, 16),
      'endDate': DateTime.utc(2026, 9, 23, 16),
    };
    expect(
      DailyCareDateHelper.isOnTaipeiToday(
        todayStay['startDate'] as DateTime,
        now,
      ),
      isTrue,
    );
    expect(DaycareStatusLabels.matchesFilter(todayStay, 'history'), isFalse);

    final Map<String, dynamic> completed = <String, dynamic>{
      'status': 'completed',
      'startDate': DateTime.utc(2026, 9, 21, 16),
      'endDate': DateTime.utc(2026, 9, 23, 16),
    };
    expect(
      DaycareStatusLabels.matchesFilter(completed, 'todayCheckIn'),
      isFalse,
    );
    expect(DaycareStatusLabels.matchesFilter(completed, 'history'), isTrue);
  });

  test('安親待確認、待分房、安親中、今日送達／接回', () {
    final DateTime now = DateTime.now();
    final DateTime taipeiStart = DailyCareDateHelper.taipeiDayStartUtc(
      DailyCareDateHelper.todayInTaipei(now),
    ).add(const Duration(hours: 1));

    final Map<String, dynamic> pending = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'pending',
    };
    expect(DaycareStatusLabels.matchesFilter(pending, 'pending'), isTrue);

    final Map<String, dynamic> awaiting = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'checked_in',
      'assignStatus': 'unassigned',
      'scheduledStartAt': taipeiStart,
      'scheduledEndAt': taipeiStart.add(const Duration(hours: 8)),
    };
    expect(DaycareStatusLabels.isAwaitingRoom(awaiting), isTrue);
    expect(DaycareStatusLabels.matchesFilter(awaiting, 'awaitingRoom'), isTrue);
    expect(DaycareStatusLabels.matchesFilter(awaiting, 'checked_in'), isTrue);
    expect(DaycareStatusLabels.matchesFilter(awaiting, 'todayDropOff'), isTrue);
    expect(DaycareStatusLabels.matchesFilter(awaiting, 'todayPickUp'), isTrue);

    final Map<String, dynamic> assignedInCare = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'checked_in',
      'assignStatus': 'assigned',
      'roomId': 'r1',
      'scheduledStartAt': taipeiStart,
      'scheduledEndAt': taipeiStart.add(const Duration(hours: 8)),
    };
    expect(DaycareStatusLabels.isAwaitingRoom(assignedInCare), isFalse);
    expect(
      DaycareStatusLabels.matchesFilter(assignedInCare, 'checked_in'),
      isTrue,
    );

    final Map<String, dynamic> legacyNoAssign = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'confirmed',
      'roomId': '',
    };
    expect(DaycareStatusLabels.isAwaitingRoom(legacyNoAssign), isFalse);
    expect(
      DaycareStatusLabels.matchesFilter(legacyNoAssign, 'awaitingRoom'),
      isFalse,
    );
    expect(DaycareStatusLabels.assignLabel(legacyNoAssign), '尚未分房');

    final Map<String, dynamic> checkedOut = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'checked_out',
    };
    expect(
      DaycareStatusLabels.matchesFilter(checkedOut, 'checked_in'),
      isFalse,
    );
  });

  testWidgets('快速分類維持橫向一列，可滑到結清', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: BookingStatusFilter(
              selectedType: 'active',
              counts: const <String, int>{},
              onChanged: (_) {},
              items: BookingStatusFilter.stayItems,
            ),
          ),
        ),
      ),
    );
    final ListView list = tester.widget<ListView>(find.byType(ListView));
    expect(list.scrollDirection, Axis.horizontal);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('歷史訂單'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('已取消'),
      120,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('結清'), findsOneWidget);
    expect(find.text('已取消'), findsOneWidget);
  });

  test('搜尋範圍跟目前分類走，全部不包含結清與取消', () {
    final List<String> active = BookingListQueryService.searchStatusesFor(
      kind: BookingKind.accommodation,
      filter: 'active',
    );
    expect(active, isNot(contains('completed')));
    expect(active, isNot(contains('cancelled')));
    expect(active, isNot(contains('no_show')));
    expect(
      BookingListQueryService.searchStatusesFor(
        kind: BookingKind.accommodation,
        filter: 'settled',
      ),
      <String>['completed'],
    );
    expect(
      BookingListQueryService.searchStatusesFor(
        kind: BookingKind.daycare,
        filter: 'cancelled',
      ),
      <String>['cancelled', 'no_show'],
    );
    expect(
      BookingListQueryService.searchStatusesFor(
        kind: BookingKind.daycare,
        filter: 'active',
      ),
      isNot(contains('completed')),
    );
  });

  test('未來入住是台北今天之後，不是 UTC 日界', () {
    final DateTime now = DateTime.utc(2026, 9, 21, 16, 30);
    final DateTime tomorrowTaipei = DailyCareDateHelper.taipeiDayStartUtc(
      DateTime(2026, 9, 23),
    );
    expect(DailyCareDateHelper.isAfterTaipeiToday(tomorrowTaipei, now), isTrue);
    expect(
      DailyCareDateHelper.isAfterTaipeiToday(
        DateTime.utc(2026, 9, 21, 16),
        now,
      ),
      isFalse,
    );
  });
}
