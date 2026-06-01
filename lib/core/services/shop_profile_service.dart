// lib/core/services/shop_profile_service.dart
// 🏪 店家基本資料 Service
// 功能：管理店家資料、營業資訊、Logo / Cover 圖片

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ShopProfileService {
  ShopProfileService._();

  static final instance = ShopProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  Future<void> deleteImageByUrl(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('刪除圖片失敗: $e');
    }
  }

  Future<void> updateShop({
    required String shopId,
    required Map<String, dynamic> data,
  }) async {
    await _shops.doc(shopId).update(data);
  }

  Future<Map<String, dynamic>?> getShop(String shopId) async {
    final doc = await _shops.doc(shopId).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};

    return {'shopId': doc.id, ...data};
  }

  Stream<Map<String, dynamic>?> streamShop(String shopId) {
    return _shops.doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {'shopId': doc.id, ...doc.data()!};
    });
  }

  Future<void> updateShopBasicInfo({
    required String shopId,
    required String name,
    String businessType = 'cat',
    String phone = '',
    String address = '',
    String description = '',
    String city = '',
    String district = '',
    String lineUrl = '',
    String igUrl = '',
    String fbUrl = '',
    String businessHours = '',
    String licenseNumber = '',
    String taxId = '',
    bool showTaxId = true,
  }) async {
    await _shops.doc(shopId).update({
      'name': name.trim(),
      'businessType': businessType,
      'phone': phone.trim(),
      'address': address.trim(),
      'description': description.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'lineUrl': lineUrl.trim(),
      'igUrl': igUrl.trim(),
      'fbUrl': fbUrl.trim(),
      'businessHours': businessHours.trim(),
      'licenseNumber': licenseNumber.trim(),
      'taxId': taxId.trim(),
      'showTaxId': showTaxId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBusinessInfo({
    required String shopId,
    required bool isOpen,
    String businessHours = '',
    String openTime = '',
    String closeTime = '',
    List<String> closedDays = const [],
    List<String> serviceTypes = const [],
    bool isPublic = false,
  }) async {
    await _shops.doc(shopId).update({
      'isOpen': isOpen,
      'businessHours': businessHours,
      'openTime': openTime,
      'closeTime': closeTime,
      'closedDays': closedDays,
      'serviceTypes': serviceTypes,
      'isPublic': isPublic,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadShopLogo({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('shops/$shopId/logo.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    final url = await ref.getDownloadURL();

    await _shops.doc(shopId).update({
      'logoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return url;
  }

  Future<String> uploadShopCover({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = _storage.ref().child('shops/$shopId/$fileName');

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    return await ref.getDownloadURL();
  }
}
