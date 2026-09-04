// lib/core/services/member_avatar_service.dart
// 會員自訂大頭貼。
// Storage 使用現有已允許路徑：pets/{uid}/avatar_{timestamp}.jpg
// （與寵物照片同一規則：本人 JPEG 寫入）
// Firestore：user_profiles/{uid}.avatarUrl / avatarStoragePath
// 不更新 Firebase Auth photoURL。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class MemberAvatarUpload {
  const MemberAvatarUpload({
    required this.imageUrl,
    required this.imageStoragePath,
  });

  final String imageUrl;
  final String imageStoragePath;
}

class MemberAvatarService {
  MemberAvatarService._();

  static final MemberAvatarService instance = MemberAvatarService._();

  static const int maxImageBytes = 5 * 1024 * 1024;
  static const int outputSize = 800;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static void logFailure(
    String operation,
    Object error, [
    StackTrace? stack,
    String extra = '',
  ]) {
    if (error is FirebaseException) {
      debugPrint(
        '[Avatar] $operation failed: '
        'code=${error.code} message=${error.message} '
        'plugin=${error.plugin} $extra',
      );
    } else {
      debugPrint('[Avatar] $operation failed: $error $extra');
    }
    if (stack != null) {
      debugPrint('[Avatar] $operation stack:\n$stack');
    }
  }

  /// Web / 手機皆走 Uint8List + putData，不使用 dart:io File。
  Future<MemberAvatarUpload> uploadAvatarBytes(Uint8List bytes) async {
    final User user = _requireUser();
    if (bytes.isEmpty) {
      throw Exception('圖片處理失敗，請重新選擇圖片。');
    }
    if (bytes.length > maxImageBytes) {
      throw Exception('單張圖片最大 5 MB，請換一張較小的照片');
    }

    final String fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'pets/${user.uid}/$fileName';
    final Reference ref = _storage.ref().child(storagePath);

    debugPrint(
      '[Avatar] upload start path=$storagePath '
      'bytes=${bytes.length} contentType=image/jpeg uid=${user.uid}',
    );

    try {
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      debugPrint('[Avatar] upload success path=$storagePath');
    } on FirebaseException catch (e, st) {
      logFailure('upload', e, st, 'path=$storagePath');
      rethrow;
    } catch (e, st) {
      logFailure('upload', e, st, 'path=$storagePath');
      rethrow;
    }

    try {
      final String url = await ref.getDownloadURL();
      debugPrint('[Avatar] getDownloadURL success path=$storagePath');
      return MemberAvatarUpload(imageUrl: url, imageStoragePath: storagePath);
    } on FirebaseException catch (e, st) {
      logFailure('getDownloadURL', e, st, 'path=$storagePath');
      await tryDeleteOwnedAvatar(
        uid: user.uid,
        storagePath: storagePath,
        imageUrl: '',
      );
      rethrow;
    } catch (e, st) {
      logFailure('getDownloadURL', e, st, 'path=$storagePath');
      await tryDeleteOwnedAvatar(
        uid: user.uid,
        storagePath: storagePath,
        imageUrl: '',
      );
      rethrow;
    }
  }

