// lib/core/services/pet_service.dart
// 🐱 PetService（會員寵物）
// 負責：
// - 新增寵物
// - 取得寵物列表
// - 自動更新 petsCount
//
// ⚠️ 使用結構：
// /user_profiles/{uid}/pets/{petId}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PetService {
  PetService._();
  static final PetService instance = PetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔐 取得目前使用者 UID
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('尚未登入');
    }
    return user.uid;
  }

/// 🖼️ 上傳寵物照片（會覆蓋舊照片）
Future<void> uploadPetPhoto({
  required String petId,
}) async {
  final picker = ImagePicker();

  /// 選圖片
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return;

  final file = picked;

  /// 🔥 Storage 路徑（固定 = 覆蓋）
  final ref = FirebaseStorage.instance
      .ref()
      .child('pets')
      .child(_uid)
      .child('$petId.jpg');

  /// 上傳
  await ref.putData(await file.readAsBytes());

  /// 取得下載URL
  final url = await ref.getDownloadURL();

  /// 存到 Firestore
  await _firestore
      .collection('user_profiles')
      .doc(_uid)
      .collection('pets')
      .doc(petId)
      .update({
    'photoUrl': url,
  });
}

  /// 🐱 取得寵物列表（Stream）
  Stream<List<Map<String, dynamic>>> streamMyPets() {
    return _firestore
        .collection('user_profiles')
        .doc(_uid)
        .collection('pets')
        .orderBy('createdAt', descending: true)
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

  /// 🐱 新增寵物
  Future<void> createPet({
    required String name,
    required String type, // cat / dog
    String? breed,
    String? gender,
    DateTime? birthday,
    String? note,
  }) async {

// 🔥 檢查上限（最多5隻）
final snapshot = await _firestore
    .collection('user_profiles')
    .doc(_uid)
    .collection('pets')
    .get();

if (snapshot.docs.length >= 5) {
  throw Exception('最多只能新增 5 隻寵物');
}

    final petsRef = _firestore
        .collection('user_profiles')
        .doc(_uid)
        .collection('pets');

    final doc = petsRef.doc();

    await doc.set({
      'petId': doc.id,
      'name': name,
      'type': type,
      'breed': breed ?? '',
      'gender': gender ?? '',
      'birthday': birthday,
      'note': note ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🔥 更新寵物數量
    await _firestore
        .collection('user_profiles')
        .doc(_uid)
        .update({
      'petsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}