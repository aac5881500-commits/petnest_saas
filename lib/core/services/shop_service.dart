// 檔案名稱：lib/core/services/shop_service.dart
// 說明：店家服務層（含營業資訊 / Logo / 封面 / 預約設定）


import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';


class ShopService {
  ShopService._();
  static final instance = ShopService._();

Future<void> deleteImageByUrl(String url) async {
  try {
    final ref = FirebaseStorage.instance.refFromURL(url);
    await ref.delete();
  } catch (e) {
    print('刪除圖片失敗: $e');
  }
}

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  CollectionReference<Map<String, dynamic>> get _shopMembers =>
      _firestore.collection('shop_members');

  List<String> normalizeEnabledModules(dynamic value) {
    if (value is! List) {
      return [...ShopModules.defaultEnabled];
    }

    final result = value
        .map((e) => e.toString())
        .where((e) => ShopModules.all.contains(e))
        .toSet()
        .toList();

    if (result.isEmpty) {
      return [...ShopModules.defaultEnabled];
    }

    return result;
  }

  Future<void> updateEnabledModules({
    required String shopId,
    required List<String> enabledModules,
  }) async {
    final normalized = enabledModules
        .map((e) => e.trim())
        .where((e) => ShopModules.all.contains(e))
        .toSet()
        .toList();

    await _shops.doc(shopId).update({
      'enabledModules':
          normalized.isEmpty ? ShopModules.defaultEnabled : normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

/// 🔥 更新店家資料（新增給後台用）
Future<void> updateShop({
  required String shopId,
  required Map<String, dynamic> data,
}) async {
  await _firestore.collection('shops').doc(shopId).update(data);
}

  /// 建立店家
  Future<String> createShop({
    required String name,
  }) async {
    final user = _currentUser;

    if (user == null) throw Exception('未登入');

    final existing = await _shopMembers
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('你已經建立過店家了');
    }

    final shopRef = _shops.doc();
    final memberRef = _shopMembers.doc('${shopRef.id}_${user.uid}');

    final batch = _firestore.batch();

    batch.set(shopRef, {
      'name': name.trim(),
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      // 基本資料
      'businessType': 'cat',
      'phone': '',
      'address': '',
      'description': '',
      'city': '',
      'district': '',
      'lineUrl': '',

      // 營業資訊
      'isOpen': true,
      'businessHours': '',
      'closedDays': <String>[],
      'serviceTypes': <String>['overnight'],
      'isPublic': false,

      // 圖片
      'logoUrl': '',
      'coverUrl': '',

      // 模組開關（後台分頁用）
      'enabledModules': ShopModules.defaultEnabled,

      // ========= 預約設定 =========
      'bookingEnabled': true,
      'totalRooms': 1,

      // 本次新增：房況欄位
      'cleaningRooms': 0,
      'maintenanceRooms': 0,

      'maxAdvanceBookingDays': 30,
      'defaultPricePerNight': 0,
      'blockedDates': <String>[],
      'specialPrices': <String, dynamic>{},
    });

    batch.set(memberRef, {
      'shopId': shopRef.id,
      'uid': user.uid,
      'email': user.email ?? '',
      'emailKey': normalizeEmail(user.email ?? ''),

      // 權限預留：owner / manager / staff
      'role': ShopRoles.owner,
      'permissions': ownerDefaultPermissions(),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return shopRef.id;
  }

  /// 取得我的店家
  Future<List<Map<String, dynamic>>> getMyShops() async {
    final user = _currentUser;
    if (user == null) throw Exception('未登入');

    final memberSnapshot =
        await _shopMembers.where('uid', isEqualTo: user.uid).get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in memberSnapshot.docs) {
      final data = doc.data();
      final shopId = data['shopId'];

      final shopDoc = await _shops.doc(shopId).get();
      if (!shopDoc.exists) continue;

      result.add({
        'shopId': shopId,
        'name': shopDoc.data()?['name'] ?? '',
        'role': data['role'] ?? '',
      });
    }

    return result;
  }

  /// 取得單一店家
  Future<Map<String, dynamic>?> getShop(String shopId) async {
    final doc = await _shops.doc(shopId).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};

    return {
      'shopId': doc.id,
      ...data,
    };
  }

  /// 監聽單一店家
  Stream<Map<String, dynamic>?> streamShop(String shopId) {
    return _shops.doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {
        'shopId': doc.id,
        ...doc.data()!,
      };
    });
  }

