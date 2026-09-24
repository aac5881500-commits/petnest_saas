// 檔案名稱：lib/core/models/daily_care_session_status.dart
// 功能說明：每日回報場次完成狀態與照片張數顯示文案。

import 'daily_care_photo_model.dart';
import 'daily_care_record_model.dart';
import '../services/daily_care_photo_service.dart';

class DailyCareSessionStatus {
  DailyCareSessionStatus._();

  static const int maxPhotos = DailyCarePhotoService.maxPhotosPerSession;

  static String photoLabel(int count) {
    final int safe = count < 0 ? 0 : (count > maxPhotos ? maxPhotos : count);
    return '照片 $safe/$maxPhotos 張';
  }

  static String sessionLine({
    required bool completed,
    required int photoCount,
    required bool locked,
  }) {
    if (locked && completed) {
      return '已完成｜${photoLabel(photoCount)}｜唯讀';
    }
    if (locked && !completed) {
      return '未完成｜訂單已結清｜已鎖定';
    }
    if (completed) {
      return '已完成｜${photoLabel(photoCount)}';
    }
    return '待填';
  }

  static String bookingLockBanner({required int missingCount}) {
    if (missingCount <= 0) {
      return '已結清，回報已鎖定';
    }
    return '已結清｜尚缺 $missingCount 場回報（已鎖定）';
  }

  static int countPhotos({
    required List<DailyCarePhotoModel> photos,
    required String bookingId,
    required String recordId,
    required DateTime recordDate,
    required int sessionIndex,
    String roomId = '',
  }) {
    final String dateKey = DailyCarePhotoMatch.canonicalDateKey(recordDate);
    final int live = DailyCarePhotoMatch.recordPhotos(
      photos: photos
          .where(
            (DailyCarePhotoModel photo) =>
                photo.bookingId == bookingId &&
                photo.previewUrl.trim().isNotEmpty,
          )
          .toList(),
      dailyCareRecordId: recordId,
      dateKey: dateKey,
      sessionIndex: sessionIndex,
      roomId: roomId,
    ).length;
    if (live > maxPhotos) {
      return maxPhotos;
    }
    return live;
  }

  static int recordFallbackCount(DailyCareRecordModel? record) {
    if (record == null) {
      return 0;
    }
    final int count = record.photoCount;
    if (count < 0) {
      return 0;
    }
    return count > maxPhotos ? maxPhotos : count;
  }
}
