// 檔案名稱：lib/core/services/booking_payment_proof_function_service.dart
// 功能說明：呼叫 appendBookingPaymentProof，追加不可覆蓋的付款回傳照片紀錄

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';

class BookingPaymentProofFunctionService {
  BookingPaymentProofFunctionService._();
  static final BookingPaymentProofFunctionService instance =
      BookingPaymentProofFunctionService._();

  Future<void> append({
    required String bookingId,
    required String purpose,
    String imageUrl = '',
    String storagePath = '',
    int amount = 0,
    String last5 = '',
    String proofId = '',
  }) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: DaycareFunctionService.functionsRegion,
      ).httpsCallable('appendBookingPaymentProof').call(<String, dynamic>{
        'bookingId': bookingId,
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'purpose': purpose,
        'amount': amount,
        'last5': last5,
        'proofId': proofId,
      });
    } on FirebaseFunctionsException catch (error, stack) {
      debugFail(
        error,
        stack,
        storagePath: storagePath,
        stage: 'appendBookingPaymentProof',
      );
      throw DaycareFunctionException(userMessage(error));
    }
  }

  static String userMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
        case 'permission-denied':
          return '無權限上傳付款照片';
        case 'internal':
        case 'unknown':
        case 'unavailable':
          return '無法儲存付款回傳資料';
        default:
          final String message = (error.message ?? '').trim();
          if (message.isNotEmpty &&
              message.toLowerCase() != 'internal' &&
              message.toLowerCase() != 'internal.') {
            return message;
          }
          return '無法儲存付款回傳資料';
      }
    }
    if (error is FirebaseException) {
      debugFail(error, StackTrace.current, stage: 'firebase');
      if (error.plugin.contains('storage')) {
        return '照片上傳失敗，請重試';
      }
      if (error.code == 'permission-denied') {
        return '無權限上傳付款照片';
      }
    }
    return '照片上傳失敗，請重試';
  }

  static void debugFail(
    Object error,
    StackTrace stack, {
    String storagePath = '',
    String stage = '',
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[paymentProof] stage=$stage path=$storagePath');
    debugPrint('[paymentProof] runtimeType=${error.runtimeType}');
    if (error is FirebaseException) {
      debugPrint('[paymentProof] plugin=${error.plugin}');
      debugPrint('[paymentProof] code=${error.code}');
      debugPrint('[paymentProof] message=${error.message}');
    } else {
      debugPrint('[paymentProof] error=$error');
    }
    debugPrint('[paymentProof] stack=$stack');
  }
}
