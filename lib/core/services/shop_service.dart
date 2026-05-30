// 檔案名稱：lib/core/services/shop_service.dart
// 說明：店家服務層（含營業資訊 / Logo / 封面 / 預約設定）

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/services/platform_activation_code_service.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';

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
      'enabledModules': normalized.isEmpty
          ? ShopModules.defaultEnabled
          : normalized,
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

  /// ===============================
  /// 🏪 產生下一個店家編號
  /// ===============================
  /// 格式：SHOP0001、SHOP0002
  Future<String> _generateNextShopCode() async {
    final counterRef = _firestore.collection('platform_counters').doc('shops');

    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      final current = snapshot.exists
          ? (snapshot.data()?['current'] ?? 0) as int
          : 0;

      final next = current + 1;

      transaction.set(counterRef, {
        'current': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return 'SHOP${next.toString().padLeft(4, '0')}';
    });
  }

  /// 建立店家
  Future<String> createShop({
    required String name,
    required String city,
    required String district,
    required int acceptedShopOwnerPolicyVersion,
    required String activationCode,
    String businessType = 'cat_hotel',
  }) async {
    final user = _currentUser;

    if (user == null) throw Exception('未登入');

    final existing = await _shopMembers
        .where('uid', isEqualTo: user.uid)
        .where('role', isEqualTo: 'owner')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('你已經建立過店家了');
    }
    final activationError = await PlatformActivationCodeService.instance
        .validateCode(activationCode);

    if (activationError != null) {
      throw Exception(activationError);
    }

    final activationCodeData = await PlatformActivationCodeService.instance
        .getCode(activationCode);

    if (activationCodeData == null) {
      throw Exception('找不到此激活碼');
    }

    final shopCode = await _generateNextShopCode();

    final shopRef = _shops.doc(shopCode);
    final memberRef = _shopMembers.doc('${shopCode}_${user.uid}');

    final activationCodeId = activationCodeData['id'].toString();

    final activationPlan = activationCodeData['plan']?.toString() ?? 'basic';

    final activationFreeDays = activationCodeData['freeDays'] is int
        ? activationCodeData['freeDays'] as int
        : 30;

    final paidUntil = Timestamp.fromDate(
      DateTime.now().add(Duration(days: activationFreeDays)),
    );

    final activationCodeRef = _firestore
        .collection('activation_codes')
        .doc(activationCodeId);

    final batch = _firestore.batch();

    final policyAcceptanceRef = shopRef
        .collection('policy_acceptances')
        .doc('shop_owner_policy_v$acceptedShopOwnerPolicyVersion');

    batch.set(shopRef, {
      'shopId': shopCode,
      'shopCode': shopCode,
      'name': name.trim(),
      'ownerUid': user.uid,

      // 🔒 建立後鎖定欄位
      'profileLocked': true,
      'lockedFields': [
        'name',
        'businessType',
        'city',
        'licenseNumber',
        'taxId',
      ],

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // 🎟️ 激活碼 / 方案開通
      'activationCode': activationCode.trim(),
      'activationCodeId': activationCodeId,
      'activationFreeDays': activationFreeDays,
      'plan': activationPlan,
      'paidUntil': paidUntil,
      'planStartedAt': FieldValue.serverTimestamp(),
      'acceptedShopOwnerPolicyVersion': acceptedShopOwnerPolicyVersion,

      'acceptedShopOwnerPolicyAt': FieldValue.serverTimestamp(),

      // 基本資料
      'businessType': businessType,
      'phone': '',
      'address': '',
      'description': '',
      'city': city.trim(),
      'district': district.trim(),
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

      // ========= 💰 訂金 / 付款設定 =========
      'depositEnabled': false,
      'depositAmount': 0,

      'bankName': '',
      'accountName': '',
      'accountNumber': '',

      'paymentMethods': {'cash': true, 'transfer': false},

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

    batch.set(policyAcceptanceRef, {
      'type': 'shop_owner_policy',
      'version': acceptedShopOwnerPolicyVersion,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedByUid': user.uid,
      'acceptedByEmail': user.email ?? '',
    });

    final currentUsedCount = activationCodeData['usedCount'] ?? 0;

    final maxUses = activationCodeData['maxUses'] ?? 0;

    final newUsedCount = currentUsedCount + 1;

    batch.update(activationCodeRef, {
      'usedCount': newUsedCount,
      'usedShopIds': FieldValue.arrayUnion([shopRef.id]),
      'usedByUids': FieldValue.arrayUnion([user.uid]),
      'lastUsedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      // 🔥 用完自動停用
      'enabled': newUsedCount < maxUses,
    });
    final activationUsageLogRef = activationCodeRef
        .collection('usage_logs')
        .doc(shopRef.id);

    batch.set(activationUsageLogRef, {
      'shopId': shopRef.id,
      'shopName': name.trim(),
      'usedByUid': user.uid,
      'usedByEmail': user.email ?? '',
      'plan': activationPlan,
      'freeDays': activationFreeDays,
      'usedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return shopRef.id;
  }

  /// 取得我的店家
  Future<List<Map<String, dynamic>>> getMyShops() async {
    final user = _currentUser;
    if (user == null) throw Exception('未登入');

    final memberSnapshot = await _shopMembers
        .where('uid', isEqualTo: user.uid)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in memberSnapshot.docs) {
      final data = doc.data();
      final shopId = data['shopId'];

      final shopDoc = await _shops.doc(shopId).get();
      if (!shopDoc.exists) continue;

      final shopData = shopDoc.data() ?? {};

      result.add({
        'shopId': shopId,
        'name': shopData['name'] ?? '',
        'role': data['role'] ?? '',

        // 首頁卡片顯示用
        'coverUrl': shopData['coverUrl'] ?? '',

        /// 平台首頁「我的店家卡片」專用圖片
        'platformHomeCoverUrl': shopData['platformHomeCoverUrl'] ?? '',
        'platformHomeLogoUrl': shopData['platformHomeLogoUrl'] ?? '',

        'city': shopData['city'] ?? '',
        'district': shopData['district'] ?? '',
        'isOpen': shopData['isOpen'] ?? true,
        'isPublic': shopData['isPublic'] ?? false,
        'businessType': shopData['businessType'] ?? '',

        // 🔥 首頁營運資訊區
        'enabledModules': List<String>.from(shopData['enabledModules'] ?? []),

        'licenseNumber': shopData['licenseNumber'] ?? '',

        'taxId': shopData['taxId'] ?? '',

        'updatedAt': shopData['updatedAt'],

        // 營業時間自動判斷用
        'openTime': shopData['openTime'] ?? '',
        'closeTime': shopData['closeTime'] ?? '',
      });
    }

    return result;
  }

  /// 取得單一店家
  Future<Map<String, dynamic>?> getShop(String shopId) async {
    final doc = await _shops.doc(shopId).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};

    return {'shopId': doc.id, ...data};
  }

  /// 監聽單一店家
  Stream<Map<String, dynamic>?> streamShop(String shopId) {
    return _shops.doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {'shopId': doc.id, ...doc.data()!};
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

  /// 🔐 取得某使用者在該店的完整成員資料
  Future<Map<String, dynamic>?> getUserMemberInShop({
    required String shopId,
    required String uid,
  }) async {
    final snapshot = await _shopMembers
        .where('shopId', isEqualTo: shopId)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;

    return {'id': doc.id, ...doc.data()};
  }

  /// 是否有管理店家權限
  bool canManageShop(String? role) {
    return role == ShopRoles.owner;
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
    final normalized =
        blockedDates
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

    final Map<String, dynamic> specialPrices = Map<String, dynamic>.from(
      shop['specialPrices'] ?? {},
    );

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
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

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

  String normalizeEmail(String email) {
    return ShopMemberPermissionService.instance.normalizeEmail(email);
  }

  Map<String, bool> ownerDefaultPermissions() {
    return ShopMemberPermissionService.instance.ownerDefaultPermissions();
  }

  Map<String, bool> managerDefaultPermissions() {
    return ShopMemberPermissionService.instance.managerDefaultPermissions();
  }

  Map<String, bool> staffDefaultPermissions() {
    return ShopMemberPermissionService.instance.staffDefaultPermissions();
  }

  Map<String, bool> defaultPermissionsByRole(String role) {
    return ShopMemberPermissionService.instance.defaultPermissionsByRole(role);
  }

  Map<String, bool> normalizePermissions(dynamic value, {String? role}) {
    return ShopMemberPermissionService.instance.normalizePermissions(
      value,
      role: role,
    );
  }

  bool hasPermission(Map<String, dynamic>? memberData, String permissionKey) {
    return ShopMemberPermissionService.instance.hasPermission(
      memberData,
      permissionKey,
    );
  }

  // ===== 成員 =====

  Stream<List<Map<String, dynamic>>> streamShopMembers(String shopId) {
    return ShopMemberPermissionService.instance.streamShopMembers(shopId);
  }

  // ===== 邀請 =====

  Stream<List<Map<String, dynamic>>> streamShopMemberInvites(String shopId) {
    return ShopMemberPermissionService.instance.streamShopMemberInvites(shopId);
  }

  Future<void> upsertMemberPermissionByEmail({
    required String shopId,
    required String email,
    required String role,
    required Map<String, bool> permissions,
    required String operatorUid,
    required String operatorRole,
  }) async {
    return ShopMemberPermissionService.instance.upsertMemberPermissionByEmail(
      shopId: shopId,
      email: email,
      role: role,
      permissions: permissions,
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }

  Future<void> updateMemberPermission({
    required String memberDocId,
    required String shopId,
    required String role,
    required Map<String, bool> permissions,
    required String operatorUid,
    required String operatorRole,
  }) async {
    return ShopMemberPermissionService.instance.updateMemberPermission(
      memberDocId: memberDocId,
      shopId: shopId,
      role: role,
      permissions: permissions,
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }

  Future<void> removeMember({
    required String memberDocId,
    required String shopId,
    required String operatorUid,
    required String operatorRole,
  }) async {
    return ShopMemberPermissionService.instance.removeMember(
      memberDocId: memberDocId,
      shopId: shopId,
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
    return ShopMemberPermissionService.instance.removeMemberInvite(
      inviteDocId: inviteDocId,
      shopId: shopId,
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }

  Future<void> syncPendingInvitesForCurrentUser() async {
    return ShopMemberPermissionService.instance
        .syncPendingInvitesForCurrentUser();
  }

  // ===============================
  // 🏠 房型 / 房間 / 房務日曆
  // 已搬到 ShopRoomService，這裡只保留代理
  // ===============================

  CollectionReference<Map<String, dynamic>> roomTypesRef(String shopId) {
    return ShopRoomService.instance.roomTypesRef(shopId);
  }

  Stream<List<Map<String, dynamic>>> streamRoomTypes(String shopId) {
    return ShopRoomService.instance.streamRoomTypes(shopId);
  }

  Future<List<Map<String, dynamic>>> getRoomTypes(String shopId) async {
    return ShopRoomService.instance.getRoomTypes(shopId);
  }

  Future<void> createRoomType({
    required String shopId,
    required String name,
    required int capacity,
    required int price,
    required int totalRooms,
    required String description,
    required int extraPrice,
    required int width,
    required int depth,
    required int height,
    Map<String, dynamic>? extraData,
  }) async {
    return ShopRoomService.instance.createRoomType(
      shopId: shopId,
      name: name,
      capacity: capacity,
      price: price,
      totalRooms: totalRooms,
      description: description,
      extraPrice: extraPrice,
      width: width,
      depth: depth,
      height: height,
      extraData: extraData,
    );
  }

  Future<void> updateRoomType({
    required String shopId,
    required String roomTypeId,
    required String name,
    required int capacity,
    required int price,
    required bool isSingle,
  }) async {
    return ShopRoomService.instance.updateRoomType(
      shopId: shopId,
      roomTypeId: roomTypeId,
      name: name,
      capacity: capacity,
      price: price,
      isSingle: isSingle,
    );
  }

  Future<void> deleteRoomType({
    required String shopId,
    required String roomTypeId,
  }) async {
    return ShopRoomService.instance.deleteRoomType(
      shopId: shopId,
      roomTypeId: roomTypeId,
    );
  }

  Future<String> uploadRoomTypeImage({
    required String shopId,
    required String roomTypeId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    return ShopRoomService.instance.uploadRoomTypeImage(
      shopId: shopId,
      roomTypeId: roomTypeId,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<void> deleteRoomTypeImage({
    required String shopId,
    required String roomTypeId,
    required String imageUrl,
  }) async {
    return ShopRoomService.instance.deleteRoomTypeImage(
      shopId: shopId,
      roomTypeId: roomTypeId,
      imageUrl: imageUrl,
    );
  }

  CollectionReference<Map<String, dynamic>> roomsRef(String shopId) {
    return ShopRoomService.instance.roomsRef(shopId);
  }

  Stream<List<Map<String, dynamic>>> streamRooms(String shopId) {
    return ShopRoomService.instance.streamRooms(shopId);
  }

  Future<List<Map<String, dynamic>>> getRooms(String shopId) async {
    return ShopRoomService.instance.getRooms(shopId);
  }

  Future<void> createRoom({
    required String shopId,
    required String name,
    required String roomTypeId,
  }) async {
    return ShopRoomService.instance.createRoom(
      shopId: shopId,
      name: name,
      roomTypeId: roomTypeId,
    );
  }

  Future<void> updateRoomStatus({
    required String shopId,
    required String roomId,
    required bool enabled,
  }) async {
    return ShopRoomService.instance.updateRoomStatus(
      shopId: shopId,
      roomId: roomId,
      enabled: enabled,
    );
  }

  Future<void> deleteRoom({
    required String shopId,
    required String roomId,
  }) async {
    return ShopRoomService.instance.deleteRoom(shopId: shopId, roomId: roomId);
  }

  Future<void> updateRoomBlockedDates({
    required String shopId,
    required String roomId,
    required List<String> blockedDates,
  }) async {
    return ShopRoomService.instance.updateRoomBlockedDates(
      shopId: shopId,
      roomId: roomId,
      blockedDates: blockedDates,
    );
  }

  Future<void> updateRoomPriceRules({
    required String shopId,
    required String roomId,
    required List<Map<String, dynamic>> rules,
  }) async {
    return ShopRoomService.instance.updateRoomPriceRules(
      shopId: shopId,
      roomId: roomId,
      rules: rules,
    );
  }

  Future<void> updateRoomDiscountRules({
    required String shopId,
    required String roomId,
    required List<Map<String, dynamic>> rules,
  }) async {
    return ShopRoomService.instance.updateRoomDiscountRules(
      shopId: shopId,
      roomId: roomId,
      rules: rules,
    );
  }

  CollectionReference<Map<String, dynamic>> roomCalendarRef(String shopId) {
    return ShopRoomService.instance.roomCalendarRef(shopId);
  }

  Stream<List<Map<String, dynamic>>> streamRoomCalendarByDate(
    String shopId,
    String date,
  ) {
    return ShopRoomService.instance.streamRoomCalendarByDate(shopId, date);
  }

  Future<void> setRoomStatus({
    required String shopId,
    required String roomId,
    required String date,
    required String status,
    String roomName = '',
  }) async {
    return ShopRoomService.instance.setRoomStatus(
      shopId: shopId,
      roomId: roomId,
      date: date,
      status: status,
      roomName: roomName,
    );
  }

  Future<List<Map<String, dynamic>>> getAvailableRoomTypes({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return ShopRoomService.instance.getAvailableRoomTypes(
      shopId: shopId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  int calculateRoomPrice({
    required Map<String, dynamic> room,
    required int basePrice,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return ShopRoomService.instance.calculateRoomPrice(
      room: room,
      basePrice: basePrice,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ===============================
  // 📜 入住條款（版本控管）
  // ===============================

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

  Future<void> updateCheckinPolicy({
    required String shopId,
    required Map<String, dynamic> sections,
    required Map<String, bool> enabled,
    required List<String> customPoliciesPage1,
    required List<String> customPoliciesPage2,
  }) async {
    final user = _currentUser;

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

    final policyData = {
      'version': newVersion,
      'sections': sections,
      'enabled': enabled,
      'customPoliciesPage1': customPoliciesPage1,
      'customPoliciesPage2': customPoliciesPage2,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user?.uid ?? '',
      'updatedByEmail': user?.email ?? '',
    };

    await docRef.set(policyData);

    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policy_versions')
        .doc('v$newVersion')
        .set(policyData);
  }

  Future<bool> hasAcceptedPolicy({
    required String shopId,
    required String userId,
  }) async {
    final policy = await getCheckinPolicy(shopId);
    if (policy == null) return true;

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

  Future<List<Map<String, dynamic>>> getPolicyAcceptances(String shopId) async {
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

      result.add({'userId': userId, ...doc.data()!});
    }

    return result;
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('user_profiles').doc(userId).get();

    if (!doc.exists) return null;

    return doc.data();
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
