// 檔案名稱：lib/core/services/internal_handover_note_service.dart
// 功能說明：訂單內部交接備註（獨立於 bookings，客戶不可讀）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';

class InternalHandoverConflictException implements Exception {
  const InternalHandoverConflictException();
  @override
  String toString() => '其他員工剛更新過交接備註，請重新載入後再儲存。';
}

class InternalHandoverLockedException implements Exception {
  const InternalHandoverLockedException();
  @override
  String toString() => '訂單已鎖定，內部交接備註無法再修改。';
}

class InternalHandoverNoteService {
  InternalHandoverNoteService._();
  static final InternalHandoverNoteService instance =
      InternalHandoverNoteService._();

  DocumentReference<Map<String, dynamic>> _ref({
    required String shopId,
    required String bookingId,
  }) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('internal_handover_notes')
        .doc(bookingId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> stream({
    required String shopId,
    required String bookingId,
  }) {
    return _ref(shopId: shopId, bookingId: bookingId).snapshots();
  }

  Future<void> save({
    required String shopId,
    required String bookingId,
    required String text,
    int? expectedRevision,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: '請重新登入',
      );
    }
    final DocumentReference<Map<String, dynamic>> noteRef = _ref(
      shopId: shopId,
      bookingId: bookingId,
    );
    final DocumentReference<Map<String, dynamic>> bookingRef = FirebaseFirestore
        .instance
        .collection('bookings')
        .doc(bookingId);

    int nextRevision = 1;

    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnap = await tx.get(
        bookingRef,
      );
      if (!bookingSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: '找不到訂單，無法儲存內部交接備註',
        );
      }
      final Map<String, dynamic> booking =
          bookingSnap.data() ?? const <String, dynamic>{};
      if ((booking['shopId'] ?? '').toString() != shopId) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: '訂單不屬於此店家，無法儲存內部交接備註',
        );
      }
      if (BookingSettlementMath.isSettlementLocked(booking)) {
        throw const InternalHandoverLockedException();
      }
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(noteRef);
      final int current = snap.exists
          ? (((snap.data()?['revision'] as num?)?.toInt()) ?? 0)
          : 0;
      if (expectedRevision != null && expectedRevision != current) {
        throw const InternalHandoverConflictException();
      }
      nextRevision = current + 1;
      tx.set(noteRef, <String, dynamic>{
        'shopId': shopId,
        'bookingId': bookingId,
        'text': text,
        'revision': nextRevision,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': user.uid,
        'updatedByEmail': (user.email ?? '').trim(),
      }, SetOptions(merge: true));
      tx.set(noteRef.collection('history').doc(), <String, dynamic>{
        'shopId': shopId,
        'bookingId': bookingId,
        'text': text,
        'revision': nextRevision,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': user.uid,
        'updatedByEmail': (user.email ?? '').trim(),
      });
    });

    try {
      await ActionLogService.instance.logAction(
        shopId: shopId,
        targetType: 'booking',
        targetId: bookingId,
        action: 'internal_handover_updated',
        operatorUid: user.uid,
        operatorRole: 'staff',
        payload: <String, dynamic>{
          'revision': nextRevision,
          'hasText': text.trim().isNotEmpty,
          'operatorEmail': (user.email ?? '').trim(),
        },
      );
    } catch (_) {
      // 備註本體已成功；操作紀錄失敗不回滾。
    }
  }
}
