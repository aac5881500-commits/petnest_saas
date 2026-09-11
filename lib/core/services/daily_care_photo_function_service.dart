// 檔案名稱：lib/core/services/daily_care_photo_function_service.dart
// 功能說明：呼叫照護照片預留／完成／釋放／刪除 Cloud Functions。

import 'package:cloud_functions/cloud_functions.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';

class DailyCarePhotoFunctionService {
  DailyCarePhotoFunctionService._();
  static final DailyCarePhotoFunctionService instance =
      DailyCarePhotoFunctionService._();

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(
      region: DaycareFunctionService.functionsRegion,
    );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final HttpsCallableResult<dynamic> result =
          await _functions.httpsCallable(name).call(data);
      final Object? raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{'ok': true};
    } on FirebaseFunctionsException catch (error) {
      throw DaycareFunctionException((error.message ?? '操作失敗').trim());
    }
  }

  Future<Map<String, dynamic>> reserve({
    required String shopId,
    required String bookingId,
    required String roomId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    return _call('reserveDailyCarePhoto', <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'roomId': roomId,
      'recordDate': recordDate.toIso8601String(),
      'sessionIndex': sessionIndex,
    });
  }

  Future<Map<String, dynamic>> complete({
    required String reservationId,
    required String previewStoragePath,
    required String downloadStoragePath,
    required String previewUrl,
    required String roomName,
    required String sessionName,
    required int previewBytes,
    required int downloadBytes,
  }) {
    return _call('completeDailyCarePhotoUpload', <String, dynamic>{
      'reservationId': reservationId,
      'previewStoragePath': previewStoragePath,
      'downloadStoragePath': downloadStoragePath,
      'previewUrl': previewUrl,
      'roomName': roomName,
      'sessionName': sessionName,
      'previewBytes': previewBytes,
      'downloadBytes': downloadBytes,
    });
  }

  Future<void> release(String reservationId) async {
    if (reservationId.trim().isEmpty) {
      return;
    }
    await _call('releaseDailyCarePhotoReservation', <String, dynamic>{
      'reservationId': reservationId,
    });
  }

  Future<void> deletePhoto(String photoId) {
    return _call('deleteDailyCarePhoto', <String, dynamic>{
      'photoId': photoId,
    });
  }

  Future<void> lockSession({
    required String shopId,
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    return _call('lockDailyCareSessionPhotos', <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'recordDate': recordDate.toIso8601String(),
      'sessionIndex': sessionIndex,
    });
  }

  Future<Map<String, dynamic>> quoteAddon({
    required String shopId,
    required bool isDaycare,
    required String offerId,
    required String offerName,
    required int nights,
    String addonId = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _call('quoteDailyCareAddon', <String, dynamic>{
      'shopId': shopId,
      'isDaycare': isDaycare,
      'offerId': offerId,
      'offerName': offerName,
      'nights': nights,
      'addonId': addonId,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    });
  }
}
