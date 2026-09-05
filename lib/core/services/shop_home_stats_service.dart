// 檔案名稱：lib/core/services/shop_home_stats_service.dart
// 功能說明：首頁店家統計 Service
// 功能：
// 1. 今日訂單
// 2. 待確認訂單
// 3. 會員數統計

import 'package:cloud_firestore/cloud_firestore.dart';

class ShopHomeStatsService {
  ShopHomeStatsService._();

  static final instance = ShopHomeStatsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, int>> getShopHomeStats(String shopId) async {
    /// 待確認：status = pending
    final pendingSnapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .get();

    /// 已轉帳回傳：已上傳訂金等待店家確認
    final transferUploadedSnapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('depositStatus', isEqualTo: 'pending_review')
        .get();

    /// 會員數：該店所有訂單的不重複 userId
    final allBookingsSnapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    final memberIds = <String>{};

    for (final doc in allBookingsSnapshot.docs) {
      final userId = doc.data()['userId']?.toString() ?? '';

      if (userId.isNotEmpty) {
        memberIds.add(userId);
      }
    }

    return {
      'pendingOrders': pendingSnapshot.docs.length,
      'transferUploadedOrders': transferUploadedSnapshot.docs.length,
      'memberCount': memberIds.length,
    };
  }
}
