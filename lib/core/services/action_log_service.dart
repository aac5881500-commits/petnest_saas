// 檔案名稱：lib/core/services/action_log_service.dart
// 功能說明：店家操作紀錄 Service
// 功能：
// - 統一寫入 action_logs
// - 監聽店家操作紀錄
// - 依 createdAt 由新到舊排序
// - 只抓最新 20 筆，降低 Firestore 讀取與流量
//
// 注意：
// - 若 Firestore 提示需要建立索引，請到 Firebase Console 建立 index
// - 不建議在首頁長時間監聽所有操作紀錄

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActionLogService {
  ActionLogService._();

  static final instance = ActionLogService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _actionLogs =>
      _firestore.collection('action_logs');

  /// 新增操作紀錄
  Future<void> logAction({
    required String shopId,
    required String targetType,
    required String targetId,
    required String action,
    required String operatorUid,
    required String operatorRole,
    Map<String, dynamic>? payload,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await _actionLogs.add({
      'shopId': shopId,
      'targetType': targetType,
      'targetId': targetId,
      'action': action,
      'operatorUid': operatorUid,
      'operatorEmail': user?.email ?? '',
      'operatorRole': operatorRole,
      'payload': payload ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 監聽店家最新 20 筆操作紀錄
  Stream<List<Map<String, dynamic>>> streamShopLogs(String shopId) {
    return _actionLogs
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }
}
