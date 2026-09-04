// lib/core/services/shop_card_media_service.dart
// 🖼️ 我的店家卡片圖片 Service
// 功能：上傳平台首頁「我的店家卡片」專用大圖與 Logo
// 規則：限制 5MB、新圖覆蓋 Firestore 欄位、刪除 Storage 舊圖

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ShopCardMediaService {
  ShopCardMediaService._();

  static final instance = ShopCardMediaService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int maxImageBytes = 5 * 1024 * 1024;

  Future<String> uploadPlatformHomeCover({
    required String shopId,
    required Uint8List bytes,
  }) async {
    return _uploadAndReplaceImage(
      shopId: shopId,
      bytes: bytes,
      fieldName: 'platformHomeCoverUrl',
      folderName: 'platform_home_cover',
    );
  }

  Future<String> uploadPlatformHomeLogo({
    required String shopId,
    required Uint8List bytes,
  }) async {
    return _uploadAndReplaceImage(
      shopId: shopId,
      bytes: bytes,
      fieldName: 'platformHomeLogoUrl',
      folderName: 'platform_home_logo',
    );
  }

  Future<String> _uploadAndReplaceImage({
    required String shopId,
    required Uint8List bytes,
    required String fieldName,
    required String folderName,
  }) async {
    if (bytes.lengthInBytes > maxImageBytes) {
      throw Exception('圖片不可超過 5MB');
    }

    final shopRef = _firestore.collection('shops').doc(shopId);

    final oldDoc = await shopRef.get();
    final oldUrl = oldDoc.data()?[fieldName]?.toString() ?? '';

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final storageRef = _storage.ref().child(
      'shops/$shopId/$folderName/$fileName',
    );

    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final newUrl = await storageRef.getDownloadURL();

    await shopRef.update({
      fieldName: newUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (oldUrl.isNotEmpty && oldUrl != newUrl) {
      try {
        await _storage.refFromURL(oldUrl).delete();
      } catch (e) {
        print('刪除舊圖片失敗：$e');
      }
    }

    return newUrl;
  }
}
