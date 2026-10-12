// 檔案名稱：lib/core/services/admin_manual_deposit_confirm.dart
// 功能說明：店家後台確認銀行轉帳入帳。金額與訂金／全額由後端依訂單付款目的寫入。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';

class AdminManualDepositConfirm {
  AdminManualDepositConfirm._();

  static Future<void> confirmStayBooking({required String bookingId}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('請先登入');
    }
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore
        .instance
        .collection('bookings')
        .doc(bookingId);
    final DocumentSnapshot<Map<String, dynamic>> current = await ref.get();
    if (!current.exists) {
      throw StateError('找不到訂單');
    }
    final Map<String, dynamic> before = current.data() ?? <String, dynamic>{};
    final InitialPaymentChoice choice = BookingPaymentStatus.initialPaymentChoice(
      before,
    );
    if (choice.settled || choice.amount <= 0) {
      throw StateError(choice.isFull ? '全額已確認' : '訂金已確認');
    }
    try {
      await FirebaseFunctions.instanceFor(
        region: DaycareFunctionService.functionsRegion,
      ).httpsCallable('confirmManualBookingPayment').call(<String, dynamic>{
        'bookingId': bookingId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? '確認付款失敗');
    }
    final Map<String, dynamic> after =
        (await ref.get()).data() ?? <String, dynamic>{};
    if (choice.isFull) {
      final int paid = BookingPaymentStatus.resolvePaid(after);
      final int total = BookingPaymentStatus.resolveTotal(after);
      if (total <= 0 || paid < total) {
        throw StateError('確認全額未寫入付款狀態，請重試');
      }
      return;
    }
    if (!BookingPaymentStatus.isDepositConfirmed(after)) {
      throw StateError('確認訂金未寫入付款狀態，請重試');
    }
  }
}
