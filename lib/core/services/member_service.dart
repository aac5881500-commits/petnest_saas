// 檔案名稱：lib/core/services/member_service.dart
// 功能說明：建立 / 更新店家會員快取，並同步會員寵物到店家會員資料
// 👤 會員服務（跨店會員系統）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberService {
  MemberService._();
  static final instance = MemberService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔥 確保會員存在（登入店家時呼叫）
  Future<void> ensureMember({
    required String shopId,
    String? name,
    String? phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final memberRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(user.uid);

    final doc = await memberRef.get();

    final profileDoc = await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .get();

    final profileData = profileDoc.data() ?? {};

    final profileName = (profileData['name'] ?? '').toString().trim();
    final profilePhone = (profileData['phone'] ?? '').toString().trim();

    final rawAddress = profileData['address'];
    String addressText = '';

    if (rawAddress is Map) {
      addressText =
          [rawAddress['city'], rawAddress['district'], rawAddress['detail']]
              .where((v) => (v ?? '').toString().trim().isNotEmpty)
              .map((v) => v.toString())
              .join('');
    } else {
      addressText = (rawAddress ?? '').toString().trim();
    }

    final emergencyContact = profileData['emergencyContact'] is Map
        ? Map<String, dynamic>.from(profileData['emergencyContact'])
        : <String, dynamic>{};

    try {
      if (doc.exists) {
        await memberRef.set({
          'userId': user.uid,
          'email': user.email ?? '',
          'name': name ?? profileName.ifEmpty(user.displayName ?? ''),
          'phone': phone ?? profilePhone.ifEmpty(user.phoneNumber ?? ''),
          'address': addressText,
          'emergencyContact': emergencyContact,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastBookingAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await memberRef.set({
          'userId': user.uid,
          'email': user.email ?? '',
          'name': name ?? profileName.ifEmpty(user.displayName ?? ''),
          'phone': phone ?? profilePhone.ifEmpty(user.phoneNumber ?? ''),
          'address': addressText,
          'emergencyContact': emergencyContact,
          'petCount': 0,
          'bookingCount': 0,
          'tags': <String>[],
          'blacklisted': false,
          'blacklistReason': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastBookingAt': FieldValue.serverTimestamp(),
          'isBlocked': false,
        }, SetOptions(merge: true));
      }

      await syncCurrentUserPetsToShopMember(shopId: shopId);
    } catch (e) {
      print('🔥 ensureMember錯誤');
      print(e);
      rethrow;
    }
  }

  /// 🐾 同步目前登入會員的寵物到店家會員快取
  Future<void> syncCurrentUserPetsToShopMember({required String shopId}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final petsSnapshot = await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .collection('pets')
        .get();

    final memberRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(user.uid);

    final batch = _firestore.batch();

    for (final petDoc in petsSnapshot.docs) {
      batch.set(memberRef.collection('pets').doc(petDoc.id), {
        ...petDoc.data(),
        'petId': petDoc.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    batch.set(memberRef, {
      'petCount': petsSnapshot.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// 🔥 更新最後登入時間
  Future<void> updateLastLogin({required String shopId}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await ensureMember(shopId: shopId);
  }
}

extension _StringFallback on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
