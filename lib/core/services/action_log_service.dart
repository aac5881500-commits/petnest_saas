//lib/core/services/action_log_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ActionLogService {
  ActionLogService._();
  static final instance = ActionLogService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _actionLogs =>
      _firestore.collection('action_logs');

  Future<void> logAction({
    required String shopId,
    required String targetType,
    required String targetId,
    required String action,
    required String operatorUid,
    required String operatorRole,
    Map<String, dynamic>? payload,
  }) async {
    await _actionLogs.add({
      'shopId': shopId,
      'targetType': targetType,
      'targetId': targetId,
      'action': action,
      'operatorUid': operatorUid,
      'operatorRole': operatorRole,
      'payload': payload ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamShopLogs(String shopId) {
    return _actionLogs
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final result = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      result.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      return result;
    });
  }
}