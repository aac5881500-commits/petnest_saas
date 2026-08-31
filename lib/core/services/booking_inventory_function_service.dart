// lib/core/services/booking_inventory_function_service.dart
// 🏨 住宿加購／耗材返還 Cloud Functions 呼叫
// 功能：一般會員不得直接讀寫 inventory_items，
// 建立訂單扣加購庫存與取消返還改由後端處理。

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';

class BookingInventoryFunctionService {
  BookingInventoryFunctionService._();

  static final BookingInventoryFunctionService instance =
      BookingInventoryFunctionService._();

  static const String functionsRegion = 'asia-east1';
  static const Duration callableTimeout = Duration(seconds: 60);

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  Future<void> finalizeBookingAddonInventory({
    required String shopId,
    required String bookingId,
  }) async {
    debugPrint(
      '[BookingSubmit] finalize inventory start '
      'region=$functionsRegion '
      'function=finalizeBookingAddonInventory '
      'shopId=$shopId bookingId=$bookingId',
    );

    try {
      await _functions
          .httpsCallable(
            'finalizeBookingAddonInventory',
            options: HttpsCallableOptions(timeout: callableTimeout),
          )
          .call(<String, dynamic>{'shopId': shopId, 'bookingId': bookingId});
      debugPrint(
        '[BookingSubmit] finalize inventory success bookingId=$bookingId',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[BookingSubmit] finalize inventory failed:\n'
        'code=${error.code}\n'
        'message=${error.message}\n'
        'details=${error.details}\n'
        'shopId=$shopId bookingId=$bookingId',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw InventoryException(InventoryException.userMessage(error));
    } catch (error, stackTrace) {
      debugPrint(
        '[BookingSubmit] finalize inventory failed: $error '
        'shopId=$shopId bookingId=$bookingId',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw InventoryException(InventoryException.userMessage(error));
    }
  }

  Future<void> returnBookingInventory({
    required String shopId,
    required String bookingId,
  }) async {
    debugPrint(
      '[BookingSubmit] return inventory start '
      'region=$functionsRegion '
      'function=returnBookingInventory '
      'shopId=$shopId bookingId=$bookingId',
    );

    try {
      await _functions
          .httpsCallable(
            'returnBookingInventory',
            options: HttpsCallableOptions(timeout: callableTimeout),
          )
          .call(<String, dynamic>{'shopId': shopId, 'bookingId': bookingId});
      debugPrint(
        '[BookingSubmit] return inventory success bookingId=$bookingId',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[BookingSubmit] return inventory failed:\n'
        'code=${error.code}\n'
        'message=${error.message}\n'
        'details=${error.details}\n'
        'shopId=$shopId bookingId=$bookingId',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw InventoryException(InventoryException.userMessage(error));
    } catch (error, stackTrace) {
      debugPrint(
        '[BookingSubmit] return inventory failed: $error '
        'shopId=$shopId bookingId=$bookingId',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw InventoryException(InventoryException.userMessage(error));
    }
  }
}
