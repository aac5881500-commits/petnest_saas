// 檔案名稱：lib/core/services/pet_service.dart
// 功能說明：PetService（會員寵物完整版）
// 功能：
// - 新增寵物（含完整欄位）
// - 上傳寵物照片（覆蓋 + Web支援🔥）
// - 取得寵物列表
//
// 📦 結構：
// user_profiles/{uid}/pets/{petId}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';

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
    bool alreadyProcessed = false,
  }) async {
    Uint8List uploadData;

    if (alreadyProcessed || kIsWeb) {
      uploadData = bytes;
    } else {
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('圖片解析失敗');

      final resized = img.copyResize(image, width: 800);

      uploadData = img.encodeJpg(resized, quality: 85);
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('pets')
        .child(_uid)
        .child('$petId.jpg');

    /// 🔥 覆蓋上傳
    await ref.putData(uploadData, SettableMetadata(contentType: 'image/jpeg'));

    final url = await ref.getDownloadURL();

    await _firestore
        .collection('user_profiles')
        .doc(_uid)
        .collection('pets')
        .doc(petId)
        .update({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // ===============================
  // 🐱 取得寵物列表
  // ===============================
  Stream<List<Map<String, dynamic>>> streamMyPets() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      ).asBroadcastStream();
    }
    return _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .collection('pets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'petId': doc.id, ...doc.data()};
          }).toList();
        });
  }

  // ===============================
  // 🐱 新增寵物（完整版🔥）
  // ===============================
  Future<String> createPet({
    required String name,

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
    String shopId = '',
    Map<String, dynamic>? customFormAnswers,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('未登入');

    final petsRef = _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .collection('pets');

    /// 🔥 限制最多 10 隻
    final snapshot = await petsRef.get();
    if (snapshot.docs.length >= 10) {
      throw Exception('最多只能新增 10 隻寵物');
    }
    final doc = petsRef.doc();

    final String normalizedShopId = shopId.trim();
    final Map<String, dynamic> payload = <String, dynamic>{
      'petId': doc.id,
      'userId': user.uid,

      /// 基本
      'name': name,
      'type': 'cat',
      'species': 'cat',
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
    };

    await doc.set(payload);

    if (PetShopFormAnswers.shouldWrite(customFormAnswers) &&
        normalizedShopId.isNotEmpty) {
      await saveShopFormAnswers(
        userId: user.uid,
        petId: doc.id,
        shopId: normalizedShopId,
        snapshot: customFormAnswers!,
      );
    }

    /// 🔥 更新數量
    await _firestore.collection('user_profiles').doc(user.uid).set({
      'petsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return doc.id;
  }

  DocumentReference<Map<String, dynamic>> shopFormAnswersDoc({
    required String userId,
    required String petId,
    required String shopId,
  }) {
    return _firestore
        .collection('user_profiles')
        .doc(userId.trim())
        .collection('pets')
        .doc(petId.trim())
        .collection(PetShopFormAnswers.collectionName)
        .doc(shopId.trim());
  }

  Future<void> saveShopFormAnswers({
    required String userId,
    required String petId,
    required String shopId,
    required Map<String, dynamic> snapshot,
  }) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty || !PetShopFormAnswers.shouldWrite(snapshot)) {
      return;
    }
    await shopFormAnswersDoc(
      userId: userId,
      petId: petId,
      shopId: normalizedShopId,
    ).set(
      PetShopFormAnswers.documentData(
        shopId: normalizedShopId,
        snapshot: snapshot,
      ),
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> loadShopFormAnswers({
    required String userId,
    required String petId,
    required String shopId,
    Map<String, dynamic>? petData,
  }) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await shopFormAnswersDoc(
          userId: userId,
          petId: petId,
          shopId: normalizedShopId,
        ).get();
    return PetShopFormAnswers.resolve(
      shopId: normalizedShopId,
      subcollectionData: snapshot.data(),
      petData: petData,
    );
  }
}
