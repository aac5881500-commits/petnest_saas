// 檔案名稱：lib/core/services/admin_manual_deposit_confirm.dart
// 功能說明：店家後台「確認收到訂金」寫入（不覆寫 depositExpireAt）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class AdminManualDepositConfirm {
  AdminManualDepositConfirm._();

  static Future<void> confirmStayBooking({required String bookingId}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore
        .instance
        .collection('bookings')
        .doc(bookingId);
    final DocumentSnapshot<Map<String, dynamic>> current = await ref.get();
    final Map<String, dynamic> before = current.data() ?? <String, dynamic>{};
    if (!current.exists) {
      throw StateError('找不到訂單');
    }
    if (BookingPaymentStatus.isDepositConfirmed(before)) {
      throw StateError('訂金已確認');
    }
    final int depositAmount = SafeParse.parseMoney(before['depositAmount']);
    if (depositAmount <= 0) {
      throw StateError('此訂單無需確認訂金');
    }
    final int totalAmount = DaycarePaymentDisplay.resolveTotal(before);
    final int existingPaid = SafeParse.parseMoney(before['paidAmount']);
    final int paid = existingPaid > depositAmount
        ? existingPaid
        : depositAmount;
    final int remaining = totalAmount - paid < 0 ? 0 : totalAmount - paid;
    final String paymentStatus = paid >= totalAmount && totalAmount > 0
        ? 'paid'
        : (paid > 0 ? 'partial' : 'unpaid');
    final String status = (before['status'] ?? '').toString();
    final Map<String, dynamic> update = <String, dynamic>{
      'depositPaid': true,
      'depositStatus': 'confirmed',
      'depositPaidAt': FieldValue.serverTimestamp(),
      'paidAmount': paid,
      'remainingAmount': remaining,
      'paymentStatus': paymentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'pending' ||
        status == 'pending_confirmation' ||
        status == 'unpaid') {
      update['status'] = 'confirmed';
      update['confirmedAt'] = FieldValue.serverTimestamp();
    }
    try {
      await ref.update(update);
    } on FirebaseException catch (error) {
      throw StateError(
        '確認訂金失敗：[${error.plugin}/${error.code}] ${error.message ?? ''}\n'
        '路徑：bookings/$bookingId',
      );
    }
    final Map<String, dynamic> after = (await ref.get()).data() ?? before;
    if (!BookingPaymentStatus.isDepositConfirmed(after)) {
      throw StateError('確認訂金未寫入付款狀態，請重試');
    }
    try {
      await FirebaseFirestore.instance
          .collection('action_logs')
          .add(<String, dynamic>{
            'type': 'deposit_confirmed',
            'bookingId': bookingId,
            'bookingShortId': bookingId.length >= 8
                ? bookingId.substring(0, 8)
                : bookingId,
            'shopId': after['shopId'],
            'roomId': after['roomId'],
            'roomName': after['roomName'],
            'roomTypeName': after['roomTypeName'],
            'depositAmount': after['depositAmount'] ?? 0,
            'paymentMethod': after['paymentMethod'],
            'transferLast5': after['transferLast5'],
            'operatorUid': user?.uid,
            'operatorRole': 'staff',
            'operatorEmail': user?.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (error) {
      throw StateError(
        '訂金已寫入訂單，但操作紀錄寫入失敗：[${error.plugin}/${error.code}] '
        '${error.message ?? ''}\n路徑：action_logs',
      );
    }
  }
}
