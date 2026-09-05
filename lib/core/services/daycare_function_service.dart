// 檔案名稱：lib/core/services/daycare_function_service.dart
// 功能說明：臨托 Cloud Functions 呼叫

import 'package:cloud_functions/cloud_functions.dart';

class DaycareFunctionException implements Exception {
  const DaycareFunctionException(this.message);
  final String message;

  @override
  String toString() => message;

  static String from(Object error) {
    if (error is FirebaseFunctionsException) {
      return (error.message ?? '操作失敗').trim();
    }
    return error.toString();
  }
}

class DaycareFunctionService {
  DaycareFunctionService._();

  static final DaycareFunctionService instance = DaycareFunctionService._();

  static const String functionsRegion = 'asia-east1';

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call(data);
      final Object? raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{'ok': true};
    } catch (error) {
      throw DaycareFunctionException(DaycareFunctionException.from(error));
    }
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) {
    return _call('createDaycareBooking', data);
  }

  Future<Map<String, dynamic>> manage({
    required String shopId,
    required String bookingId,
    required String action,
    String requestId = '',
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    return _call('manageDaycareBooking', <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'action': action,
      if (requestId.isNotEmpty) 'requestId': requestId,
      ...extra,
    });
  }

  Future<Map<String, dynamic>> assignRoom({
    required String shopId,
    required String bookingId,
    required String roomId,
    String roomName = '',
    String roomTypeId = '',
    String roomTypeName = '',
  }) {
    return _call('assignDaycareRoom', <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'roomId': roomId,
      'roomName': roomName,
      'roomTypeId': roomTypeId,
      'roomTypeName': roomTypeName,
    });
  }

  Future<Map<String, dynamic>> convertToAccommodation(
    Map<String, dynamic> data,
  ) {
    return _call('convertDaycareToAccommodation', data);
  }
}
