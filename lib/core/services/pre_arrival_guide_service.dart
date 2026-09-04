// lib/core/services/pre_arrival_guide_service.dart
// 入住前準備 Firestore／Storage。路徑：shops/{shopId}/pre_arrival_guides/{serviceType}

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';

class PreArrivalGuideException implements Exception {
  const PreArrivalGuideException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PreArrivalGuideImageUpload {
  const PreArrivalGuideImageUpload({
    required this.imageUrl,
    required this.storagePath,
  });

  final String imageUrl;
  final String storagePath;
}

class PreArrivalGuideService {
  PreArrivalGuideService._();

  static final PreArrivalGuideService instance = PreArrivalGuideService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int maxImageBytes = 5 * 1024 * 1024;
  static const int maxEdge = 1600;
  static const int jpegQuality = 84;

  DocumentReference<Map<String, dynamic>> _doc({
    required String shopId,
    required String serviceType,
  }) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection('pre_arrival_guides')
        .doc(serviceType);
  }

  Future<PreArrivalGuideModel> getGuide({
    required String shopId,
    required String serviceType,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String type = serviceType.trim();
    if (normalizedShopId.isEmpty || !PreArrivalGuideServiceType.isValid(type)) {
      return PreArrivalGuideModel.empty(
        shopId: normalizedShopId,
        serviceType: type,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _doc(
      shopId: normalizedShopId,
      serviceType: type,
    ).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return PreArrivalGuideModel.empty(
        shopId: normalizedShopId,
        serviceType: type,
      );
    }

    return PreArrivalGuideModel.fromMap(
      shopId: normalizedShopId,
      serviceType: type,
      data: snapshot.data(),
    );
  }

  /// 客戶顯示用：安親可沿用住宿內容。
  Future<PreArrivalGuideModel> getCustomerGuide({
    required String shopId,
    required String serviceType,
  }) async {
    final PreArrivalGuideModel requested = await getGuide(
      shopId: shopId,
      serviceType: serviceType,
    );
    if (serviceType == PreArrivalGuideServiceType.daycare &&
        requested.inheritAccommodation) {
      return getGuide(
        shopId: shopId,
        serviceType: PreArrivalGuideServiceType.accommodation,
      );
    }
    return requested;
  }

  Future<void> saveGuide(PreArrivalGuideModel guide) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const PreArrivalGuideException('請先登入');
    }
    if (guide.shopId.trim().isEmpty) {
      throw const PreArrivalGuideException('找不到店家');
    }
    if (!PreArrivalGuideServiceType.isValid(guide.serviceType)) {
      throw const PreArrivalGuideException('服務類型不正確');
    }

    await _doc(
      shopId: guide.shopId,
      serviceType: guide.serviceType,
    ).set(guide.toMap(updatedBy: user.uid), SetOptions(merge: true));
  }

  Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    return picker.pickImage(source: ImageSource.gallery);
  }

  Future<PreArrivalGuideImageUpload> uploadImage({
    required String shopId,
    required String serviceType,
    required XFile image,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String type = serviceType.trim();
    if (normalizedShopId.isEmpty) {
      throw const PreArrivalGuideException('找不到店家');
    }
    if (!PreArrivalGuideServiceType.isValid(type)) {
      throw const PreArrivalGuideException('服務類型不正確');
    }

    final String name = image.name.toLowerCase();
    if (!(name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        image.mimeType == 'image/jpeg' ||
        image.mimeType == 'image/png' ||
        image.mimeType == 'image/jpg')) {
      throw const PreArrivalGuideException('僅支援 JPG、PNG 圖片');
    }

    final Uint8List original = await image.readAsBytes();
    if (original.isEmpty) {
      throw const PreArrivalGuideException('讀取圖片失敗，請重新選擇');
    }
    if (original.length > maxImageBytes) {
      throw const PreArrivalGuideException('圖片大小不可超過 5MB');
    }

    Uint8List compressed;
    try {
      compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: maxEdge,
        minHeight: maxEdge,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
    } catch (_) {
      throw const PreArrivalGuideException('圖片壓縮失敗，請改選其他圖片');
    }

    if (compressed.isEmpty || compressed.length > maxImageBytes) {
      throw const PreArrivalGuideException('圖片大小不可超過 5MB');
    }

    final String fileId = DateTime.now().millisecondsSinceEpoch.toString();
    final String path =
        'shops/$normalizedShopId/pre_arrival_guides/$type/$fileId.jpg';
    final Reference ref = _storage.ref(path);
    await ref.putData(
      compressed,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'shopId': normalizedShopId,
          'serviceType': type,
          'imageType': 'pre_arrival_guide',
        },
      ),
    );

    return PreArrivalGuideImageUpload(
      imageUrl: await ref.getDownloadURL(),
      storagePath: path,
    );
  }

  Future<void> deleteImage({
    String storagePath = '',
    String imageUrl = '',
  }) async {
    try {
      if (storagePath.trim().isNotEmpty) {
        await _storage.ref(storagePath.trim()).delete();
        return;
      }
      if (imageUrl.trim().isNotEmpty) {
        await _storage.refFromURL(imageUrl.trim()).delete();
      }
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }
      throw const PreArrivalGuideException('刪除圖片失敗');
    }
  }
}
