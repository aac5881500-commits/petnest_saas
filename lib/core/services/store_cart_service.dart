// lib/core/services/store_cart_service.dart
// 🛒 每店獨立購物車
// 功能：只保存商品與數量，不扣除 currentStock。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';

class StoreCartItem {
  const StoreCartItem({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;
}

class StoreCartService {
  StoreCartService._();

  static final StoreCartService instance = StoreCartService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> cartRef({
    required String shopId,
    required String userId,
  }) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.cartsCollection)
        .doc(userId.trim());
  }

  Stream<List<StoreCartItem>> streamCart(String shopId) {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return Stream<List<StoreCartItem>>.value(const <StoreCartItem>[]);
    }

    return cartRef(shopId: shopId, userId: uid).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      return _itemsFromData(snapshot.data());
    });
  }

  Future<void> addOrIncrease({
    required String shopId,
    required String productId,
    int quantity = 1,
  }) async {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw Exception('請先登入');
    }
    if (quantity <= 0) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> reference = cartRef(
      shopId: shopId,
      userId: uid,
    );

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);
      final List<StoreCartItem> items = _itemsFromData(snapshot.data());
      final int current = items
          .where((StoreCartItem item) => item.productId == productId)
          .fold<int>(0, (int sum, StoreCartItem item) => sum + item.quantity);
      final List<StoreCartItem> next = items
          .where((StoreCartItem item) => item.productId != productId)
          .toList();
      next.add(StoreCartItem(productId: productId, quantity: current + quantity));

      transaction.set(reference, <String, dynamic>{
        'shopId': shopId.trim(),
        'userId': uid,
        'items': next
            .map(
              (StoreCartItem item) => <String, dynamic>{
                'productId': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setItem({
    required String shopId,
    required String productId,
    required int quantity,
  }) async {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw Exception('請先登入');
    }

    final DocumentReference<Map<String, dynamic>> reference = cartRef(
      shopId: shopId,
      userId: uid,
    );

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);
      final List<StoreCartItem> items = _itemsFromData(snapshot.data());
      final List<StoreCartItem> next = items
          .where((StoreCartItem item) => item.productId != productId)
          .toList();
      if (quantity > 0) {
        next.add(StoreCartItem(productId: productId, quantity: quantity));
      }

      transaction.set(reference, <String, dynamic>{
        'shopId': shopId.trim(),
        'userId': uid,
        'items': next
            .map(
              (StoreCartItem item) => <String, dynamic>{
                'productId': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> clearCart(String shopId) async {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return;
    }

    await cartRef(shopId: shopId, userId: uid).set(<String, dynamic>{
      'shopId': shopId.trim(),
      'userId': uid,
      'items': <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<StoreCartItem> _itemsFromData(Map<String, dynamic>? data) {
    final Object? raw = data?['items'];
    if (raw is! List) {
      return <StoreCartItem>[];
    }

    return raw
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) {
          final String productId = (item['productId'] ?? '').toString().trim();
          final int quantity = item['quantity'] is int
              ? item['quantity'] as int
              : int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
          return StoreCartItem(productId: productId, quantity: quantity);
        })
        .where(
          (StoreCartItem item) =>
              item.productId.isNotEmpty && item.quantity > 0,
        )
        .toList();
  }
}
