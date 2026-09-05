// 檔案名稱：lib/core/services/daycare_date_override_service.dart
// 功能說明：臨托單日例外：shops/{shopId}/daycare_date_overrides/{yyyyMMdd}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class DaycareDateOverrideService {
  DaycareDateOverrideService._();

  static final DaycareDateOverrideService instance =
      DaycareDateOverrideService._();

  static const String collection = 'daycare_date_overrides';

  CollectionReference<Map<String, dynamic>> _col(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection(collection);
  }

  Future<DaycareDateOverrideModel?> get({
    required String shopId,
    required DateTime date,
  }) async {
    final String id = DaycareTimeHelper.overrideDocId(date);
    final DocumentSnapshot<Map<String, dynamic>> snap = await _col(
      shopId,
    ).doc(id).get();
    if (!snap.exists) {
      return null;
    }
    return DaycareDateOverrideModel.fromMap(snap.data(), id: snap.id);
  }

  Future<Map<String, DaycareDateOverrideModel>> loadRange({
    required String shopId,
    required DateTime start,
    required DateTime end,
  }) async {
    final String startId = DaycareTimeHelper.overrideDocId(start);
    final String endId = DaycareTimeHelper.overrideDocId(end);
    final QuerySnapshot<Map<String, dynamic>> snap = await _col(shopId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endId)
        .get();
    final Map<String, DaycareDateOverrideModel> result =
        <String, DaycareDateOverrideModel>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final DaycareDateOverrideModel model = DaycareDateOverrideModel.fromMap(
        doc.data(),
        id: doc.id,
      );
      result[model.id] = model;
      result[model.date] = model;
    }
    return result;
  }

  Stream<List<DaycareDateOverrideModel>> streamRange({
    required String shopId,
    required DateTime start,
    required DateTime end,
  }) {
    final String startId = DaycareTimeHelper.overrideDocId(start);
    final String endId = DaycareTimeHelper.overrideDocId(end);
    return _col(shopId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          return snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    DaycareDateOverrideModel.fromMap(doc.data(), id: doc.id),
              )
              .toList();
        });
  }

  Future<void> save({
    required String shopId,
    required DaycareDateOverrideModel override,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _col(
      shopId,
    ).doc(override.id);
    final bool exists = (await ref.get()).exists;
    await ref.set(<String, dynamic>{
      ...override.toMap(),
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveMany({
    required String shopId,
    required List<DateTime> dates,
    required bool isOpen,
    int maxPets = 0,
    String openTime = '',
    String closeTime = '',
    String latestDropoffTime = '',
    String latestPickupTime = '',
    String note = '',
  }) async {
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    for (final DateTime date in dates) {
      final String id = DaycareTimeHelper.overrideDocId(date);
      final DocumentReference<Map<String, dynamic>> ref = _col(shopId).doc(id);
      final bool exists = (await ref.get()).exists;
      final DaycareDateOverrideModel model = DaycareDateOverrideModel(
        id: id,
        date: DaycareTimeHelper.dateKey(date),
        isOpen: isOpen,
        maxPets: maxPets,
        openTime: openTime,
        closeTime: closeTime,
        latestDropoffTime: latestDropoffTime,
        latestPickupTime: latestPickupTime,
        note: note,
      );
      batch.set(ref, <String, dynamic>{
        ...model.toMap(),
        if (!exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> delete({required String shopId, required DateTime date}) {
    return _col(shopId).doc(DaycareTimeHelper.overrideDocId(date)).delete();
  }
}
