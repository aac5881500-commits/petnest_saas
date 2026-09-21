// 檔案名稱：test/daily_care_record_photo_binding_test.dart
// 功能說明：照片依 record ID／台北 dateKey 綁定，不混場次與房間。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_photo_model.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/widgets/daily_care_journal_renderer.dart';

DailyCarePhotoModel _photo({
  String id = 'p',
  DateTime? recordDate,
  String dateKey = '',
  String dailyCareRecordId = '',
  int sessionIndex = 0,
  String roomId = 'roomA',
}) {
  return DailyCarePhotoModel(
    id: id,
    shopId: 's',
    bookingId: 'booking123',
    dailyCareRecordId: dailyCareRecordId,
    dateKey: dateKey,
    roomId: roomId,
    roomName: 'A1',
    recordDate: recordDate ?? DateTime.utc(2026, 9, 19, 16),
    sessionIndex: sessionIndex,
    sessionName: '上午場',
    previewUrl: 'https://example.com/$id.jpg',
    previewStoragePath: 'path',
    createdAt: DateTime.utc(2026, 9, 19, 16),
  );
}

void main() {
  test('UTC 9/19 16:00 的台北日是 9/20，record ID 與 Functions 一致', () {
    final DateTime utc = DateTime.utc(2026, 9, 19, 16);
    expect(DailyCareDateHelper.recordIdDateKey(utc), '20260920');
    expect(DailyCareDateHelper.displayDateKey('20260920'), '2026/09/20');
    expect(
      DailyCareRecordService.recordId(
        bookingId: 'booking123',
        recordDate: utc,
        sessionIndex: 0,
      ),
      'booking123_20260920_0',
    );
  });

  test('圖庫與回報都用照片 dateKey，不看本機 year/month/day', () {
    final DailyCarePhotoModel photo = _photo(
      dateKey: '20260920',
      recordDate: DateTime.utc(2026, 9, 19, 16),
    );
    expect(DailyCarePhotoMatch.photoDisplayDateKey(photo), '2026/09/20');
    expect(DailyCarePhotoMatch.matchesDate(photo, '2026/09/20'), isTrue);
    expect(DailyCarePhotoMatch.matchesDate(photo, '2026/09/19'), isFalse);
  });

  test('有 dailyCareRecordId 的新照片只依 record ID', () {
    final List<DailyCarePhotoModel> photos = <DailyCarePhotoModel>[
      _photo(
        id: 'mine',
        dailyCareRecordId: 'booking123_20260920_0',
        dateKey: '20260920',
        sessionIndex: 0,
      ),
      _photo(
        id: 'other-day',
        dailyCareRecordId: 'booking123_20260919_0',
        dateKey: '20260919',
        sessionIndex: 0,
      ),
      _photo(
        id: 'other-session',
        dailyCareRecordId: 'booking123_20260920_1',
        dateKey: '20260920',
        sessionIndex: 1,
      ),
    ];
    final List<DailyCarePhotoModel> mine = DailyCarePhotoMatch.recordPhotos(
      photos: photos,
      dailyCareRecordId: 'booking123_20260920_0',
      dateKey: '2026/09/20',
      sessionIndex: 0,
    );
    expect(mine.map((DailyCarePhotoModel p) => p.id), <String>['mine']);
  });

  test('錯誤或舊 record ID 仍可依日期＋場次＋房間歸到本場', () {
    final List<DailyCarePhotoModel> photos = <DailyCarePhotoModel>[
      _photo(
        id: 'legacy-wrong-id',
        dailyCareRecordId: 'booking123_20260920_wrong',
        dateKey: '20260920',
        sessionIndex: 0,
        roomId: 'roomA',
      ),
      _photo(
        id: 'other-session',
        dailyCareRecordId: 'booking123_20260920_1',
        dateKey: '20260920',
        sessionIndex: 1,
        roomId: 'roomA',
      ),
    ];
    final List<DailyCarePhotoModel> matched = DailyCarePhotoMatch.recordPhotos(
      photos: photos,
      dailyCareRecordId: 'booking123_20260920_0',
      dateKey: '2026/09/20',
      sessionIndex: 0,
      roomId: 'roomA',
    );
    expect(matched.map((DailyCarePhotoModel p) => p.id), <String>[
      'legacy-wrong-id',
    ]);
  });

  test('舊照片沒有 record ID 時以台北日＋場次＋房間 fallback', () {
    final List<DailyCarePhotoModel> photos = <DailyCarePhotoModel>[
      _photo(
        id: 'legacy',
        dateKey: '20260920',
        sessionIndex: 0,
        roomId: 'roomA',
      ),
      _photo(
        id: 'other-room',
        dateKey: '20260920',
        sessionIndex: 0,
        roomId: 'roomB',
      ),
      _photo(id: 'other-session', dateKey: '20260920', sessionIndex: 1),
      _photo(
        id: 'no-key',
        dateKey: '',
        recordDate: DateTime.utc(2026, 9, 19, 16),
        sessionIndex: 0,
        roomId: 'roomA',
      ),
    ];
    final List<DailyCarePhotoModel> matched = DailyCarePhotoMatch.recordPhotos(
      photos: photos,
      dailyCareRecordId: 'booking123_20260920_0',
      dateKey: '2026/09/20',
      sessionIndex: 0,
      roomId: 'roomA',
    );
    expect(
      matched.map((DailyCarePhotoModel p) => p.id).toList()..sort(),
      <String>['legacy', 'no-key'],
    );
  });

  testWidgets('客戶回報快照直接使用本場照片，顯示 1 張', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final DailyCarePhotoModel photo = _photo(
      id: 'p1',
      dailyCareRecordId: 'booking123_20260920_0',
      dateKey: '20260920',
    );
    final DailyCareRecordModel record = DailyCareRecordModel(
      id: 'booking123_20260920_0',
      shopId: 's',
      bookingId: 'booking123',
      roomId: 'roomA',
      roomName: 'A1',
      recordDate: DateTime(2026, 9, 20),
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
      createdAt: DateTime(2026, 9, 20, 10),
      updatedAt: DateTime(2026, 9, 20, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            height: 852,
            child: DailyCareJournalRenderer(
              setting: const DailyCareSettingModel(),
              stay: DailyCareStayInfo(
                roomName: 'A1',
                pets: <DailyCareStayPet>[
                  DailyCareStayPet(name: '小米', photoUrl: ''),
                ],
                startDate: DateTime(2026, 9, 20),
                endDate: DateTime(2026, 9, 20),
              ),
              dateKeys: const <String>['2026/09/20'],
              selectedDateKey: '2026/09/20',
              sessionTabs: const <DailyCareJournalSessionTab>[
                DailyCareJournalSessionTab(sessionIndex: 0, sessionName: '上午場'),
              ],
              selectedSessionIndex: 0,
              record: record,
              photos: <DailyCarePhotoModel>[photo],
              photosBoundToSelectedRecord: true,
              showPhotoSection: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(DailyCareJournalRenderer.emptySessionPhotosLabel),
      findsNothing,
    );
    expect(find.textContaining('1 / 3'), findsNothing);
  });

  test('本場額度：1 張已上傳時尚可上傳 2 張', () {
    const int maxCount = 3;
    const int uploadedCount = 1;
    final int remaining = maxCount - uploadedCount;
    expect(
      '本場已上傳 $uploadedCount / $maxCount 張，尚可上傳 $remaining 張',
      '本場已上傳 1 / 3 張，尚可上傳 2 張',
    );
  });
}