  /// 先更新 Firestore 指向新圖，成功後才刪舊圖。
  /// Firestore 失敗時刪剛上傳的新檔，舊圖維持不變。
  /// 不呼叫 Firebase Auth updatePhotoURL。
  Future<void> replaceProfileAvatar({
    required String newImageUrl,
    required String newStoragePath,
    String previousImageUrl = '',
    String previousStoragePath = '',
  }) async {
    final User user = _requireUser();
    final String profilePath = 'user_profiles/${user.uid}';

    debugPrint(
      '[Avatar] firestore update start path=$profilePath '
      'fields=avatarUrl,avatarStoragePath newStorage=$newStoragePath',
    );

    try {
      await _firestore.collection('user_profiles').doc(user.uid).set({
        'avatarUrl': newImageUrl,
        'avatarStoragePath': newStoragePath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[Avatar] firestore update success path=$profilePath');
    } catch (e, st) {
      logFailure('firestoreUpdate', e, st, 'path=$profilePath');
      debugPrint(
        '[Avatar] firestore failed, cleanup new image $newStoragePath',
      );
      await tryDeleteOwnedAvatar(
        uid: user.uid,
        storagePath: newStoragePath,
        imageUrl: newImageUrl,
      );
      rethrow;
    }

    if (previousStoragePath.trim() == newStoragePath.trim() &&
        previousStoragePath.trim().isNotEmpty) {
      return;
    }

    if (previousStoragePath.trim().isEmpty && previousImageUrl.trim().isEmpty) {
      return;
    }

    debugPrint('[Avatar] cleanup old image path=$previousStoragePath');
    await tryDeleteOwnedAvatar(
      uid: user.uid,
      storagePath: previousStoragePath,
      imageUrl: previousImageUrl,
    );
  }

  /// 先清掉 profile 圖片欄位，成功後才刪 Storage。不刪 Google 原始圖片。
  Future<void> removeProfileAvatar({
    String previousImageUrl = '',
    String previousStoragePath = '',
  }) async {
    final User user = _requireUser();
    final String profilePath = 'user_profiles/${user.uid}';

    debugPrint('[Avatar] firestore clear avatar path=$profilePath');

    try {
      await _firestore.collection('user_profiles').doc(user.uid).set({
        'avatarUrl': '',
        'avatarStoragePath': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      logFailure('firestoreClear', e, st, 'path=$profilePath');
      rethrow;
    }

    await tryDeleteOwnedAvatar(
      uid: user.uid,
      storagePath: previousStoragePath,
      imageUrl: previousImageUrl,
    );
  }

  Future<bool> tryDeleteOwnedAvatar({
    required String uid,
    String storagePath = '',
    String imageUrl = '',
  }) async {
    final String? path = _safeOwnedPath(
      uid: uid,
      storagePath: storagePath,
      imageUrl: imageUrl,
    );
    if (path == null) {
      debugPrint(
        '[Avatar] skip delete: not an owned PetNest avatar '
        'path=$storagePath url=$imageUrl',
      );
      return true;
    }

    debugPrint('[Avatar] delete start path=$path');
    try {
      await _storage.ref().child(path).delete();
      debugPrint('[Avatar] delete success path=$path');
      return true;
    } on FirebaseException catch (e, st) {
      if (e.code == 'object-not-found') {
        debugPrint('[Avatar] delete skip, object-not-found path=$path');
        return true;
      }
      logFailure('delete', e, st, 'path=$path');
      return false;
    } catch (e, st) {
      logFailure('delete', e, st, 'path=$path');
      return false;
    }
  }

  User _requireUser() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('尚未登入');
    }
    return user;
  }

  String? _safeOwnedPath({
    required String uid,
    required String storagePath,
    required String imageUrl,
  }) {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return null;
    }

    final String fromPath = storagePath.trim();
    if (_isOwnedAvatarPath(uid: normalizedUid, path: fromPath)) {
      return fromPath;
    }

    final String fromUrl = _pathFromDownloadUrl(imageUrl);
    if (_isOwnedAvatarPath(uid: normalizedUid, path: fromUrl)) {
      return fromUrl;
    }

    return null;
  }

  bool _isOwnedAvatarPath({required String uid, required String path}) {
    if (uid.isEmpty || path.isEmpty) {
      return false;
    }
    if (path.contains('..') || path.contains('//')) {
      return false;
    }

    final String petsPrefix = 'pets/$uid/';
    final String usersPrefix = 'users/$uid/profile/';
    final String relative;
    if (path.startsWith(petsPrefix)) {
      relative = path.substring(petsPrefix.length);
    } else if (path.startsWith(usersPrefix)) {
      relative = path.substring(usersPrefix.length);
    } else {
      return false;
    }

    return RegExp(r'^avatar_\d+\.jpg$').hasMatch(relative);
  }

  String _pathFromDownloadUrl(String imageUrl) {
    final String url = imageUrl.trim();
    if (url.isEmpty) {
      return '';
    }
    if (_looksLikeGooglePhoto(url)) {
      return '';
    }

    try {
      return _storage.refFromURL(url).fullPath;
    } catch (_) {
      return '';
    }
  }

  bool _looksLikeGooglePhoto(String url) {
    final String lower = url.toLowerCase();
    return lower.contains('googleusercontent.com') ||
        lower.contains('ggpht.com') ||
        lower.contains('google.com/a/');
  }
}
