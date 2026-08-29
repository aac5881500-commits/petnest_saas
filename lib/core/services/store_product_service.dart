// lib/core/services/store_product_service.dart
// 🛒 商城商品 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';

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
          .take(6)
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
    final DocumentReference<Map<String, dynamic>> reference = productId.trim().isEmpty
        ? productsRef(shopId).doc()
        : productsRef(shopId).doc(productId.trim());
    final String uid = _auth.currentUser?.uid ?? '';
    await reference.set(<String, dynamic>{
      ...data,
      'shopId': shopId.trim(),
      'createdBy': uid,
      'updatedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> updateProduct({
    required String shopId,
    required String productId,
    required Map<String, dynamic> data,
  }) async {
    await productsRef(shopId).doc(productId.trim()).update(<String, dynamic>{
      ...data,
      'updatedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
