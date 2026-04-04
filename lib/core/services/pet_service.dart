// lib/core/services/pet_service.dart
// 🐱 PetService（會員寵物完整版🔥）
//
// 功能：
// - 新增寵物（含完整欄位）
// - 上傳寵物照片（覆蓋 + Web支援🔥）
// - 取得寵物列表
//
// 📦 結構：
// user_profiles/{uid}/pets/{petId}

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class PetService {
  PetService._();
  static final PetService instance = PetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔐 取得 UID
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('尚未登入');
    return user.uid;
  }

  // ===============================
  // 🖼️ 上傳寵物照片（覆蓋舊圖 + Web支援🔥）
  // ===============================
  Future<void> uploadPetPhoto({
    required String petId,
    required Uint8List bytes,
  }) async {
    Uint8List uploadData;

    if (kIsWeb) {
      /// 🔥 Web：不能用 image 套件 → 直接上傳
      uploadData = bytes;
    } else {
      /// 🔥 手機：壓縮圖片
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('圖片解析失敗');

      final resized = img.copyResize(
        image,
        width: 800,
      );

      uploadData = img.encodeJpg(resized, quality: 85);
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('pets')
        .child(_uid)
        .child('$petId.jpg');

    /// 🔥 覆蓋上傳
    await ref.putData(
  uploadData,
  SettableMetadata(
    contentType: 'image/jpeg',
  ),
);

    final url = await ref.getDownloadURL();

    await _firestore
        .collection('user_profiles')
        .doc(_uid)
        .collection('pets')
        .doc(petId)
        .update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===============================
  // 🐱 取得寵物列表
  // ===============================
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

  // ===============================
  // 🐱 新增寵物（完整版🔥）
  // ===============================
  Future<String> createPet({
    required String name,

    /// 固定貓（之後可擴狗）
    String type = 'cat',

    /// 基本
    String gender = '',
    String litterType = '',

    /// 🔥 新增欄位
    String age = '',
    String breed = '',
    String vaccine = '',
    String note = '',

    /// 狀態
    bool isNeutered = false,
    bool canSocial = false,
    bool canMedicate = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('未登入');

    final petsRef = _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .collection('pets');

    /// 🔥 限制最多 5 隻
    final snapshot = await petsRef.get();
    if (snapshot.docs.length >= 5) {
      throw Exception('最多只能新增 5 隻寵物');
    }

    final doc = petsRef.doc();

    await doc.set({
      'petId': doc.id,
      'userId': user.uid,

      /// 基本
      'name': name,
      'type': type,
      'gender': gender,
      'litterType': litterType,

      /// 🔥 新欄位
      'age': age,
      'breed': breed,
      'vaccine': vaccine,
      'note': note,

      /// 狀態
      'isNeutered': isNeutered,
      'canSocial': canSocial,
      'canMedicate': canMedicate,

      /// 照片
      'photoUrl': '',

      /// 系統
      'createdAt': FieldValue.serverTimestamp(),
    });

    /// 🔥 更新數量
    await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .set({
      'petsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return doc.id;
  }
}