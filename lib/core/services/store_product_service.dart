// lib/core/services/store_product_service.dart
// 🛒 商城商品 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';

class StoreProductSaveException implements Exception {
  const StoreProductSaveException({
    required this.step,
    required this.path,
    required this.cause,
  });

  final String step;
  final String path;
  final Object cause;

  String get code =>
      cause is FirebaseException ? (cause as FirebaseException).code : '';

  String get message => cause is FirebaseException
      ? ((cause as FirebaseException).message ?? cause.toString())
      : cause.toString();

  @override
  String toString() {
    return '[StoreProductSave] $step failed\n'
        'path=$path\n'
        'code=$code\n'
        'message=$message';
  }
}

class StoreProductService {
  StoreProductService._();

  static final StoreProductService instance = StoreProductService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> productsRef(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.productsCollection);
  }

  Stream<List<StoreProductModel>> streamProducts(String shopId) {
    return productsRef(shopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<StoreProductModel> products = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return StoreProductModel.fromMap(id: doc.id, data: doc.data());
      }).toList();
      products.sort((StoreProductModel a, StoreProductModel b) {
        final int order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) {
          return order;
        }
        return a.name.compareTo(b.name);
      });
      return products;
    });
  }

  Stream<List<StoreProductModel>> streamEnabledProducts(String shopId) {
    return productsRef(shopId)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<StoreProductModel> products = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return StoreProductModel.fromMap(id: doc.id, data: doc.data());
      }).toList();
      products.sort((StoreProductModel a, StoreProductModel b) {
        final int order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) {
          return order;
        }
        return a.name.compareTo(b.name);
      });
      return products;
    });
  }

  Stream<List<StoreProductModel>> streamFeaturedProducts(String shopId) {
    return streamEnabledProducts(shopId).map((List<StoreProductModel> products) {
      return products
          .where((StoreProductModel item) => item.featured)
          .take(8)
          .toList();
    });
  }

  Future<StoreProductModel?> getProduct({
    required String shopId,
    required String productId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await productsRef(shopId).doc(productId.trim()).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return StoreProductModel.fromMap(id: snapshot.id, data: snapshot.data()!);
  }

  Future<String> createProduct({
    required String shopId,
    required Map<String, dynamic> data,
    String productId = '',
  }) async {
    final DocumentReference<Map<String, dynamic>> reference =
        productId.trim().isEmpty
        ? productsRef(shopId).doc()
        : productsRef(shopId).doc(productId.trim());
    final Map<String, dynamic> payload = <String, dynamic>{
      ...data,
      'shopId': shopId.trim(),
      'createdBy': _auth.currentUser?.uid ?? '',
      'updatedBy': _auth.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _writeProduct(
      step: 'STEP 1 create',
      shopId: shopId,
      productId: reference.id,
      path: reference.path,
      payload: payload,
      write: () => reference.set(payload),
    );
    return reference.id;
  }

  Future<void> updateProduct({
    required String shopId,
    required String productId,
    required Map<String, dynamic> data,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference =
        productsRef(shopId).doc(productId.trim());
    final Map<String, dynamic> payload = <String, dynamic>{
      ...data,
      'shopId': shopId.trim(),
      'updatedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _writeProduct(
      step: 'STEP 1 update',
      shopId: shopId,
      productId: productId.trim(),
      path: reference.path,
      payload: payload,
      write: () => reference.update(payload),
    );
  }

  Future<void> _writeProduct({
    required String step,
    required String shopId,
    required String productId,
    required String path,
    required Map<String, dynamic> payload,
    required Future<void> Function() write,
  }) async {
    await _logPreflight(
      step: step,
      shopId: shopId,
      productId: productId,
      path: path,
      payload: payload,
    );
    debugPrint('[StoreProductSave] $step start\npath=$path');
    try {
      await write();
      debugPrint('[StoreProductSave] $step success\npath=$path');
    } catch (error, stackTrace) {
      debugPrint(
        '[StoreProductSave] $step failed\n'
        'path=$path\n'
        'code=${error is FirebaseException ? error.code : ''}\n'
        'message=${error is FirebaseException ? (error.message ?? error.toString()) : error}\n'
        'stack=$stackTrace',
      );
      throw StoreProductSaveException(step: step, path: path, cause: error);
    }
  }

  /// Debug only. Must never throw or block the product write.
  Future<void> _logPreflight({
    required String step,
    required String shopId,
    required String productId,
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    final String uid = _auth.currentUser?.uid ?? '';
    final List<String> keys = payload.keys.toList()..sort();
    debugPrint(
      '[StoreProductSave] $step preflight\n'
      'uid=$uid\n'
      'authNull=${_auth.currentUser == null}\n'
      'pageShopId=$shopId\n'
      'payloadShopId=${payload['shopId']}\n'
      'productId=$productId\n'
      'collectionPath=$path\n'
      'expectedMemberPath=shop_members/${shopId.trim()}_$uid\n'
      'payloadKeys=${keys.join(',')}',
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>> shopSnap =
          await _firestore.collection('shops').doc(shopId.trim()).get();
      debugPrint(
        '[StoreProductSave] STEP 0 shop read success\n'
        'path=shops/${shopId.trim()}\n'
        'exists=${shopSnap.exists}\n'
        'shopDocShopId=${shopSnap.data()?['shopId']}\n'
        'ownerUid=${shopSnap.data()?['ownerUid']}\n'
        'uidMatchesOwner=${shopSnap.data()?['ownerUid']?.toString() == uid}',
      );
    } catch (error) {
      debugPrint(
        '[StoreProductSave] STEP 0 shop read failed\n'
        'path=shops/${shopId.trim()}\n'
        'code=${error is FirebaseException ? error.code : ''}\n'
        'message=$error',
      );
    }

    final String memberPath = 'shop_members/${shopId.trim()}_$uid';
    try {
      final DocumentSnapshot<Map<String, dynamic>> memberSnap =
          await _firestore.doc(memberPath).get();
      debugPrint(
        '[StoreProductSave] STEP 0 member read success\n'
        'path=$memberPath\n'
        'exists=${memberSnap.exists}\n'
        'memberShopId=${memberSnap.data()?['shopId']}\n'
        'memberUid=${memberSnap.data()?['uid']}\n'
        'memberRole=${memberSnap.data()?['role']}\n'
        'manage_store_products=${(memberSnap.data()?['permissions'] is Map) ? (memberSnap.data()?['permissions'] as Map)['manage_store_products'] : null}',
      );
    } catch (error) {
      debugPrint(
        '[StoreProductSave] STEP 0 member read failed\n'
        'path=$memberPath\n'
        'code=${error is FirebaseException ? error.code : ''}\n'
        'message=$error',
      );
    }
  }
}
