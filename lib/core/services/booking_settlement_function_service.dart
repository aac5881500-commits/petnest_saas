// 檔案名稱：lib/core/services/booking_settlement_function_service.dart
// 功能說明：呼叫 adjustBookingSettlement：調整應收、店內收退款、App 補款

import 'package:cloud_functions/cloud_functions.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';

class BookingSettlementFunctionService {
  BookingSettlementFunctionService._();
  static final BookingSettlementFunctionService instance =
      BookingSettlementFunctionService._();

  Future<Map<String, dynamic>> call({
    required String shopId,
    required String bookingId,
    required String action,
    Map<String, dynamic> extra = const <String, dynamic>{},
    String requestId = '',
  }) async {
    try {
      final HttpsCallableResult<dynamic> result =
          await FirebaseFunctions.instanceFor(
            region: DaycareFunctionService.functionsRegion,
          ).httpsCallable('adjustBookingSettlement').call(<String, dynamic>{
            'shopId': shopId,
            'bookingId': bookingId,
            'action': action,
            'requestId': requestId,
            ...extra,
          });
      final Object? raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{'ok': true};
    } on FirebaseFunctionsException catch (error) {
      throw DaycareFunctionException((error.message ?? '操作失敗').trim());
    }
  }

  Future<Map<String, dynamic>> changeCustomerPaymentMethod({
    required String shopId,
    required String bookingId,
    required String paymentMethod,
    String payAmountType = '',
  }) async {
    try {
      final HttpsCallableResult<dynamic> result =
          await FirebaseFunctions.instanceFor(
            region: DaycareFunctionService.functionsRegion,
          ).httpsCallable('changeBookingPaymentMethod').call(<String, dynamic>{
            'shopId': shopId,
            'bookingId': bookingId,
            'paymentMethod': paymentMethod,
            if (payAmountType.isNotEmpty) 'payAmountType': payAmountType,
          });
      final Object? raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{'ok': true};
    } on FirebaseFunctionsException catch (error) {
      throw DaycareFunctionException((error.message ?? '變更付款失敗').trim());
    }
  }
}
