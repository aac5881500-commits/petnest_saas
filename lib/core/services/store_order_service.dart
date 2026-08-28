// lib/core/services/store_order_service.dart
// 🛒 商城訂單讀取 Service
// 功能：前台與後台查詢訂單。建立、付款與狀態變更走 Cloud Functions。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';

class StoreOrderService {
  StoreOrderService._();

  static final StoreOrderService instance = StoreOrderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> shopOrdersRef(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.ordersCollection);
  }

  Stream<List<StoreOrderModel>> streamShopOrders(String shopId) {
    return shopOrdersRef(shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  Stream<List<StoreOrderModel>> streamMemberOrders({String shopId = ''}) {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return Stream<List<StoreOrderModel>>.value(const <StoreOrderModel>[]);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup(StoreConstants.ordersCollection)
        .where('userId', isEqualTo: uid);

    if (shopId.trim().isNotEmpty) {
      query = query.where('shopId', isEqualTo: shopId.trim());
    }

    return query.orderBy('createdAt', descending: true).snapshots().map(_mapDocs);
  }

  Stream<StoreOrderModel?> streamOrder({
    required String shopId,
    required String orderId,
  }) {
    return shopOrdersRef(shopId).doc(orderId.trim()).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return StoreOrderModel.fromMap(id: snapshot.id, data: snapshot.data()!);
    });
  }

  Future<StoreOrderModel?> getOrder({
    required String shopId,
    required String orderId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await shopOrdersRef(shopId).doc(orderId.trim()).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return StoreOrderModel.fromMap(id: snapshot.id, data: snapshot.data()!);
  }

  List<StoreOrderModel> _mapDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return StoreOrderModel.fromMap(id: doc.id, data: doc.data());
    }).toList();
  }
}
