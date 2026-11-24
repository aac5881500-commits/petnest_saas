import '../models/internal_handover_entry.dart';
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

  Stream<List<InternalHandoverEntry>> streamEntries({
    required String shopId,
    required String bookingId,
  }) => _ref(shopId: shopId, bookingId: bookingId)
      .collection('history')
      .orderBy('revision', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => InternalHandoverEntry.fromMap(doc.id, doc.data()))
            .where((entry) => entry.content.trim().isNotEmpty)
            .toList(),
      );

  Future<void> appendEntry({
    required String shopId,
    required String bookingId,
    required String category,
    required String content,
  }) async {
    final text = InternalHandoverEntry.encode(category, content);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: '請重新登入',
      );
    }
    final noteRef = _ref(shopId: shopId, bookingId: bookingId);
    final historyRef = noteRef.collection('history').doc();
    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId);
    final booking = (await bookingRef.get()).data();
    if (booking == null || booking['shopId'] != shopId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: '找不到可新增交接的店家訂單',
      );
    }
    if (BookingSettlementMath.isSettlementLocked(booking)) {
      throw const InternalHandoverLockedException();
    }
    // The existing write rules recheck the booking lock at commit time.
    var saved = false;
    for (var attempt = 0; attempt < 5; attempt++) {
      var observedRevision = 0;
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final current = (await transaction.get(noteRef)).data();
          observedRevision = (current?['revision'] as num?)?.toInt() ?? 0;
          final data = <String, dynamic>{
            'shopId': shopId,
            'bookingId': bookingId,
            'text': text,
            'revision': ((current?['revision'] as num?)?.toInt() ?? 0) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': user.uid,
            'updatedByEmail': (user.email ?? '').trim(),
          };
          transaction.set(noteRef, data);
          transaction.set(historyRef, data);
        });
        saved = true;
        break;
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' && error.code != 'aborted') {
          rethrow;
        }
        final latest = (await noteRef.get(
          const GetOptions(source: Source.server),
        )).data();
        final latestRevision = (latest?['revision'] as num?)?.toInt() ?? 0;
        // Rules can reject a stale revision before the SDK retries a transaction.
        // Retry only a proven concurrent revision, never an unchanged permission failure.
        if (latestRevision <= observedRevision) rethrow;
      }
    }
    if (!saved) throw const InternalHandoverConflictException();
    try {
      await ActionLogService.instance.logAction(
        shopId: shopId,
        targetType: 'booking',
        targetId: bookingId,
        action: 'internal_handover_added',
        operatorUid: user.uid,
        operatorRole: 'staff',
        payload: {
          'category': category,
          'hasText': true,
          'operatorEmail': (user.email ?? '').trim(),
        },
      );
    } catch (_) {
      // The private handover entry is already saved.
    }
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

    final bookingSnap = await bookingRef.get();
    final booking = bookingSnap.data();
    if (booking == null || booking['shopId'] != shopId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: '找不到可編輯的店家訂單',
      );
    }
    if (BookingSettlementMath.isSettlementLocked(booking)) {
      throw const InternalHandoverLockedException();
    }
    final currentRevision = expectedRevision ?? 0;
    final nextRevision = currentRevision + 1;
    final data = <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'text': text,
      'revision': nextRevision,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user.uid,
      'updatedByEmail': (user.email ?? '').trim(),
    };
    // Rules require the next revision and an identical history snapshot.
    final batch = FirebaseFirestore.instance.batch();
    batch.set(noteRef, data);
    batch.set(noteRef.collection('history').doc(), data);
    await batch.commit();

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
