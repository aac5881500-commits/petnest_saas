// lib/core/services/store_category_service.dart
// 🛒 商城分類 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';

class StoreCategoryService {
  StoreCategoryService._();

  static final StoreCategoryService instance = StoreCategoryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> categoriesRef(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.categoriesCollection);
  }

  Stream<List<StoreCategoryModel>> streamCategories(String shopId) {
    return categoriesRef(shopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<StoreCategoryModel> categories = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return StoreCategoryModel.fromMap(id: doc.id, data: doc.data());
      }).toList();
      categories.sort((StoreCategoryModel a, StoreCategoryModel b) {
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return categories;
    });
  }

  Future<String> createCategory({
    required String shopId,
    required String name,
    required int sortOrder,
    bool enabled = true,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = categoriesRef(
      shopId,
    ).doc();
    await reference.set(<String, dynamic>{
      'shopId': shopId.trim(),
      'name': name.trim(),
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdBy': _auth.currentUser?.uid ?? '',
      'updatedBy': _auth.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> updateCategory({
    required String shopId,
    required String categoryId,
    required Map<String, dynamic> data,
  }) async {
    await categoriesRef(shopId).doc(categoryId.trim()).update(<String, dynamic>{
      ...data,
      'updatedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
