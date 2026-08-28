// lib/core/services/booking_inventory_function_service.dart
// 🏨 住宿加購／耗材返還 Cloud Functions 呼叫
// 功能：一般會員不得直接讀寫 inventory_items，
// 建立訂單扣加購庫存與取消返還改由後端處理。

import 'package:cloud_functions/cloud_functions.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';

class BookingInventoryFunctionService {
  BookingInventoryFunctionService._();

  static final BookingInventoryFunctionService instance =
      BookingInventoryFunctionService._();

  static const String functionsRegion = 'asia-east1';

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  Future<void> finalizeBookingAddonInventory({
    required String shopId,
    required String bookingId,
  }) async {
    try {
      await _functions
          .httpsCallable('finalizeBookingAddonInventory')
          .call(<String, dynamic>{
            'shopId': shopId,
            'bookingId': bookingId,
          });
    } on FirebaseFunctionsException catch (error) {
      throw InventoryException(InventoryException.userMessage(error));
    }
  }

  Future<void> returnBookingInventory({
    required String shopId,
    required String bookingId,
  }) async {
    try {
      await _functions
          .httpsCallable('returnBookingInventory')
          .call(<String, dynamic>{
            'shopId': shopId,
            'bookingId': bookingId,
          });
    } on FirebaseFunctionsException catch (error) {
      throw InventoryException(InventoryException.userMessage(error));
    }
  }
}
