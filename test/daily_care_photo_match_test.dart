import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_photo_model.dart';

DailyCarePhotoModel _photo({
  required DateTime recordDate,
  int sessionIndex = 0,
  String roomId = 'room',
}) {
  return DailyCarePhotoModel(
    id: 'p',
    shopId: 's',
    bookingId: 'b',
    roomId: roomId,
    roomName: 'A1',
    recordDate: recordDate,
    sessionIndex: sessionIndex,
    sessionName: '上午場',
    previewUrl: 'https://example.com/p.jpg',
    previewStoragePath: 'path',
    createdAt: recordDate,
  );
}

void main() {
  test('日期字串可用斜線或連字號，並對齊台北日曆日', () {
    final DailyCarePhotoModel photo = _photo(
      recordDate: DateTime.utc(2026, 9, 16, 16),
    );
    expect(DailyCarePhotoMatch.matchesDate(photo, '2026/09/17'), isTrue);
    expect(DailyCarePhotoMatch.matchesDate(photo, '2026-09-17'), isTrue);
    expect(DailyCarePhotoMatch.matchesDate(photo, '20260917'), isTrue);
    expect(DailyCarePhotoMatch.photoDisplayDateKey(photo), '2026/09/17');
  });

  test('本場只比 sessionIndex 與日期，不用場次名稱', () {
    final DailyCarePhotoModel photo = _photo(
      recordDate: DateTime(2026, 9, 16),
      sessionIndex: 0,
    );
    expect(
      DailyCarePhotoMatch.matchesSession(
        photo: photo,
        dateKey: '2026/09/16',
        sessionIndex: 0,
        sessionName: '完全不同的名稱',
      ),
      isTrue,
    );
    expect(
      DailyCarePhotoMatch.matchesSession(
        photo: photo,
        dateKey: '2026/09/16',
        sessionIndex: 1,
        sessionName: '上午場',
      ),
      isFalse,
    );
  });

  test('其他場有照片時本場列表為空', () {
    final List<DailyCarePhotoModel> photos = <DailyCarePhotoModel>[
      _photo(recordDate: DateTime(2026, 9, 16), sessionIndex: 1),
    ];
    expect(
      DailyCarePhotoMatch.sessionPhotos(
        photos: photos,
        dateKey: '2026/09/16',
        sessionIndex: 0,
      ),
      isEmpty,
    );
  });
}
