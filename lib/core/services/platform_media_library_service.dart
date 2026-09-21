// 檔案名稱：lib/core/services/platform_media_library_service.dart
// 功能說明：平台外觀圖庫上傳、啟用與讀取。店家只讀 enabled 素材並快取，避免每卡各打一筆。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/platform_media_asset.dart';

class PlatformMediaLibraryService {
  PlatformMediaLibraryService._();

  static final PlatformMediaLibraryService instance =
      PlatformMediaLibraryService._();

  static const String collectionName = 'platform_media_library';
  static const int maxImageBytes = 5 * 1024 * 1024;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  final Map<String, PlatformMediaAsset> _enabledCache =
      <String, PlatformMediaAsset>{};

  CollectionReference<Map<String, dynamic>> get _col {
    return _firestore.collection(collectionName);
  }

  Map<String, PlatformMediaAsset> get enabledCache =>
      Map<String, PlatformMediaAsset>.unmodifiable(_enabledCache);

  PlatformMediaAsset? cachedEnabledAsset(String id) {
    final String key = id.trim();
    if (key.isEmpty) {
      return null;
    }
    final PlatformMediaAsset? asset = _enabledCache[key];
    if (asset == null || !asset.enabled) {
      return null;
    }
    return asset;
  }

  Stream<List<PlatformMediaAsset>> streamEnabledAssets([String? category]) {
    return _col.where('enabled', isEqualTo: true).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<PlatformMediaAsset> list = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                PlatformMediaAsset.fromMap(doc.id, doc.data()),
          )
          .where((PlatformMediaAsset asset) => asset.enabled)
          .toList();
      _sort(list);
      _enabledCache
        ..clear()
        ..addEntries(
          list.map(
            (PlatformMediaAsset asset) =>
                MapEntry<String, PlatformMediaAsset>(asset.id, asset),
          ),
        );
      return _filterCategory(list, category);
    });
  }

  Stream<List<PlatformMediaAsset>> streamAllAssets([String? category]) {
    return _col.snapshots().map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<PlatformMediaAsset> list = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                PlatformMediaAsset.fromMap(doc.id, doc.data()),
          )
          .toList();
      _sort(list);
      return _filterCategory(list, category);
    });
  }

  Future<PlatformMediaAsset?> getEnabledAssetById(String id) async {
    final PlatformMediaAsset? cached = cachedEnabledAsset(id);
    if (cached != null) {
      return cached;
    }
    final String key = id.trim();
    if (key.isEmpty) {
      return null;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _col
          .doc(key)
          .get();
      if (!doc.exists) {
        return null;
      }
      final PlatformMediaAsset asset = PlatformMediaAsset.fromMap(
        doc.id,
        doc.data(),
      );
      if (!asset.enabled) {
        return null;
      }
      _enabledCache[asset.id] = asset;
      return asset;
    } catch (_) {
      return null;
    }
  }

  Future<PlatformMediaAsset> uploadAsset({
    required Uint8List bytes,
    required String contentType,
    required String name,
    required String category,
    int sortOrder = 0,
    bool enabled = true,
    int width = 0,
    int height = 0,
  }) async {
    _assertImage(bytes, contentType);
    final String normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('請輸入圖片名稱');
    }
    final String normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) {
      throw ArgumentError('請選擇分類');
    }

    final DocumentReference<Map<String, dynamic>> doc = _col.doc();
    final String extension = _extensionFor(contentType);
    final String storagePath =
        'platform/media_library/${doc.id}/original.$extension';
    final String normalizedType = _normalizeContentType(contentType);
    final User? user = _auth.currentUser;

    try {
      final Reference ref = _storage.ref().child(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: normalizedType));
      final String imageUrl = await ref.getDownloadURL();
      final Map<String, dynamic> data = <String, dynamic>{
        'name': normalizedName,
        'category': normalizedCategory,
        'imageUrl': imageUrl,
        'thumbnailUrl': imageUrl,
        'storagePath': storagePath,
        'width': width,
        'height': height,
        'fileBytes': bytes.lengthInBytes,
        'sortOrder': sortOrder,
        'enabled': enabled,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': user?.uid ?? '',
        'createdByEmail': user?.email ?? '',
      };
      await doc.set(data);
      return PlatformMediaAsset.fromMap(doc.id, <String, dynamic>{
        ...data,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    } catch (error) {
      try {
        await _storage.ref().child(storagePath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> updateAsset({
    required String id,
    String? name,
    String? category,
    int? sortOrder,
    bool? enabled,
    Uint8List? bytes,
    String? contentType,
    int? width,
    int? height,
  }) async {
    final String key = id.trim();
    if (key.isEmpty) {
      throw ArgumentError('缺少素材 ID');
    }
    final DocumentSnapshot<Map<String, dynamic>> current = await _col
        .doc(key)
        .get();
    if (!current.exists) {
      throw StateError('找不到圖庫素材');
    }
    final PlatformMediaAsset old = PlatformMediaAsset.fromMap(
      current.id,
      current.data(),
    );
    String imageUrl = old.imageUrl;
    String thumbnailUrl = old.thumbnailUrl;
    String storagePath = old.storagePath;
    int fileBytes = old.fileBytes;
    int nextWidth = width ?? old.width;
    int nextHeight = height ?? old.height;
    String? uploadedPath;

    try {
      if (bytes != null) {
        _assertImage(bytes, contentType ?? '');
        final String extension = _extensionFor(contentType ?? '');
        uploadedPath = 'platform/media_library/$key/original.$extension';
        final Reference ref = _storage.ref().child(uploadedPath);
        await ref.putData(
          bytes,
          SettableMetadata(
            contentType: _normalizeContentType(contentType ?? ''),
          ),
        );
        imageUrl = await ref.getDownloadURL();
        thumbnailUrl = imageUrl;
        storagePath = uploadedPath;
        fileBytes = bytes.lengthInBytes;
      }

      await _col.doc(key).update(<String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (category != null) 'category': category.trim(),
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (enabled != null) 'enabled': enabled,
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
        'storagePath': storagePath,
        'width': nextWidth,
        'height': nextHeight,
        'fileBytes': fileBytes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (bytes != null &&
          old.storagePath.isNotEmpty &&
          old.storagePath != storagePath) {
        try {
          await _storage.ref().child(old.storagePath).delete();
        } catch (_) {}
      }
    } catch (error) {
      if (uploadedPath != null && uploadedPath != old.storagePath) {
        try {
          await _storage.ref().child(uploadedPath).delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> setEnabled({required String id, required bool enabled}) {
    return updateAsset(id: id, enabled: enabled);
  }

  Future<void> deleteAsset(String id) async {
    final String key = id.trim();
    if (key.isEmpty) {
      throw ArgumentError('缺少素材 ID');
    }
    final DocumentSnapshot<Map<String, dynamic>> current = await _col
        .doc(key)
        .get();
    final String storagePath = current.data()?['storagePath']?.toString() ?? '';
    await _col.doc(key).delete();
    _enabledCache.remove(key);
    if (storagePath.trim().isNotEmpty) {
      try {
        await _storage.ref().child(storagePath.trim()).delete();
      } catch (_) {}
    }
  }

  static List<PlatformMediaAsset> _filterCategory(
    List<PlatformMediaAsset> list,
    String? category,
  ) {
    final String key = category?.trim() ?? '';
    if (key.isEmpty) {
      return list;
    }
    return list
        .where((PlatformMediaAsset asset) => asset.category == key)
        .toList();
  }

  static void _sort(List<PlatformMediaAsset> list) {
    list.sort((PlatformMediaAsset a, PlatformMediaAsset b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) {
        return byOrder;
      }
      return a.name.compareTo(b.name);
    });
  }

  static void _assertImage(Uint8List bytes, String contentType) {
    if (bytes.isEmpty) {
      throw ArgumentError('請選擇圖片');
    }
    if (bytes.lengthInBytes > maxImageBytes) {
      throw ArgumentError('圖片不可超過 5 MB');
    }
    final String type = _normalizeContentType(contentType);
    if (type != 'image/jpeg' && type != 'image/png' && type != 'image/webp') {
      throw ArgumentError('只接受 JPG、PNG、WEBP');
    }
  }

  static String _normalizeContentType(String contentType) {
    final String type = contentType.trim().toLowerCase();
    if (type == 'image/jpg' || type == 'image/jpeg') {
      return 'image/jpeg';
    }
    if (type == 'image/png') {
      return 'image/png';
    }
    if (type == 'image/webp') {
      return 'image/webp';
    }
    return type;
  }

  static String _extensionFor(String contentType) {
    switch (_normalizeContentType(contentType)) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  @visibleForTesting
  static String normalizeContentTypeForTest(String contentType) {
    return _normalizeContentType(contentType);
  }

  @visibleForTesting
  static String extensionForTest(String contentType) {
    return _extensionFor(contentType);
  }
}
