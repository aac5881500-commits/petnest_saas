// 檔案名稱：lib/core/services/daily_care_addon_service.dart
// 功能說明：讀寫寵物寫真與照護回報專用加購方案。

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_care_addon_plan.dart';

class DailyCareAddonService {
  DailyCareAddonService._();
  static final DailyCareAddonService instance = DailyCareAddonService._();

  CollectionReference<Map<String, dynamic>> _col(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId.trim())
        .collection('daily_care_addons');
  }

  Stream<List<DailyCareAddonPlan>> streamPlans(String shopId) {
    if (shopId.trim().isEmpty) {
      return Stream<List<DailyCareAddonPlan>>.value(
        const <DailyCareAddonPlan>[],
      );
    }
    return _col(shopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snap,
    ) {
      return snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                DailyCareAddonPlan.fromMap(doc.id, doc.data()),
          )
          .toList();
    });
  }

  Future<List<DailyCareAddonPlan>> listPlans(String shopId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _col(shopId).get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              DailyCareAddonPlan.fromMap(doc.id, doc.data()),
        )
        .toList();
  }

  Future<void> savePlan({
    required String shopId,
    required DailyCareAddonPlan plan,
  }) async {
    final String id = plan.id.trim().isEmpty
        ? _col(shopId).doc().id
        : plan.id.trim();
    await _col(shopId).doc(id).set(<String, dynamic>{
      ...plan.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