  /// 取得某使用者在該店的角色
  Future<String?> getUserRoleInShop({
    required String shopId,
    required String uid,
  }) async {
    final snapshot = await _shopMembers
        .where('shopId', isEqualTo: shopId)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return data['role']?.toString();
  }

  /// 是否有管理店家權限
  bool canManageShop(String? role) {
    return role == ShopRoles.owner || role == ShopRoles.manager;
  }

  /// 更新店家基本資料
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
})async {
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

  /// 🔥 新增
  'businessHours': businessHours.trim(),
  'licenseNumber': licenseNumber.trim(),
  'taxId': taxId.trim(),
  'showTaxId': showTaxId,

  'updatedAt': FieldValue.serverTimestamp(),
});
  }

  /// 更新營業資訊
  Future<void> updateBusinessInfo({
    required String shopId,
    required bool isOpen,
    String businessHours = '',
    List<String> closedDays = const [],
    List<String> serviceTypes = const [],
    bool isPublic = false,
  }) async {
    await _shops.doc(shopId).update({
      'isOpen': isOpen,
      'businessHours': businessHours,
      'closedDays': closedDays,
      'serviceTypes': serviceTypes,
      'isPublic': isPublic,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 更新預約基本設定
  Future<void> updateBookingSettings({
    required String shopId,
    bool? bookingEnabled,
    int? totalRooms,
    int? cleaningRooms,
    int? maintenanceRooms,
    int? maxAdvanceBookingDays,
    int? defaultPricePerNight,
  }) async {
    final Map<String, dynamic> data = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (bookingEnabled != null) data['bookingEnabled'] = bookingEnabled;
    if (totalRooms != null) data['totalRooms'] = totalRooms;
    if (cleaningRooms != null) data['cleaningRooms'] = cleaningRooms;
    if (maintenanceRooms != null) {
      data['maintenanceRooms'] = maintenanceRooms;
    }
    if (maxAdvanceBookingDays != null) {
      data['maxAdvanceBookingDays'] = maxAdvanceBookingDays;
    }
    if (defaultPricePerNight != null) {
      data['defaultPricePerNight'] = defaultPricePerNight;
    }

    await _shops.doc(shopId).update(data);
  }

  /// 覆蓋整份 blockedDates
  Future<void> updateBlockedDates({
    required String shopId,
    required List<String> blockedDates,
  }) async {
    final normalized = blockedDates
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    await _shops.doc(shopId).update({
      'blockedDates': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 新增單一天關閉日期
  Future<void> addBlockedDate({
    required String shopId,
    required String dateKey,
  }) async {
    await _shops.doc(shopId).update({
      'blockedDates': FieldValue.arrayUnion([dateKey]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 移除單一天關閉日期
  Future<void> removeBlockedDate({
    required String shopId,
    required String dateKey,
  }) async {
    await _shops.doc(shopId).update({
      'blockedDates': FieldValue.arrayRemove([dateKey]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 設定某一天特別價格
  Future<void> setSpecialPrice({
    required String shopId,
    required String dateKey,
    required int price,
  }) async {
    await _shops.doc(shopId).update({
      'specialPrices.$dateKey': price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 移除某一天特別價格
  Future<void> removeSpecialPrice({
    required String shopId,
    required String dateKey,
  }) async {
    await _shops.doc(shopId).update({
      'specialPrices.$dateKey': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 取得某天實際價格
  int getPriceForDate(Map<String, dynamic> shop, DateTime date) {
    final String dateKey = formatDateKey(date);

    final Map<String, dynamic> specialPrices =
        Map<String, dynamic>.from(shop['specialPrices'] ?? {});

    if (specialPrices.containsKey(dateKey)) {
      return _toInt(specialPrices[dateKey]);
    }

    return _toInt(shop['defaultPricePerNight']);
  }

  /// 判斷某天是否被關閉
  bool isBlockedDate(Map<String, dynamic> shop, DateTime date) {
    final String dateKey = formatDateKey(date);

    final List<dynamic> rawBlockedDates = shop['blockedDates'] ?? [];
    final blockedDates = rawBlockedDates.map((e) => e.toString()).toSet();

    return blockedDates.contains(dateKey);
  }

  /// 計算基礎可用房數（還沒扣 booking 佔用）
  ///
  /// totalRooms - cleaningRooms - maintenanceRooms
  int getBaseCapacity(Map<String, dynamic> shop) {
    final totalRooms = _toInt(shop['totalRooms'], fallback: 0);
    final cleaningRooms = _toInt(shop['cleaningRooms'], fallback: 0);
    final maintenanceRooms = _toInt(shop['maintenanceRooms'], fallback: 0);

    final result = totalRooms - cleaningRooms - maintenanceRooms;
    return result < 0 ? 0 : result;
  }

  /// 日期轉成 yyyy-MM-dd
  String formatDateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 上傳店家 Logo
  Future<String> uploadShopLogo({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('shops/$shopId/logo.jpg');
    await ref.putData(bytes);
    final url = await ref.getDownloadURL();

    await _shops.doc(shopId).update({
      'logoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return url;
  }

  /// 上傳店家 Cover
  Future<String> uploadShopCover({
  required String shopId,
  required Uint8List bytes,
}) async {
  /// 🔥 每次用新檔名（避免快取＆壞檔）
  final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

  final ref = _storage.ref().child('shops/$shopId/$fileName');

  /// 🔥 強制指定圖片格式（關鍵）
  await ref.putData(
    bytes,
    SettableMetadata(
      contentType: 'image/jpeg',
    ),
  );

  return await ref.getDownloadURL();
}

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
    // ===============================
  // 🔐 權限系統（會員 / 邀請 / 權限）
  // ===============================

  CollectionReference<Map<String, dynamic>> get _shopMemberInvites =>
      _firestore.collection('shop_member_invites');

  String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  Map<String, bool> ownerDefaultPermissions() {
    return {
      for (final key in ShopPermissionKeys.all) key: true,
    };
  }

  Map<String, bool> managerDefaultPermissions() {
    return {
      ShopPermissionKeys.manageMembers: false,
      ShopPermissionKeys.editBasicInfo: true,
      ShopPermissionKeys.editBusinessInfo: true,
      ShopPermissionKeys.editMedia: true,
      ShopPermissionKeys.manageBookings: true,
      ShopPermissionKeys.viewReports: true,
      ShopPermissionKeys.viewActionLogs: true,
    };
  }

  Map<String, bool> staffDefaultPermissions() {
    return {
      ShopPermissionKeys.manageMembers: false,
      ShopPermissionKeys.editBasicInfo: false,
      ShopPermissionKeys.editBusinessInfo: false,
      ShopPermissionKeys.editMedia: false,
      ShopPermissionKeys.manageBookings: true,
      ShopPermissionKeys.viewReports: false,
      ShopPermissionKeys.viewActionLogs: false,
    };
  }

  Map<String, bool> defaultPermissionsByRole(String role) {
    switch (role) {
      case ShopRoles.manager:
        return managerDefaultPermissions();
      case ShopRoles.staff:
        return staffDefaultPermissions();
      case ShopRoles.owner:
      default:
        return ownerDefaultPermissions();
    }
  }

  Map<String, bool> normalizePermissions(dynamic value, {String? role}) {
    final base = defaultPermissionsByRole(role ?? ShopRoles.staff);

    if (value is! Map) {
      return base;
    }

    final result = <String, bool>{...base};

    for (final key in ShopPermissionKeys.all) {
      final raw = value[key];
      if (raw is bool) {
        result[key] = raw;
      }
    }

    return result;
  }

  bool hasPermission(
    Map<String, dynamic>? memberData,
    String permissionKey,
  ) {
    if (memberData == null) return false;

    final role = memberData['role']?.toString();

    if (role == ShopRoles.owner) return true;

    final permissions = normalizePermissions(
      memberData['permissions'],
      role: role,
    );

    return permissions[permissionKey] == true;
  }

  // ===== 成員 =====

  Stream<List<Map<String, dynamic>>> streamShopMembers(String shopId) {
    return _shopMembers.where('shopId', isEqualTo: shopId).snapshots().map(
      (snapshot) {
        final result = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        result.sort((a, b) {
          final aRole = a['role']?.toString() ?? '';
          final bRole = b['role']?.toString() ?? '';
          return aRole.compareTo(bRole);
        });

        return result;
      },
    );
  }

  // ===== 邀請 =====

  Stream<List<Map<String, dynamic>>> streamShopMemberInvites(String shopId) {
    return _shopMemberInvites
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      },
    );
  }

  Future<void> upsertMemberPermissionByEmail({
    required String shopId,
    required String email,
    required String role,
    required Map<String, bool> permissions,
    required String operatorUid,
    required String operatorRole,
  }) async {
    final normalizedEmail = normalizeEmail(email);

    if (normalizedEmail.isEmpty) {
      throw Exception('Email 不可為空');
    }

    final existingMembers =
        await _shopMembers.where('shopId', isEqualTo: shopId).get();

    for (final doc in existingMembers.docs) {
      final data = doc.data();
      if (data['emailKey'] == normalizedEmail) {
        await _shopMembers.doc(doc.id).update({
          'role': role,
          'permissions': normalizePermissions(
            permissions,
            role: role,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await ActionLogService.instance.logAction(
          shopId: shopId,
          targetType: 'shop_member',
          targetId: doc.id,
          action: 'update_member_permission',
          operatorUid: operatorUid,
          operatorRole: operatorRole,
        );

        return;
      }
    }

    final inviteDocId = '${shopId}_$normalizedEmail';

    await _shopMemberInvites.doc(inviteDocId).set({
      'shopId': shopId,
      'email': normalizedEmail,
      'emailKey': normalizedEmail,
      'role': role,
      'permissions': normalizePermissions(
        permissions,
        role: role,
      ),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'shop_member_invite',
      targetId: inviteDocId,
      action: 'create_invite',
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }
  Future<void> removeMemberInvite({
  required String inviteDocId,
  required String shopId,
  required String operatorUid,
  required String operatorRole,
}) async {
  await _shopMemberInvites.doc(inviteDocId).delete();

  await ActionLogService.instance.logAction(
    shopId: shopId,
    targetType: 'shop_member_invite',
    targetId: inviteDocId,
    action: 'delete_member_invite',
    operatorUid: operatorUid,
    operatorRole: operatorRole,
  );
}

  Future<void> syncPendingInvitesForCurrentUser() async {
    final user = _currentUser;
    if (user == null) return;

    final email = normalizeEmail(user.email ?? '');

    final invites = await _shopMemberInvites
        .where('emailKey', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final inviteDoc in invites.docs) {
      final invite = inviteDoc.data();
      final shopId = invite['shopId'];

      final memberDocId = '${shopId}_${user.uid}';

      await _shopMembers.doc(memberDocId).set({
        'shopId': shopId,
        'uid': user.uid,
        'email': email,
        'emailKey': email,
        'role': invite['role'],
        'permissions': normalizePermissions(
          invite['permissions'],
          role: invite['role'],
        ),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await inviteDoc.reference.update({
        'status': 'accepted',
      });

      await ActionLogService.instance.logAction(
        shopId: shopId,
        targetType: 'shop_member',
        targetId: memberDocId,
        action: 'invite_accepted',
        operatorUid: user.uid,
        operatorRole: invite['role'],
      );
    }
  }
    // ===============================
  // 🐱 房型（RoomType）
  // ===============================

  CollectionReference<Map<String, dynamic>> roomTypesRef(String shopId) {
    return _shops.doc(shopId).collection('room_types');
  }

  /// 取得房型列表（監聽）
  Stream<List<Map<String, dynamic>>> streamRoomTypes(String shopId) {
    return roomTypesRef(shopId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
  return {
    ...doc.data(),
    'id': doc.id, // 👈 放最後（關鍵🔥）
  };
}).toList();
    });
  }

  /// 新增房型
  Future<void> createRoomType({
  required String shopId,
  required String name,
  required int capacity,
  required int price,
  required int totalRooms,
  required String description,

  /// 🔥 新增
  required int extraPrice,
  required int width,
  required int depth,
  required int height,

  Map<String, dynamic>? extraData,
}) async {
  final doc = roomTypesRef(shopId).doc();

  await doc.set({
    'name': name,
    'capacity': capacity,
    'price': price,
    'totalRooms': totalRooms,
    'description': description,

    /// 🔥 重點欄位
    'extraPrice': extraPrice,
    'width': width,
    'depth': depth,
    'height': height,

    'images': [],
    'isSingle': false,

    ...?extraData,

    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

  /// 更新房型
  Future<void> updateRoomType({
    required String shopId,
    required String roomTypeId,
    required String name,
    required int capacity,
    required int price,
    required bool isSingle,
  }) async {
    await roomTypesRef(shopId).doc(roomTypeId).update({
      'name': name,
      'capacity': capacity,
      'price': price,
      'isSingle': isSingle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 刪除房型
  Future<void> deleteRoomType({
    required String shopId,
    required String roomTypeId,
  }) async {
    await roomTypesRef(shopId).doc(roomTypeId).delete();
  }

  /// 上傳房型圖片
Future<String> uploadRoomTypeImage({
  required String shopId,
  required String roomTypeId,
  required Uint8List bytes,
}) async {
  final fileName =
      'room_${DateTime.now().millisecondsSinceEpoch}.jpg';

  final ref = _storage
      .ref()
      .child('shops/$shopId/room_types/$roomTypeId/$fileName');

  await ref.putData(
    bytes,
    SettableMetadata(contentType: 'image/jpeg'),
  );

  final url = await ref.getDownloadURL();

  /// 🔥 存進 Firestore（array）
  await roomTypesRef(shopId).doc(roomTypeId).update({
    'images': FieldValue.arrayUnion([url]),
  });

  return url;
}

/// 🔥 刪除房型圖片（Firestore + Storage）
Future<void> deleteRoomTypeImage({
  required String shopId,
  required String roomTypeId,
  required String imageUrl,
}) async {
  try {
    /// 🔥 刪 Storage
    final ref = FirebaseStorage.instance.refFromURL(imageUrl);
    await ref.delete();

    /// 🔥 刪 Firestore
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('room_types')
        .doc(roomTypeId)
        .update({
      'images': FieldValue.arrayRemove([imageUrl]),
    });
  } catch (e) {
    print('刪除圖片錯誤: $e');
  }
}

  // ===============================
// 🏠 房間（Room）
// ===============================

CollectionReference<Map<String, dynamic>> roomsRef(String shopId) {
  return _shops.doc(shopId).collection('rooms');
}

/// 監聽房間列表
Stream<List<Map<String, dynamic>>> streamRooms(String shopId) {
  return roomsRef(shopId).snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  });
}

/// 🔥 取得所有房型（一次性）
Future<List<Map<String, dynamic>>> getRoomTypes(String shopId) async {
  final snapshot = await roomTypesRef(shopId).get();

  return snapshot.docs.map((doc) {
    return {
      'id': doc.id,
      ...doc.data(),
    };
  }).toList();
}

/// 🔥 設定房間關閉日期
Future<void> updateRoomBlockedDates({
  required String shopId,
  required String roomId,
  required List<String> blockedDates,
}) async {
  await roomsRef(shopId).doc(roomId).update({
    'blockedDates': blockedDates,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// 🔥 取得所有房間（一次性）
Future<List<Map<String, dynamic>>> getRooms(String shopId) async {
  final snapshot = await roomsRef(shopId).get();

  return snapshot.docs.map((doc) {
    return {
      'id': doc.id,
      ...doc.data(),
    };
  }).toList();
}

/// 新增房間
Future<void> createRoom({
  required String shopId,
  required String name,
  required String roomTypeId,
}) async {
  await roomsRef(shopId).add({
    'name': name,
    'roomTypeId': roomTypeId,
    'enabled': true,
    'cameraIds': [], 
    'blockedDates': [],
    'cameraIds': [],
'blockedDates': [],
'priceRules': [], 
'discountRules': [], 
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// 更新房間（開關）
Future<void> updateRoomStatus({
  required String shopId,
  required String roomId,
  required bool enabled,
}) async {
  await roomsRef(shopId).doc(roomId).update({
    'enabled': enabled,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// 🔥 刪除房間
Future<void> deleteRoom({
  required String shopId,
  required String roomId,
}) async {
  await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('rooms')
      .doc(roomId)
      .delete();
}

Future<void> updateRoomPriceRules({
  required String shopId,
  required String roomId,
  required List<Map<String, dynamic>> rules,
}) async {
  await roomsRef(shopId).doc(roomId).update({
    'priceRules': rules,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updateRoomDiscountRules({
  required String shopId,
  required String roomId,
  required List<Map<String, dynamic>> rules,
}) async {
  await roomsRef(shopId).doc(roomId).update({
    'discountRules': rules,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

// ===============================
// 📅 房間日曆（Room Calendar）
// ===============================

CollectionReference<Map<String, dynamic>> roomCalendarRef(String shopId) {
  return _shops.doc(shopId).collection('room_calendar');
}

/// 監聽某一天所有房間狀態
Stream<List<Map<String, dynamic>>> streamRoomCalendarByDate(
  String shopId,
  String date,
) {
  return roomCalendarRef(shopId)
      .where('date', isEqualTo: date)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  });
}

/// 設定房間某天狀態
Future<void> setRoomStatus({
  required String shopId,
  required String roomId,
  required String date, // yyyy-MM-dd
  required String status, // available / blocked / cleaning
}) async {
  final docId = '${roomId}_$date';

  await roomCalendarRef(shopId).doc(docId).set({
    'roomId': roomId,
    'date': date,
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// ===============================
/// 🧮 取得可用房型（前台用）
/// ===============================
Future<List<Map<String, dynamic>>> getAvailableRoomTypes({
  required String shopId,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  // 1️⃣ 取得所有房型
  final roomTypesSnapshot = await roomTypesRef(shopId).get();
  final roomTypes = roomTypesSnapshot.docs;

  // 2️⃣ 取得所有房間
  final roomsSnapshot = await roomsRef(shopId).get();
  final rooms = roomsSnapshot.docs;

  // 3️⃣ 先建立 roomType -> rooms mapping
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> roomMap = {};

  for (final room in rooms) {
    final data = room.data();

    if (data['enabled'] != true) continue;

    final typeId = data['roomTypeId'];
    if (typeId == null) continue;

    roomMap.putIfAbsent(typeId, () => []);
    roomMap[typeId]!.add(room);
  }

  // 4️⃣ 計算日期區間
  final stayDates = <String>[];
  DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);

  while (cursor.isBefore(endDate)) {
    stayDates.add(formatDateKey(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }

  final result = <Map<String, dynamic>>[];

  // 5️⃣ 每個房型檢查是否可用
  for (final typeDoc in roomTypes) {
    final type = typeDoc.data();
    final typeId = typeDoc.id;

    final typeRooms = roomMap[typeId] ?? [];

    if (typeRooms.isEmpty) continue;

    int minAvailableRooms = 999999;

    for (final date in stayDates) {
      int availableCount = 0;

      // 取得當天日曆
      final calendarSnapshot = await roomCalendarRef(shopId)
          .where('date', isEqualTo: date)
          .get();

      final calendarMap = {
        for (var doc in calendarSnapshot.docs)
          doc['roomId']: doc.data(),
      };

      for (final room in typeRooms) {
        final roomId = room.id;
        final cal = calendarMap[roomId];
        final status = cal?['status'] ?? 'available';
        /// 🔥 房間自己的 blockedDates
final roomData = room.data();
final List blocked = roomData['blockedDates'] ?? [];

if (blocked.contains(date)) {
  continue;
}

        if (status == 'available') {
          availableCount++;
        }
      }

      if (availableCount < minAvailableRooms) {
        minAvailableRooms = availableCount;
      }
    }

    if (minAvailableRooms > 0) {
      result.add({
  'roomTypeId': typeId,
  'name': type['name'],
  'price': type['price'],
  'capacity': type['capacity'],
  'availableRooms': minAvailableRooms,
  'images': type['images'] ?? [],
  'description': type['description'] ?? '',
  'features': type['features'] ?? [],

  /// 🔥 這幾個一定要補
  'extraPrice': type['extraPrice'] ?? 0,
  'width': type['width'] ?? 0,
  'depth': type['depth'] ?? 0,
  'height': type['height'] ?? 0,
});
    }
  }

  return result;
}
// ===============================
// 📜 入住條款（版本控管）
// ===============================

/// 取得入住條款
Future<Map<String, dynamic>?> getCheckinPolicy(String shopId) async {
  final doc = await _firestore
      .collection('shops')
      .doc(shopId)
      .collection('policies')
      .doc('checkin_policy')
      .get();

  if (!doc.exists) return null;

  return doc.data();
}

/// 更新入住條款（自動版本 +1）
Future<void> updateCheckinPolicy({
  required String shopId,
  required Map<String, dynamic> sections,
  required Map<String, bool> enabled,

  /// 🔵 第一頁
  required List<String> customPoliciesPage1,

  /// 🔴 第二頁
  required List<String> customPoliciesPage2,
})async {
  final docRef = _firestore
      .collection('shops')
      .doc(shopId)
      .collection('policies')
      .doc('checkin_policy');

  final doc = await docRef.get();

  int newVersion = 1;

  if (doc.exists) {
    final oldVersion = doc.data()?['version'] ?? 1;
    newVersion = oldVersion + 1;
  }

  await docRef.set({
  'version': newVersion,

  /// 🔥 模板欄位（可開關）
  'sections': sections,

  /// 🔥 每個欄位是否啟用
  'enabled': enabled,

  /// 🔥 額外條款（自由新增）
  'customPoliciesPage1': customPoliciesPage1,
'customPoliciesPage2': customPoliciesPage2,

  'updatedAt': FieldValue.serverTimestamp(),
});
}
// ===============================
// 📜 條款確認（會員）
// ===============================

/// 取得會員是否已確認條款
Future<bool> hasAcceptedPolicy({
  required String shopId,
  required String userId,
}) async {
  final policy = await getCheckinPolicy(shopId);
  if (policy == null) return true; // 沒條款直接通過

  final currentVersion = policy['version'] ?? 1;

  final doc = await _firestore
      .collection('users')
      .doc(userId)
      .collection('policy_acceptances')
      .doc(shopId)
      .get();

  if (!doc.exists) return false;

  final acceptedVersion = doc.data()?['acceptedVersion'] ?? 0;

  return acceptedVersion == currentVersion;
}

/// 記錄會員已確認條款
Future<void> acceptPolicy({
  required String shopId,
  required String userId,
}) async {
  final policy = await getCheckinPolicy(shopId);
  if (policy == null) return;

  final version = policy['version'] ?? 1;

  await _firestore
      .collection('users')
      .doc(userId)
      .collection('policy_acceptances')
      .doc(shopId)
      .set({
    'acceptedVersion': version,
    'acceptedAt': FieldValue.serverTimestamp(),
    'email': _currentUser?.email ?? '',
  });
}
/// 📊 取得條款同意紀錄（店家用）
Future<List<Map<String, dynamic>>> getPolicyAcceptances(
    String shopId) async {

  final usersSnapshot = await _firestore.collection('users').get();

  final result = <Map<String, dynamic>>[];

  for (final userDoc in usersSnapshot.docs) {
    final userId = userDoc.id;

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('policy_acceptances')
        .doc(shopId)
        .get();

    if (!doc.exists) continue;

    result.add({
      'userId': userId,
      ...doc.data()!,
    });
  }

  return result;
}
/// 👤 取得會員資料（給條款紀錄用）
Future<Map<String, dynamic>?> getUserProfile(String userId) async {
  final doc = await _firestore.collection('user_profiles').doc(userId).get();

  if (!doc.exists) return null;

  return doc.data();
}

/// 🔥 計算房間總價格（貼在這裡）
int calculateRoomPrice({
  required Map<String, dynamic> room,
  required int basePrice,
  required DateTime startDate,
  required DateTime endDate,
}) {
  int total = 0;

  final List priceRules = room['priceRules'] ?? [];
  final List discountRules = room['discountRules'] ?? [];

  DateTime cursor = startDate;
  int days = 0;

  while (cursor.isBefore(endDate)) {
    int price = basePrice;

    final dateKey = formatDateKey(cursor);

    /// 🔥 套用加價
    for (final rule in priceRules) {
  if (dateKey.compareTo(rule['start']) >= 0 &&
      dateKey.compareTo(rule['end']) <= 0) {

    final extra = rule['extra'];

    if (extra is num) {
      price += extra.toInt();
    }

  }
}
    total += price;

    days++;
    cursor = cursor.add(const Duration(days: 1));
  }

  /// 🔥 折扣
  double discount = 1.0;

  for (final rule in discountRules) {
    if (days >= (rule['minDays'] ?? 0)) {
      discount = rule['discount'] ?? 1.0;
    }
  }

  return (total * discount).toInt();
}
/// 🔥 判斷是否為員工（含 owner / manager / staff）
Future<bool> isEmployee({
  required String shopId,
  required String userId,
}) async {
  if (userId.isEmpty) return false;

  final snapshot = await _shopMembers
      .where('shopId', isEqualTo: shopId)
      .where('uid', isEqualTo: userId)
      .limit(1)
      .get();

  return snapshot.docs.isNotEmpty;
}
}


