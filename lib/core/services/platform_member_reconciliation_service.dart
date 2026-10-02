// 檔案名稱：lib/core/services/platform_member_reconciliation_service.dart
// 功能說明：以 shops.ownerUid 為準，補齊缺少的 users/{ownerUid} 平台會員

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';

class MissingOwnerShop {
  const MissingOwnerShop({required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;
}

class MissingOwnerPlatformMember {
  const MissingOwnerPlatformMember({
    required this.ownerUid,
    required this.email,
    required this.displayName,
    required this.shops,
    required this.documentMissing,
    this.missingFields = const <String>[],
  });

  final String ownerUid;
  final String email;
  final String displayName;
  final List<MissingOwnerShop> shops;
  final bool documentMissing;
  final List<String> missingFields;
}

class OwnerPlatformMemberScan {
  const OwnerPlatformMemberScan({
    required this.missing,
    required this.incomplete,
  });

  final List<MissingOwnerPlatformMember> missing;
  final List<MissingOwnerPlatformMember> incomplete;

  bool get isClear => missing.isEmpty && incomplete.isEmpty;
}

class PlatformMemberRepairResult {
  const PlatformMemberRepairResult({
    required this.repairedCount,
    required this.alreadyExistedCount,
  });

  final int repairedCount;
  final int alreadyExistedCount;
}

class PlatformMemberCompleteResult {
  const PlatformMemberCompleteResult({required this.completedCount});

  final int completedCount;
}

class PlatformMemberReconciliationService {
  PlatformMemberReconciliationService._();

  static final PlatformMemberReconciliationService instance =
      PlatformMemberReconciliationService._();

  static const GetOptions _server = GetOptions(source: Source.server);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('user_profiles');

  CollectionReference<Map<String, dynamic>> get _shopMembers =>
      _firestore.collection('shop_members');

  void _requireRoot() {
    if (!PlatformRootAdmin.isRoot(_auth.currentUser?.uid)) {
      throw Exception('只有平台最高管理員可以補齊店主平台會員');
    }
  }

  static const List<String> requiredMemberFields = <String>[
    'uid',
    'createdAt',
    'updatedAt',
    'platformStatus',
    'status',
    'displayName',
  ];

  /// 掃描來源是 shops.ownerUid。
  /// users 不存在為「缺少平台會員」；存在但缺必要欄位為「資料不完整」。
  Future<OwnerPlatformMemberScan> findMissingOwnerPlatformMembers() async {
    _requireRoot();
    final QuerySnapshot<Map<String, dynamic>> shops = await _shops.get(_server);
    final Map<String, List<MissingOwnerShop>> shopsByOwner =
        <String, List<MissingOwnerShop>>{};
    final Map<String, Set<String>> memberLookupIds = <String, Set<String>>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> shop in shops.docs) {
      final Map<String, dynamic> data = shop.data();
      final String ownerUid = (data['ownerUid'] ?? '').toString().trim();
      if (ownerUid.isEmpty) continue;

      final String shopName = (data['name'] ?? '').toString().trim().isEmpty
          ? '未命名店家'
          : data['name'].toString().trim();
      shopsByOwner
          .putIfAbsent(ownerUid, () => <MissingOwnerShop>[])
          .add(MissingOwnerShop(shopId: shop.id, shopName: shopName));
      final Set<String> lookupIds = memberLookupIds.putIfAbsent(
        ownerUid,
        () => <String>{},
      );
      lookupIds.add(shop.id);
      final String namedShopId = (data['shopId'] ?? '').toString().trim();
      if (namedShopId.isNotEmpty) lookupIds.add(namedShopId);
    }

    final Map<String, Map<String, dynamic>?> usersById =
        <String, Map<String, dynamic>?>{};
    final Map<String, String> emails = <String, String>{};
    final Map<String, String> displayNames = <String, String>{};

    for (final String ownerUid in shopsByOwner.keys) {
      final DocumentSnapshot<Map<String, dynamic>> userSnap = await _users
          .doc(ownerUid)
          .get(_server);
      if (!userSnap.exists) {
        usersById[ownerUid] = null;
      } else {
        usersById[ownerUid] = userSnap.data() ?? <String, dynamic>{};
      }

      final Map<String, dynamic>? userData = usersById[ownerUid];
      final List<String> gaps = userData == null
          ? const <String>[]
          : missingPlatformMemberFields(userData);
      if (userSnap.exists && gaps.isEmpty) continue;

      final Map<String, dynamic>? profile = await _optionalData(
        _profiles.doc(ownerUid),
      );
      final Map<String, dynamic>? member = await _optionalMember(
        ownerUid: ownerUid,
        shopIds: memberLookupIds[ownerUid] ?? <String>{},
      );
      emails[ownerUid] = _firstNonEmpty(<String>[
        _firstText(userData, const <String>['email']),
        _firstText(profile, const <String>['email']),
        _firstText(member, const <String>['email', 'emailKey']),
      ]);
      displayNames[ownerUid] = _firstNonEmpty(<String>[
        _firstText(userData, const <String>['displayName']),
        _firstText(profile, const <String>['displayName', 'name']),
        _firstText(member, const <String>['displayName', 'name']),
      ]);
    }

    return assembleOwnerPlatformMemberScan(
      shopsByOwnerUid: shopsByOwner,
      usersById: usersById,
      emails: emails,
      displayNames: displayNames,
    );
  }

  @visibleForTesting
  static List<String> missingPlatformMemberFields(Map<String, dynamic> data) {
    final List<String> missing = <String>[];
    for (final String field in requiredMemberFields) {
      if (_isBlankField(data, field)) missing.add(field);
    }
    return missing;
  }

  static bool _isBlankField(Map<String, dynamic> data, String field) {
    if (!data.containsKey(field) || data[field] == null) return true;
    final Object? value = data[field];
    return value is String && value.trim().isEmpty;
  }

  @visibleForTesting
  static OwnerPlatformMemberScan assembleOwnerPlatformMemberScan({
    required Map<String, List<MissingOwnerShop>> shopsByOwnerUid,
    required Map<String, Map<String, dynamic>?> usersById,
    Map<String, String> emails = const <String, String>{},
    Map<String, String> displayNames = const <String, String>{},
  }) {
    final List<String> ownerUids = shopsByOwnerUid.keys.toList()..sort();
    final List<MissingOwnerPlatformMember> missing =
        <MissingOwnerPlatformMember>[];
    final List<MissingOwnerPlatformMember> incomplete =
        <MissingOwnerPlatformMember>[];
    for (final String ownerUid in ownerUids) {
      final String uid = ownerUid.trim();
      if (uid.isEmpty) continue;
      final List<MissingOwnerShop> shops =
          shopsByOwnerUid[ownerUid] ?? const <MissingOwnerShop>[];
      if (shops.isEmpty) continue;
      final bool known = usersById.containsKey(uid);
      final Map<String, dynamic>? userData = known ? usersById[uid] : null;
      final bool documentMissing = !known || userData == null;
      final List<String> gaps = documentMissing
          ? const <String>[]
          : missingPlatformMemberFields(userData);
      if (!documentMissing && gaps.isEmpty) continue;
      final String email = (emails[uid] ?? '').trim();
      final String foundName = (displayNames[uid] ?? '').trim();
      final MissingOwnerPlatformMember item = MissingOwnerPlatformMember(
        ownerUid: uid,
        email: email,
        displayName: foundName.isEmpty ? '店主' : foundName,
        shops: shops,
        documentMissing: documentMissing,
        missingFields: gaps,
      );
      if (documentMissing) {
        missing.add(item);
      } else {
        incomplete.add(item);
      }
    }
    return OwnerPlatformMemberScan(missing: missing, incomplete: incomplete);
  }

  Future<Map<String, dynamic>?> _optionalData(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get(
        _server,
      );
      if (!snap.exists) return null;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _optionalMember({
    required String ownerUid,
    required Set<String> shopIds,
  }) async {
    Map<String, dynamic>? fallback;
    Map<String, dynamic>? ownerRole;
    void consider(Map<String, dynamic>? data) {
      if (data == null) return;
      fallback ??= data;
      if ((data['role'] ?? '').toString() == ShopRoles.owner) {
        ownerRole = data;
      }
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> byUid = await _shopMembers
          .where('uid', isEqualTo: ownerUid)
          .get(_server);
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in byUid.docs) {
        consider(doc.data());
      }
    } catch (_) {}

    for (final String shopId in shopIds) {
      consider(await _optionalData(_shopMembers.doc('${shopId}_$ownerUid')));
    }
    return ownerRole ?? fallback;
  }

  String _firstText(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return '';
    for (final String key in keys) {
      final String value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// 只在 users/{ownerUid} 不存在時建立。已存在的文件完全不寫。
  Future<PlatformMemberRepairResult> repairMissingOwnerPlatformMembers(
    List<MissingOwnerPlatformMember> selected,
  ) async {
    _requireRoot();
    final User operator = _auth.currentUser!;
    final Map<String, MissingOwnerPlatformMember> unique =
        <String, MissingOwnerPlatformMember>{};
    for (final MissingOwnerPlatformMember item in selected) {
      final String ownerUid = item.ownerUid.trim();
      if (ownerUid.isEmpty) continue;
      unique.putIfAbsent(ownerUid, () => item);
    }

    int repairedCount = 0;
    int alreadyExistedCount = 0;
    for (final MissingOwnerPlatformMember item in unique.values) {
      final bool created = await _createUserIfMissing(item);
      if (!created) {
        alreadyExistedCount += 1;
        continue;
      }
      repairedCount += 1;
      for (final MissingOwnerShop shop in item.shops) {
        try {
          await ActionLogService.instance.logAction(
            shopId: shop.shopId,
            targetType: 'user',
            targetId: item.ownerUid,
            action: 'repair_missing_platform_member',
            operatorUid: operator.uid,
            operatorRole: 'root',
            payload: <String, dynamic>{
              'shopId': shop.shopId,
              'ownerUid': item.ownerUid,
              'email': item.email.trim(),
            },
          );
        } catch (_) {}
      }
    }

    return PlatformMemberRepairResult(
      repairedCount: repairedCount,
      alreadyExistedCount: alreadyExistedCount,
    );
  }

  /// 只補既有 users 文件裡缺少的欄位，不覆蓋已有內容。
  Future<PlatformMemberCompleteResult> completeIncompleteOwnerPlatformMembers(
    List<MissingOwnerPlatformMember> selected,
  ) async {
    _requireRoot();
    final User operator = _auth.currentUser!;
    final Map<String, MissingOwnerPlatformMember> unique =
        <String, MissingOwnerPlatformMember>{};
    for (final MissingOwnerPlatformMember item in selected) {
      final String ownerUid = item.ownerUid.trim();
      if (ownerUid.isEmpty || item.documentMissing) continue;
      unique.putIfAbsent(ownerUid, () => item);
    }

    int completedCount = 0;
    for (final MissingOwnerPlatformMember item in unique.values) {
      final List<String> filled = await _fillMissingUserFields(item);
      if (filled.isEmpty) continue;
      completedCount += 1;
      for (final MissingOwnerShop shop in item.shops) {
        try {
          await ActionLogService.instance.logAction(
            shopId: shop.shopId,
            targetType: 'user',
            targetId: item.ownerUid,
            action: 'repair_incomplete_platform_member',
            operatorUid: operator.uid,
            operatorRole: 'root',
            payload: <String, dynamic>{
              'shopId': shop.shopId,
              'ownerUid': item.ownerUid,
              'email': item.email.trim(),
              'fields': filled,
            },
          );
        } catch (_) {}
      }
    }
    return PlatformMemberCompleteResult(completedCount: completedCount);
  }

  Future<List<String>> _fillMissingUserFields(
    MissingOwnerPlatformMember item,
  ) async {
    final String ownerUid = item.ownerUid.trim();
    final DocumentReference<Map<String, dynamic>> userRef = _users.doc(
      ownerUid,
    );
    final DocumentReference<Map<String, dynamic>> profileRef = _profiles.doc(
      ownerUid,
    );
    final Map<String, dynamic>? member = await _optionalMember(
      ownerUid: ownerUid,
      shopIds: item.shops.map((MissingOwnerShop shop) => shop.shopId).toSet(),
    );

    return _firestore.runTransaction<List<String>>((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(userRef);
      if (!snap.exists) return <String>[];
      final DocumentSnapshot<Map<String, dynamic>> profileSnap = await tx.get(
        profileRef,
      );
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      final Map<String, dynamic>? profile = profileSnap.data();
      final List<String> gaps = missingPlatformMemberFields(data);
      final Map<String, dynamic> patch = <String, dynamic>{};
      if (gaps.contains('uid')) patch['uid'] = ownerUid;
      if (gaps.contains('createdAt')) {
        patch['createdAt'] = FieldValue.serverTimestamp();
      }
      if (gaps.contains('updatedAt')) {
        patch['updatedAt'] = FieldValue.serverTimestamp();
      }
      if (gaps.contains('platformStatus')) patch['platformStatus'] = 'active';
      if (gaps.contains('status')) patch['status'] = 'active';
      if (gaps.contains('displayName')) {
        patch['displayName'] = _firstNonEmpty(<String>[
          _firstText(profile, const <String>['displayName', 'name']),
          _firstText(member, const <String>['displayName', 'name']),
          '店主',
        ]);
      }
      if (_isBlankField(data, 'email')) {
        final String email = _firstNonEmpty(<String>[
          _firstText(profile, const <String>['email']),
          _firstText(member, const <String>['email', 'emailKey']),
        ]);
        final bool absent = !data.containsKey('email') || data['email'] == null;
        if (absent || email.isNotEmpty) {
          patch['email'] = email;
        }
      }
      if (patch.isEmpty) return <String>[];
      tx.update(userRef, patch);
      return patch.keys.toList();
    });
  }

  Future<bool> _createUserIfMissing(MissingOwnerPlatformMember item) async {
    final String ownerUid = item.ownerUid.trim();
    final DocumentReference<Map<String, dynamic>> userRef = _users.doc(
      ownerUid,
    );
    final Map<String, dynamic>? profile = await _optionalData(
      _profiles.doc(ownerUid),
    );
    final Map<String, dynamic>? member = await _optionalMember(
      ownerUid: ownerUid,
      shopIds: item.shops.map((MissingOwnerShop shop) => shop.shopId).toSet(),
    );
    final String email = _firstNonEmpty(<String>[
      _firstText(profile, const <String>['email']),
      _firstText(member, const <String>['email', 'emailKey']),
      item.email,
    ]);
    final String displayName = _firstNonEmpty(<String>[
      _firstText(profile, const <String>['displayName', 'name']),
      _firstText(member, const <String>['displayName', 'name']),
      item.displayName,
      '店主',
    ]);

    return _firestore.runTransaction<bool>((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(userRef);
      if (snap.exists) return false;
      tx.set(userRef, <String, dynamic>{
        'uid': ownerUid,
        'email': email,
        'displayName': displayName,
        'role': 'user',
        'status': 'active',
        'platformStatus': 'active',
        'platformNote': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': null,
        'repairedFromShopOwner': true,
        'repairedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  String _firstNonEmpty(List<String> values) {
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}
