import 'package:petnest_saas/core/models/pet_species.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';

class PetServiceModuleService {
  PetServiceModuleService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : db = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String? get currentUserId => auth.currentUser?.uid;
  DocumentReference<Map<String, dynamic>> configRef(
    String shop,
    String module,
  ) => db
      .collection('shops')
      .doc(shop)
      .collection('service_modules')
      .doc(module);
  CollectionReference<Map<String, dynamic>> requests(String shop) =>
      db.collection('shops').doc(shop).collection('service_requests');
  Stream<PetServiceConfig> watchConfig(String shop, PetServiceModule module) =>
      configRef(
        shop,
        module.id,
      ).snapshots().map((s) => PetServiceConfig(module, s.data()));
  Stream<List<Map<String, dynamic>>> watchRequests(
    String shop,
    String module, {
    bool mine = false,
  }) {
    Query<Map<String, dynamic>> q = requests(
      shop,
    ).where('module', isEqualTo: module);
    if (mine) {
      q = q.where(
        'userId',
        isEqualTo: auth.currentUser?.uid ?? '__signed_out__',
      );
    }
    return q.snapshots().map((s) {
      final rows = s.docs
          .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
          .toList();
      rows.sort(
        (a, b) =>
            '${b['date']} ${b['time']}'.compareTo('${a['date']} ${a['time']}'),
      );
      return rows;
    });
  }

  Future<void> saveConfig(
    String shop,
    PetServiceModule module,
    Map<String, dynamic> data,
  ) async {
    final config = PetServiceConfig(module, data);
    if (config.acceptedSpecies.isEmpty) throw StateError('請至少選擇一種可接待的寵物');
    if (config.days.isEmpty || config.opens >= config.closes) {
      throw StateError('請設定有效營業日與起訖時間');
    }
    if (config.enabled && !config.ready) throw StateError('開放前請建立啟用的服務項目及服務人員');
    final ref = configRef(shop, module.id);
    await db.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (current.data()?['updatedAt'] != data['_revision']) {
        throw StateError('設定已被其他人更新，請重新讀取');
      }
      final payload = config.editable..remove('_revision');
      tx.set(ref, {...payload, 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  Stream<List<Map<String, dynamic>>> watchMyPets() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);
    return db
        .collection('user_profiles')
        .doc(uid)
        .collection('pets')
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => <String, dynamic>{...d.data(), 'petId': d.id})
              .toList(),
        );
  }

  /// Reuse this document ID on retry, including after an ambiguous network result.
  String newRequestId(String shop) => requests(shop).doc().id;
  Future<void> submit(String shop, String id, Map<String, dynamic> data) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('請先登入');
    final module = PetServiceModule.all.firstWhere(
      (m) => m.id == data['module'],
    );
    final config = PetServiceConfig(
      module,
      (await configRef(
        shop,
        module.id,
      ).get(const GetOptions(source: Source.server))).data(),
    );
    final petId = '${data['petId'] ?? ''}';
    if (petId.isEmpty) throw StateError('請選擇會員寵物');
    final petDoc = await db
        .collection('user_profiles')
        .doc(uid)
        .collection('pets')
        .doc(petId)
        .get(const GetOptions(source: Source.server));
    final pet = petDoc.data();
    if (pet == null || !config.acceptedSpecies.contains(PetSpecies.of(pet))) {
      throw StateError('此服務不接受這隻寵物的種類，請重新選擇');
    }
    data = {
      ...data,
      'species': PetSpecies.of(pet),
      'petName': pet['name'],
      'petSnapshot': PetSnapshot.fromPet({...pet, 'petId': petId}),
    };
    final ref = requests(shop).doc(id);
    // Plain set is intentional: rules permit create only, so a retry cannot alter a received request.
    try {
      await ref.set({
        ...data,
        'userId': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      final existing = await ref.get(const GetOptions(source: Source.server));
      if (!existing.exists || existing.data()?['userId'] != uid) rethrow;
    }
  }

  Future<void> transition(
    String shop,
    String id,
    String from,
    String to,
  ) async {
    if (!(serviceTransitions[from] ?? []).contains(to)) {
      throw StateError('不允許的狀態變更');
    }
    await db.runTransaction((tx) async {
      final ref = requests(shop).doc(id);
      final current = await tx.get(ref);
      if (current.data()?['status'] != from) throw StateError('狀態已更新，請重新查看');
      tx.update(ref, {'status': to, 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  Stream<List<Map<String, dynamic>>> records(String shop, String id) =>
      requests(shop)
          .doc(id)
          .collection('records')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
  Future<void> addRecord(String shop, String id, String note) =>
      requests(shop).doc(id).collection('records').add({
        'note': note.trim(),
        'authorId': auth.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

String petServiceFailure(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => '權限不足，請確認帳號權限與模組存取設定',
      'unavailable' || 'network-request-failed' => '目前無法連線，請確認網路後重試',
      _ => '資料操作失敗，請重新讀取後重試',
    };
  }
  return '操作未完成，請稍後重試';
}
