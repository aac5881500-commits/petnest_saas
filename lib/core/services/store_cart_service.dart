// 檔案名稱：lib/core/services/store_cart_service.dart
// 功能說明：只保存商品與套裝組數，不扣除 currentStock。
// 🛒 每店獨立購物車

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';

class StoreCartItem {
  const StoreCartItem({
    this.productId = '',
    this.bundlePromotionId = '',
    required this.quantity,
  });

  final String productId;
  final String bundlePromotionId;
  final int quantity;

  bool get isBundle => bundlePromotionId.trim().isNotEmpty;
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
    if (quantity <= 0) {
      return;
    }
    await _mutate(
      shopId: shopId,
      update: (List<StoreCartItem> items) {
        final int current = items
            .where(
              (StoreCartItem item) =>
                  !item.isBundle && item.productId == productId,
            )
            .fold<int>(0, (int sum, StoreCartItem item) => sum + item.quantity);
        final List<StoreCartItem> next = items
            .where(
              (StoreCartItem item) =>
                  item.isBundle || item.productId != productId,
            )
            .toList();
        next.add(
          StoreCartItem(productId: productId, quantity: current + quantity),
        );
        return next;
      },
    );
  }

  Future<void> setItem({
    required String shopId,
    required String productId,
    required int quantity,
  }) async {
    await _mutate(
      shopId: shopId,
      update: (List<StoreCartItem> items) {
        final List<StoreCartItem> next = items
            .where(
              (StoreCartItem item) =>
                  item.isBundle || item.productId != productId,
            )
            .toList();
        if (quantity > 0) {
          next.add(StoreCartItem(productId: productId, quantity: quantity));
        }
        return next;
      },
    );
  }

  Future<void> addBundle({
    required String shopId,
    required String bundlePromotionId,
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      return;
    }
    await _mutate(
      shopId: shopId,
      update: (List<StoreCartItem> items) {
        final int current = items
            .where(
              (StoreCartItem item) =>
                  item.bundlePromotionId == bundlePromotionId,
            )
            .fold<int>(0, (int sum, StoreCartItem item) => sum + item.quantity);
        final List<StoreCartItem> next = items
            .where(
              (StoreCartItem item) =>
                  item.bundlePromotionId != bundlePromotionId,
            )
            .toList();
        next.add(
          StoreCartItem(
            bundlePromotionId: bundlePromotionId,
            quantity: current + quantity,
          ),
        );
        return next;
      },
    );
  }

  Future<void> setBundle({
    required String shopId,
    required String bundlePromotionId,
    required int quantity,
  }) async {
    await _mutate(
      shopId: shopId,
      update: (List<StoreCartItem> items) {
        final List<StoreCartItem> next = items
            .where(
              (StoreCartItem item) =>
                  item.bundlePromotionId != bundlePromotionId,
            )
            .toList();
        if (quantity > 0) {
          next.add(
            StoreCartItem(
              bundlePromotionId: bundlePromotionId,
              quantity: quantity,
            ),
          );
        }
        return next;
      },
    );
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

  Future<void> _mutate({
    required String shopId,
    required List<StoreCartItem> Function(List<StoreCartItem> items) update,
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
      final List<StoreCartItem> next = update(_itemsFromData(snapshot.data()));
      transaction.set(reference, <String, dynamic>{
        'shopId': shopId.trim(),
        'userId': uid,
        'items': next.map(_itemToMap).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, dynamic> _itemToMap(StoreCartItem item) {
    return <String, dynamic>{
      if (item.productId.trim().isNotEmpty) 'productId': item.productId.trim(),
      if (item.bundlePromotionId.trim().isNotEmpty)
        'bundlePromotionId': item.bundlePromotionId.trim(),
      'quantity': item.quantity,
    };
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
          final String bundlePromotionId = (item['bundlePromotionId'] ?? '')
              .toString()
              .trim();
          final int quantity = item['quantity'] is int
              ? item['quantity'] as int
              : int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
          return StoreCartItem(
            productId: productId,
            bundlePromotionId: bundlePromotionId,
            quantity: quantity,
          );
        })
        .where((StoreCartItem item) {
          return item.quantity > 0 &&
              (item.productId.isNotEmpty || item.bundlePromotionId.isNotEmpty);
        })
        .toList();
  }
}
