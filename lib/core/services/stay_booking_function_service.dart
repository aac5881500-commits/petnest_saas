// 檔案名稱：lib/core/services/stay_booking_function_service.dart
// 功能說明：住宿建單／分房 Cloud Functions

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/utils/callable_payload.dart';

class StayBookingFunctionException implements Exception {
  const StayBookingFunctionException(this.message);
  final String message;

  @override
  String toString() => message;

  static String from(Object error) {
    if (error is StayBookingFunctionException) {
      return error.message;
    }
    return ChatErrorProbe.userFacing(error);
  }
}

class StayBookingFunctionService {
  StayBookingFunctionService._();

  static final StayBookingFunctionService instance =
      StayBookingFunctionService._();

  static const String functionsRegion = 'asia-east1';

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      CallablePayload.assertValid(data);
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
    } catch (error, stack) {
      debugPrint(ChatErrorProbe.describe(error));
      ChatErrorProbe.dump(
        'StayBookingFunctionService._call',
        error,
        stack,
        operation: name,
      );
      throw StayBookingFunctionException(
        StayBookingFunctionException.from(error),
      );
    }
  }

  Future<String> createStayBooking({
    required String shopId,
    required String roomTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> booking,
    String requestId = '',
    String source = 'customer',
    String userId = '',
  }) async {
    final Map<String, dynamic> result =
        await _call('createStayBooking', <String, dynamic>{
          'shopId': shopId,
          'roomTypeId': roomTypeId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'requestId': requestId,
          'source': source,
          'userId': userId,
          'requestedPoints': booking['requestedPoints'] ?? 0,
          'booking': booking,
        });
    return (result['bookingId'] ?? '').toString();
  }

  Future<void> manage({
    required String shopId,
    required String bookingId,
    required String action,
    String roomId = '',
    String roomName = '',
    String reason = '',
  }) {
    return _call('manageStayInventory', <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'action': action,
      'roomId': roomId,
      'roomName': roomName,
      'reason': reason,
    }).then((_) {});
  }
}
