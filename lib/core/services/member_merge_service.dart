// lib/core/services/member_merge_service.dart
// 🔀 會員合併 Service
// 功能：掃描同電話的手動會員與店家會員，並執行訂單合併

import 'package:cloud_firestore/cloud_firestore.dart';

class MemberMergeCandidate {
  const MemberMergeCandidate({
    required this.phone,
    required this.manualUserId,
    required this.manualName,
    required this.manualBookingCount,
    required this.manualPetCount,
    required this.appUserId,
    required this.appName,
    required this.appBookingCount,
    required this.appPetCount,
  });

  final String phone;

  final String manualUserId;
  final String manualName;
  final int manualBookingCount;
  final int manualPetCount;

  final String appUserId;
  final String appName;
  final int appBookingCount;
  final int appPetCount;
}

class MemberMergeService {
  MemberMergeService._();

  static final instance = MemberMergeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  Future<List<MemberMergeCandidate>> findCandidates({
    required String shopId,
  }) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .get();

    final members = snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'userId': doc.id};
    }).toList();

    final manualMembers = members.where((member) {
      final source = (member['source'] ?? '').toString();
      final status = (member['status'] ?? '').toString();
      final phone = (member['phone'] ?? '').toString().trim();

      return source == 'admin' && status != 'merged' && phone.isNotEmpty;
    }).toList();

    final appMembers = members.where((member) {
      final source = (member['source'] ?? '').toString();
      final policyAcceptedFrom = (member['policyAcceptedFrom'] ?? '')
          .toString();
      final phone = (member['phone'] ?? '').toString().trim();

      final isAppMember =
          source == 'app' ||
          source == 'customer' ||
          policyAcceptedFrom == 'customer';

      return isAppMember && phone.isNotEmpty;
    }).toList();

    final candidates = <MemberMergeCandidate>[];

    for (final manual in manualMembers) {
      final manualPhone = (manual['phone'] ?? '').toString().trim();

      final matchedApps = appMembers.where((app) {
        final appPhone = (app['phone'] ?? '').toString().trim();
        return appPhone == manualPhone;
      }).toList();

      if (matchedApps.isEmpty) continue;

      final app = matchedApps.first;

      candidates.add(
        MemberMergeCandidate(
          phone: manualPhone,
          manualUserId: manual['userId'].toString(),
          manualName: (manual['name'] ?? '未命名手動會員').toString(),
          manualBookingCount: _toInt(manual['bookingCount']),
          manualPetCount: _toInt(manual['petCount']),
          appUserId: app['userId'].toString(),
          appName: (app['name'] ?? '未命名店家會員').toString(),
          appBookingCount: _toInt(app['bookingCount']),
          appPetCount: _toInt(app['petCount']),
        ),
      );
    }
    print('======= Merge Candidates =======');
    print('manualMembers: ${manualMembers.length}');
    print('appMembers: ${appMembers.length}');
    print('candidates: ${candidates.length}');
    return candidates;
  }

  Future<int> mergeManualToApp({
    required String shopId,
    required String manualUserId,
    required String appUserId,
  }) async {
    final bookingsSnapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: manualUserId)
        .get();

    final batch = _firestore.batch();

    final appMemberRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(appUserId);

    final manualMemberRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(manualUserId);

    for (final bookingDoc in bookingsSnapshot.docs) {
      batch.update(bookingDoc.reference, {
        'userId': appUserId,
        'mergedFromUserId': manualUserId,
        'mergedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(appMemberRef, {
      'bookingCount': FieldValue.increment(bookingsSnapshot.docs.length),

      // 🔔 客戶端顯示一次「歷史訂單已同步」提示用
      'historyMergedNoticeShown': false,
      'historyMergedBookingCount': bookingsSnapshot.docs.length,
      'historyMergedFromUserId': manualUserId,
      'historyMergedAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(manualMemberRef, {
      'status': 'merged',
      'mergedToUserId': appUserId,
      'mergedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_firestore.collection('action_logs').doc(), {
      'type': 'member_booking_merged',
      'shopId': shopId,
      'targetUserId': appUserId,
      'fromUserId': manualUserId,
      'bookingCount': bookingsSnapshot.docs.length,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return bookingsSnapshot.docs.length;
  }
}
