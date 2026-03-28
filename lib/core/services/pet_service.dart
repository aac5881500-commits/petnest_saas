// lib/core/services/pet_service.dart
// 🔥 寵物服務（平台 pets）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PetService {
  PetService._();
  static final instance = PetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _user => _auth.currentUser;

  /// 📥 監聽目前使用者的寵物
  Stream<List<Map<String, dynamic>>> streamMyPets() {
    final user = _user;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
    .collection('users')
    .doc(user.uid)
    .collection('pets')
    .snapshots()
    .map((snapshot) {
  return snapshot.docs.map((doc) {
    return {
      'petId': doc.id,
      ...doc.data(),
    };
  }).toList();
});
  }
  Future<void> createPet({
  required String name,
  required String type,
}) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final doc = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('pets')
      .doc();

  await doc.set({
    'petId': doc.id,
    'name': name,
    'type': type,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
}