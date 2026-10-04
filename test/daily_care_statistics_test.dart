import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_statistics.dart';
import 'package:petnest_saas/core/services/daily_care_statistics_service.dart';
import 'package:petnest_saas/features/booking/widgets/care_statistics_view.dart';

void main() {
  DailyCareStatisticsRequest request({
    List<CarePetRef> pets = const <CarePetRef>[],
    int? careDayCount,
    int? sessionsPerDay,
    DateTime? periodStart,
    DateTime? periodEnd,
    List<DailyCareCustomField> customFields = const <DailyCareCustomField>[],
    bool isDaycare = false,
  }) {
    return DailyCareStatisticsRequest(
      bookingId: 'booking-1',
      setting: DailyCareSettingModel(customFields: customFields),
      pets: pets,
      isDaycare: isDaycare,
      careDayCount: careDayCount,
      sessionsPerDay: sessionsPerDay,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  DailyCareRecordModel record({
    required String id,
    required DateTime recordDate,
    required int sessionIndex,
    String sessionName = '上午',
    Map<String, dynamic> values = const <String, dynamic>{'stool': '正常'},
    String reportStatus = 'completed',
    List<String> petIds = const <String>[],
    Map<String, String> petNotes = const <String, String>{},
    String bookingId = 'booking-1',
    DateTime? completedAt,
    bool withCompletedAt = true,
  }) {
    return DailyCareRecordModel(
      id: id,
      shopId: 'shop-1',
      bookingId: bookingId,
      roomId: 'room-1',
      roomName: 'A3',
      recordDate: recordDate,
      sessionIndex: sessionIndex,
      sessionName: sessionName,
      values: values,
      petNotes: petNotes,
      photoCount: 0,
      createdAt: recordDate,
      updatedAt: recordDate,
      reportStatus: reportStatus,
      completedAt: withCompletedAt ? (completedAt ?? recordDate) : null,
      petIds: petIds,
    );
  }

  BookingCareStatistics statsOf(
    List<DailyCareRecordModel> records, {
    DailyCareStatisticsRequest? source,
    String? petId,
  }) {
    return DailyCareStatisticsService.build(
      request: source ?? request(),
      records: records,
      selectedPetId: petId,
    );
  }

  test('1 場完成會提醒資料還少，草稿與其他訂單不計入', () {
    final BookingCareStatistics stats = statsOf(<DailyCareRecordModel>[
      record(
        id: 'a',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        values: const <String, dynamic>{'generalNote': '精神很好'},
      ),
      record(
        id: 'draft',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 1,
        reportStatus: 'draft',
        values: const <String, dynamic>{'stool': '正常'},
      ),
      record(
        id: 'other',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        bookingId: 'booking-2',
      ),
      record(
        id: 'cancelled',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 2,
        reportStatus: 'cancelled',
      ),
    ]);

    expect(stats.completedReportCount, 1);
    expect(stats.sampleNotice, '目前僅 1 場紀錄，統計會隨後續回報更新');
    expect(stats.notes.single.text, '精神很好');
    expect(stats.isEmpty, isFalse);
  });

  test('完成第 2 場後重新計算變成 2 場', () {
    final DailyCareRecordModel first = record(
      id: 'a',
      recordDate: DateTime(2026, 10, 3),
      sessionIndex: 0,
      sessionName: '上午',
    );
    expect(statsOf(<DailyCareRecordModel>[first]).completedReportCount, 1);

    final BookingCareStatistics next = statsOf(<DailyCareRecordModel>[
      first,
      record(
        id: 'b',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 1,
        sessionName: '下午',
      ),
    ]);
    expect(next.completedReportCount, 2);
    expect(next.sampleNotice, '目前依 2 場已完成回報統計');
    expect(
      next.timeline.map((CareTimelineSlot slot) => slot.axisLabel),
      <String>['10/3早', '10/3中'],
    );
  });

  test('3 天 3 場全完成時進度是 9 / 9', () {
    final List<DailyCareRecordModel> records = <DailyCareRecordModel>[];
    for (int day = 0; day < 3; day++) {
      for (int session = 0; session < 3; session++) {
        records.add(
          record(
            id: 'd$day-s$session',
            recordDate: DateTime(2026, 10, 3 + day),
            sessionIndex: session,
            sessionName: <String>['上午', '下午', '晚上'][session],
          ),
        );
      }
    }
    final BookingCareStatistics stats = statsOf(
      records,
      source: request(careDayCount: 3, sessionsPerDay: 3),
    );
    expect(stats.completedReportCount, 9);
    expect(stats.expectedReportCount, 9);
    expect(stats.progressText, '回報進度：9 / 9 場');
    expect(stats.progressHint, '本次照護回報已完成');
    expect(stats.timeline.first.axisLabel, '10/3早');
    expect(stats.timeline.last.axisLabel, '10/5晚');
  });

  test('缺欄不進分母，明確的無要進分母', () {
    final List<DailyCareRecordModel> records = <DailyCareRecordModel>[];
    for (int index = 0; index < 9; index++) {
      final Map<String, dynamic> values = <String, dynamic>{'stool': '正常'};
      if (index < 4) {
        values['catnip'] = '有';
      } else if (index < 6) {
        values['catnip'] = '無';
      }
      records.add(
        record(
          id: 's$index',
          recordDate: DateTime(2026, 10, 3 + (index ~/ 3)),
          sessionIndex: index % 3,
          values: values,
        ),
      );
    }
    final CareFieldStatistics catnip = statsOf(records).relax!.fields
        .singleWhere((CareFieldStatistics field) => field.key == 'catnip');
    expect(catnip.total, 6);
    expect(catnip.presence.count, 4);
    expect(catnip.presence.percent, 67);
    expect(
      catnip.distribution
          .firstWhere((CareStatusCount item) => item.label == '無')
          .ratio
          .count,
      2,
    );
  });

  test('兩隻寵物的回報不會互相污染，也不合併成全部', () {
    const List<CarePetRef> pets = <CarePetRef>[
      CarePetRef(id: 'cat-a', name: '喵喵'),
      CarePetRef(id: 'cat-b', name: '咪咪'),
    ];
    final DailyCareStatisticsRequest source = request(pets: pets);
    final List<DailyCareRecordModel> records = <DailyCareRecordModel>[
      record(
        id: 'a',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        petIds: const <String>['cat-a'],
        values: const <String, dynamic>{'stool': '正常'},
      ),
      record(
        id: 'b',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 1,
        petIds: const <String>['cat-b'],
        values: const <String, dynamic>{'stool': '偏少'},
      ),
    ];
    final BookingCareStatistics first = statsOf(records, source: source);
    final BookingCareStatistics second = statsOf(
      records,
      source: source,
      petId: 'cat-b',
    );
    expect(first.petChoices.map((CarePetRef pet) => pet.name), <String>[
      '喵喵',
      '咪咪',
    ]);
    expect(first.petName, '喵喵');
    expect(first.toilet!.fields.single.dominant.label, '正常');
    expect(second.petName, '咪咪');
    expect(second.toilet!.fields.single.dominant.label, '偏少');
    expect(second.completedReportCount, 1);
  });

  test('溫度平均與高低值，並依台北日期排序', () {
    final BookingCareStatistics stats = statsOf(<DailyCareRecordModel>[
      record(
        id: 'later',
        recordDate: DateTime.utc(2026, 10, 3, 16),
        sessionIndex: 0,
        sessionName: '上午',
        values: const <String, dynamic>{'temperature': 29, 'humidity': '55%'},
      ),
      record(
        id: 'taipei-midnight',
        recordDate: DateTime.utc(2026, 10, 2, 16),
        sessionIndex: 2,
        sessionName: '晚上',
        values: const <String, dynamic>{'temperature': '28°C', 'humidity': 48},
      ),
      record(
        id: 'first',
        recordDate: DateTime.utc(2026, 10, 2, 16),
        sessionIndex: 0,
        sessionName: '上午',
        values: const <String, dynamic>{'temperature': 27, 'humidity': 42},
      ),
    ]);
    final CareNumericSeries temperature = stats.environment!.temperature!;
    expect(temperature.average, 28);
    expect(temperature.minimum, 27);
    expect(temperature.maximum, 29);
    expect(temperature.averageText, '28');
    expect(
      stats.timeline.map((CareTimelineSlot slot) => slot.dateKey),
      <String>['2026/10/03', '2026/10/03', '2026/10/04'],
    );
    expect(
      stats.timeline.map((CareTimelineSlot slot) => slot.axisLabel),
      <String>['10/3早', '10/3晚', '10/4早'],
    );
    expect(temperature.points, <double?>[27, 28, 29]);
  });

  test('大便正常 2/3 顯示 67%，偏少 1/3 顯示 33%', () {
    final CareFieldStatistics stool =
        statsOf(<DailyCareRecordModel>[
          record(
            id: 'a',
            recordDate: DateTime(2026, 10, 3),
            sessionIndex: 0,
            values: const <String, dynamic>{'stool': '正常', 'urine': '正常'},
          ),
          record(
            id: 'b',
            recordDate: DateTime(2026, 10, 3),
            sessionIndex: 1,
            values: const <String, dynamic>{'stool': '正常', 'urine': '正常'},
          ),
          record(
            id: 'c',
            recordDate: DateTime(2026, 10, 3),
            sessionIndex: 2,
            values: const <String, dynamic>{'stool': '偏少', 'urine': '偏少'},
          ),
        ]).toilet!.fields.firstWhere(
          (CareFieldStatistics field) => field.key == 'stool',
        );
    expect(stool.dominant.label, '正常');
    expect(stool.dominant.ratio.percent, 67);
    expect(
      stool.distribution
          .firstWhere((CareStatusCount item) => item.label == '偏少')
          .ratio
          .percent,
      33,
    );
  });

  test('活動有 2 次、無 1 次是 2/3', () {
    final CareFieldStatistics ball = statsOf(<DailyCareRecordModel>[
      record(
        id: 'a',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        values: const <String, dynamic>{'toyBall': '有'},
      ),
      record(
        id: 'b',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 1,
        values: const <String, dynamic>{'toyBall': '無'},
      ),
      record(
        id: 'c',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 2,
        values: const <String, dynamic>{'toyBall': '有'},
      ),
    ]).activity!.fields.single;
    expect(ball.presence.count, 2);
    expect(ball.total, 3);
    expect(ball.presence.percent, 67);
    expect(ball.timeline, <String?>['有', '無', '有']);
  });

  test('沒有完成回報時是空狀態，理論場次仍可顯示進度', () {
    final BookingCareStatistics stats = statsOf(
      const <DailyCareRecordModel>[],
      source: request(
        careDayCount: 3,
        sessionsPerDay: 3,
        periodStart: DateTime(2026, 10, 3),
        periodEnd: DateTime(2026, 10, 5),
      ),
    );
    expect(stats.isEmpty, isTrue);
    expect(stats.completedReportCount, 0);
    expect(stats.progressText, '回報進度：0 / 9 場');
    expect(stats.environment, isNull);
    expect(stats.toilet, isNull);
    expect(stats.periodText, '2026/10/03 ～ 2026/10/05');
  });

  test('無法知道理論總場數時只顯示已完成場數', () {
    final BookingCareStatistics stats = statsOf(<DailyCareRecordModel>[
      record(id: 'a', recordDate: DateTime(2026, 10, 3), sessionIndex: 0),
      record(id: 'b', recordDate: DateTime(2026, 10, 4), sessionIndex: 0),
    ]);
    expect(stats.expectedReportCount, isNull);
    expect(stats.progressText, '目前已完成 2 場回報');
  });

  test('店家自訂放鬆欄位會進同一區，沒資料的欄位不出現', () {
    final BookingCareStatistics stats = statsOf(
      <DailyCareRecordModel>[
        record(
          id: 'a',
          recordDate: DateTime(2026, 10, 3),
          sessionIndex: 0,
          values: const <String, dynamic>{'custom_phero': '有'},
        ),
      ],
      source: request(
        customFields: const <DailyCareCustomField>[
          DailyCareCustomField(
            id: 'custom_phero',
            label: '費洛蒙',
            category: 'relax',
            inputType: 'yesNo',
          ),
          DailyCareCustomField(
            id: 'custom_box',
            label: '躲藏箱',
            category: 'relax',
            inputType: 'yesNo',
          ),
        ],
      ),
    );
    expect(
      stats.relax!.fields.map((CareFieldStatistics field) => field.label),
      <String>['費洛蒙'],
    );
    expect(stats.relax!.fields.single.presence.percent, 100);
    expect(stats.relax!.fields.single.singleSample, isTrue);
  });

  test('舊資料沒有 reportStatus 但有內容仍算完成', () {
    final BookingCareStatistics stats = statsOf(<DailyCareRecordModel>[
      record(
        id: 'legacy',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        reportStatus: '',
        withCompletedAt: false,
        values: const <String, dynamic>{'dryFood': '正常'},
      ),
    ]);
    expect(stats.completedReportCount, 1);
    expect(stats.life!.fields.single.dominant.label, '正常');
  });

  test('住宿區間用入住到退房，跨日順序不倒退', () {
    final DailyCareStatisticsScope scope = DailyCareStatisticsScope.fromBooking(
      bookingId: 'booking-1',
      booking: <String, dynamic>{
        'petName': '喵喵',
        'startDate': DateTime(2026, 10, 3),
        'endDate': DateTime(2026, 10, 6),
        'dailyCareEntitlement': <String, dynamic>{'finalReports': 3},
      },
      setting: const DailyCareSettingModel(sessionCount: 3),
    );
    expect(scope.careDates, hasLength(3));
    expect(scope.request.sessionsPerDay, 3);
    final BookingCareStatistics stats = DailyCareStatisticsService.build(
      request: scope.request,
      records: <DailyCareRecordModel>[
        record(
          id: 'night',
          recordDate: DateTime(2026, 10, 4),
          sessionIndex: 0,
          sessionName: '上午',
        ),
        record(
          id: 'prev',
          recordDate: DateTime(2026, 10, 3),
          sessionIndex: 2,
          sessionName: '晚上',
        ),
      ],
    );
    expect(stats.expectedReportCount, 9);
    expect(stats.progressText, '回報進度：2 / 9 場');
    expect(stats.progressHint, '統計會隨每日回報完成持續更新');
    expect(
      stats.timeline.map((CareTimelineSlot slot) => slot.axisLabel),
      <String>['10/3晚', '10/4早'],
    );
    expect(stats.periodText, '2026/10/03 ～ 2026/10/06');
  });

  test('整區平均：大小便、生活、活動、用品與未填不進分母', () {
    BookingCareStatistics one(Map<String, dynamic> values) {
      return statsOf(<DailyCareRecordModel>[
        record(
          id: 'only',
          recordDate: DateTime(2026, 10, 3),
          sessionIndex: 0,
          values: values,
        ),
      ]);
    }

    expect(
      one(<String, dynamic>{'stool': '正常', 'urine': '異常'}).toilet!.zone.percent,
      50,
    );
    expect(
      one(<String, dynamic>{'stool': '正常', 'urine': '正常'}).toilet!.zone.percent,
      100,
    );
    expect(
      one(<String, dynamic>{
        'dryFood': '正常',
        'wetFood': '偏少',
        'snack': '偏多',
      }).life!.zone.percent,
      80,
    );
    final BookingCareStatistics skipped = one(<String, dynamic>{
      'dryFood': '正常',
      'snack': '異常',
    });
    expect(skipped.life!.zone.percent, 50);
    expect(skipped.life!.zone.observationCount, 2);
    expect(
      one(<String, dynamic>{
        'wandToy': '有',
        'scratchBoard': '無',
        'jumpPlatform': '無',
        'toyBall': '有',
        'catHouse': '無',
      }).activity!.zone.percent,
      40,
    );
    expect(
      one(<String, dynamic>{'wandToy': '有'}).activity!.zone.caption,
      '活動參與',
    );
    expect(
      one(<String, dynamic>{
        'catnip': '無',
        'silverVine': '有',
      }).relax!.zone.percent,
      50,
    );
    expect(
      one(<String, dynamic>{
        'catnip': '無',
        'silverVine': '有',
      }).relax!.zone.caption,
      '使用比例',
    );
    expect(
      one(<String, dynamic>{'stool': '正常'}).activity!.zone.hasData,
      isFalse,
    );
  });

  test('場次比較沿用區域分數，差距未滿 5 分不顯示升降', () {
    expect(
      DailyCareZoneScore.percentOfValues(const <String?>['正常', '正常']),
      100,
    );
    expect(DailyCareZoneScore.percentOfValues(const <String?>['偏少', '正常']), 85);
    expect(
      DailyCareZoneScore.percentOfValues(const <String?>[null, '']),
      isNull,
    );
    expect(DailyCareZoneScore.changeMark(current: 85, previous: 100), '↓');
    expect(DailyCareZoneScore.changeMark(current: 100, previous: 85), '↑');
    expect(DailyCareZoneScore.changeMark(current: 74, previous: 70), '→');
    expect(DailyCareZoneScore.changeMark(current: 75, previous: null), isNull);

    final BookingCareStatistics stats = statsOf(<DailyCareRecordModel>[
      record(
        id: 'd1',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        sessionName: '上午',
        values: const <String, dynamic>{'stool': '偏少', 'urine': '偏少'},
      ),
      record(
        id: 'd2',
        recordDate: DateTime(2026, 10, 4),
        sessionIndex: 0,
        sessionName: '上午',
        values: const <String, dynamic>{'stool': '正常', 'urine': '正常'},
      ),
    ]);
    expect(
      stats.timeline.map((CareTimelineSlot slot) => slot.dateKey).toList(),
      <String>['2026/10/03', '2026/10/04'],
    );
    final int? first = DailyCareZoneScore.percentOfValues(
      stats.toilet!.fields.map(
        (CareFieldStatistics field) => field.timeline[0],
      ),
    );
    final int? second = DailyCareZoneScore.percentOfValues(
      stats.toilet!.fields.map(
        (CareFieldStatistics field) => field.timeline[1],
      ),
    );
    expect(first, 70);
    expect(second, 100);
    expect(
      DailyCareZoneScore.changeMark(current: second, previous: first),
      '↑',
    );
  });

  test('三場與九場都把全部有效狀態一次平均', () {
    final List<DailyCareRecordModel> three = <DailyCareRecordModel>[
      record(
        id: 's0',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 0,
        sessionName: '上午',
        values: const <String, dynamic>{'stool': '正常', 'urine': '正常'},
      ),
      record(
        id: 's1',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 1,
        sessionName: '下午',
        values: const <String, dynamic>{'stool': '偏少', 'urine': '正常'},
      ),
      record(
        id: 's2',
        recordDate: DateTime(2026, 10, 3),
        sessionIndex: 2,
        sessionName: '晚上',
        values: const <String, dynamic>{'stool': '異常', 'urine': '偏少'},
      ),
    ];
    final CareZoneScore toilet = statsOf(three).toilet!.zone;
    expect(toilet.percent, 73);
    expect(toilet.sessionCount, 3);
    expect(toilet.observationCount, 6);
    expect(toilet.caption, '整體狀況');

    final List<DailyCareRecordModel> nine = <DailyCareRecordModel>[];
    for (int index = 0; index < 9; index++) {
      nine.add(
        record(
          id: 'n$index',
          recordDate: DateTime(2026, 10, 3 + (index ~/ 3)),
          sessionIndex: index % 3,
          values: <String, dynamic>{
            'stool': index.isEven ? '正常' : '異常',
            'urine': '正常',
          },
        ),
      );
    }
    final BookingCareStatistics all = statsOf(
      nine,
      source: request(careDayCount: 3, sessionsPerDay: 3),
    );
    expect(all.completedReportCount, 9);
    expect(all.toilet!.zone.observationCount, 18);
    expect(all.toilet!.zone.sessionCount, 9);
    // 9 場大便：5 個正常、4 個異常；9 場尿尿皆正常。
    // (5*100 + 4*0 + 9*100) / 18 = 77.77... → 78
    expect(all.toilet!.zone.percent, 78);
  });

  testWidgets('空資料不顯示百分比，有資料時圓環顯示主要狀態', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CareStatisticsBody(
            request: request(careDayCount: 3, sessionsPerDay: 3),
            records: const <DailyCareRecordModel>[],
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('care-statistics-empty')),
      findsOneWidget,
    );
    expect(find.text('目前尚無已完成的照護回報'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CareStatisticsBody(
            request: request(),
            records: <DailyCareRecordModel>[
              record(
                id: 'a',
                recordDate: DateTime(2026, 10, 3),
                sessionIndex: 0,
                values: const <String, dynamic>{
                  'stool': '正常',
                  'temperature': 28,
                  'generalNote': '今天精神很好',
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('整體狀況'), findsOneWidget);
    expect(find.text('尚無資料'), findsWidgets);
    expect(find.text('0%'), findsNothing);
    expect(find.text('大便'), findsNothing);
    expect(find.text('目前僅 1 場紀錄，統計會隨後續回報更新'), findsOneWidget);
    expect(find.text('今天精神很好'), findsOneWidget);
    await tester.tap(find.text('照護紀錄'));
    await tester.pumpAndSettle();
    expect(find.text('環境紀錄'), findsOneWidget);
    expect(find.text('環境趨勢'), findsNothing);
    expect(find.text('10/03（六）'), findsWidgets);
    expect(find.textContaining('↑'), findsNothing);
    expect(find.textContaining('↓'), findsNothing);
    expect(find.text('查看明細'), findsOneWidget);
    await tester.tap(find.text('查看明細'));
    await tester.pumpAndSettle();
    expect(find.text('大便'), findsOneWidget);
    expect(find.text('今天精神很好'), findsWidgets);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌機照護紀錄以雙欄顯示，第二場可和上一場比較', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CareStatisticsBody(
            request: request(careDayCount: 1, sessionsPerDay: 2),
            records: <DailyCareRecordModel>[
              record(
                id: 'a',
                recordDate: DateTime(2026, 10, 3),
                sessionIndex: 0,
                sessionName: '第 1 次照護',
                values: const <String, dynamic>{'stool': '偏少', 'urine': '偏少'},
              ),
              record(
                id: 'b',
                recordDate: DateTime(2026, 10, 3),
                sessionIndex: 1,
                sessionName: '第 2 次照護',
                values: const <String, dynamic>{'stool': '正常', 'urine': '正常'},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('照護紀錄'));
    await tester.pumpAndSettle();
    expect(find.text('整筆訂單目前整體狀況'), findsOneWidget);
    expect(find.text('環境紀錄'), findsOneWidget);
    expect(find.text('環境平均'), findsOneWidget);
    expect(find.textContaining('↑'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
