// lib/core/services/store_promotion_service.dart
// 🛒 商城促銷活動 CRUD

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';

class StorePromotionService {
  StorePromotionService._();
  static final StorePromotionService instance = StorePromotionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> promotionsRef(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.promotionsCollection);
  }

  Stream<List<StorePromotionModel>> streamPromotions(String shopId) {
    return promotionsRef(shopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<StorePromotionModel> items = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return StorePromotionModel.fromMap(id: doc.id, data: doc.data());
      }).toList();
      items.sort((StorePromotionModel a, StorePromotionModel b) {
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return items;
    });
  }

  Stream<List<StorePromotionModel>> streamEnabledPromotions(String shopId) {
    return promotionsRef(shopId)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                StorePromotionModel.fromMap(id: doc.id, data: doc.data()),
          )
          .where((StorePromotionModel item) => !item.archived)
          .toList();
    });
  }

  Future<String> savePromotion({
    required String shopId,
    required StorePromotionModel promotion,
  }) async {
    final String uid = _auth.currentUser?.uid ?? '';
    final DocumentReference<Map<String, dynamic>> reference =
        promotion.id.trim().isEmpty
        ? promotionsRef(shopId).doc()
        : promotionsRef(shopId).doc(promotion.id.trim());
    final Map<String, dynamic> data = promotion.toMap()
      ..['shopId'] = shopId.trim()
      ..['updatedBy'] = uid
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (promotion.id.trim().isEmpty) {
      data['createdBy'] = uid;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['usedOrderCount'] = 0;
    }
    data['activityId'] = reference.id;
    await reference.set(data, SetOptions(merge: true));
    return reference.id;
  }

  Future<List<StorePromotionModel>> listPromotions(String shopId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await promotionsRef(shopId).get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              StorePromotionModel.fromMap(id: doc.id, data: doc.data()),
        )
        .toList();
  }

  List<StorePromotionModel> overlappingItemPromotions({
    required StorePromotionModel candidate,
    required List<StorePromotionModel> existing,
  }) {
    if (!candidate.isItemLevel) {
      return const <StorePromotionModel>[];
    }
    return existing.where((StorePromotionModel other) {
      if (other.id == candidate.id || other.archived || !other.enabled) {
        return false;
      }
      if (!other.isItemLevel) {
        return false;
      }
      if (!_periodsOverlap(
        candidate.startAt,
        candidate.endAt,
        other.startAt,
        other.endAt,
      )) {
        return false;
      }
      if (candidate.type == StorePromotionTypes.storewide ||
          other.type == StorePromotionTypes.storewide) {
        return true;
      }
      final bool sameProduct = candidate.productIds.any(other.productIds.contains);
      final bool sameCategory = candidate.categoryId.trim().isNotEmpty &&
          candidate.categoryId == other.categoryId;
      return sameProduct || sameCategory;
    }).toList();
  }

  bool _periodsOverlap(
    DateTime? aStart,
    DateTime? aEnd,
    DateTime? bStart,
    DateTime? bEnd,
  ) {
    final DateTime startA = aStart ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime endA = aEnd ?? DateTime(9999);
    final DateTime startB = bStart ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime endB = bEnd ?? DateTime(9999);
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  Future<void> setEnabled({
    required String shopId,
    required String promotionId,
    required bool enabled,
  }) async {
    await promotionsRef(shopId).doc(promotionId).update(<String, dynamic>{
      'enabled': enabled,
      if (enabled) 'archived': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> duplicatePromotion({
    required String shopId,
    required StorePromotionModel promotion,
  }) {
    return savePromotion(
      shopId: shopId,
      promotion: promotion.copyWith(
        id: '',
        name: '${promotion.name}（複製）',
        enabled: false,
        usedOrderCount: 0,
      ),
    );
  }

  Future<void> archiveOrDelete({
    required String shopId,
    required StorePromotionModel promotion,
  }) async {
    if (promotion.usedOrderCount > 0) {
      await promotionsRef(shopId).doc(promotion.id).update(<String, dynamic>{
        'enabled': false,
        'archived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await promotionsRef(shopId).doc(promotion.id).delete();
  }
}
