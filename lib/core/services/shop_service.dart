// 檔案名稱：lib/core/services/shop_service.dart
// 功能說明：店家服務層（含營業資訊 / Logo / 封面 / 預約設定）

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/services/platform_activation_code_service.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_profile_service.dart';

class ShopService {
  ShopService._();
  static final instance = ShopService._();

  Future<void> deleteImageByUrl(String url) async {
    return ShopProfileService.instance.deleteImageByUrl(url);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  CollectionReference<Map<String, dynamic>> get _shopMembers =>
      _firestore.collection('shop_members');

  List<String> effectiveEnabledModules(Map<String, dynamic> shop) {
    final plan = shop['plan']?.toString() ?? 'free';

    final lockedModule =
        shop['lockedModule']?.toString().trim().isNotEmpty == true
        ? shop['lockedModule'].toString()
        : shop['businessType']?.toString() ?? ShopModules.catHotel;

    if (plan == 'pro') {
      return ShopModules.proEnabledModules();
    }

    return ShopModules.lockedPlanModules(lockedModule);
  }

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

  bool isModuleEnabled(Map<String, dynamic>? shop, String module) {
    if (shop == null) {
      return false;
    }

    return normalizeEnabledModules(shop['enabledModules']).contains(module);
  }

  Future<void> updateEnabledModules({
    required String shopId,
    required List<String> enabledModules,
  }) async {
    final shopDoc = await _shops.doc(shopId).get();
    final shop = shopDoc.data() ?? {};

    final plan = shop['plan']?.toString() ?? 'free';

    final lockedModule =
        shop['lockedModule']?.toString().trim().isNotEmpty == true
        ? shop['lockedModule'].toString()
        : shop['businessType']?.toString() ?? ShopModules.catHotel;

    final normalized = enabledModules
        .map((e) => e.trim())
        .where((e) => ShopModules.all.contains(e))
        .toSet()
        .toList();

    final List<String> finalModules;

    if (plan == 'pro') {
      finalModules = normalized.isEmpty
          ? ShopModules.proEnabledModules()
          : {ShopModules.basicInfo, ...normalized}.toList();
    } else {
      finalModules = [...ShopModules.lockedPlanModules(lockedModule)];
    }

    final List<dynamic> existingModules = shop['enabledModules'] is List
        ? shop['enabledModules'] as List<dynamic>
        : const <dynamic>[];
    if (existingModules
            .map((dynamic e) => e.toString())
            .contains(ShopModules.daycare) &&
        !finalModules.contains(ShopModules.daycare)) {
      finalModules.add(ShopModules.daycare);
    }

    await _shops.doc(shopId).update({
      'enabledModules': finalModules,
      'lockedModule': lockedModule,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔥 更新店家資料（新增給後台用）
  Future<void> updateShop({
    required String shopId,
    required Map<String, dynamic> data,
  }) async {
    return ShopProfileService.instance.updateShop(shopId: shopId, data: data);
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

    final lockedModule =
        activationCodeData['module']?.toString() ?? ShopModules.catHotel;

    final initialEnabledModules = ShopModules.lockedPlanModules(lockedModule);

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
      'businessType': lockedModule,
      'lockedModule': lockedModule,
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
      'enabledModules': initialEnabledModules,

      // ========= 預約設定 =========
      'bookingEnabled': true,
      'daycareEnabled': false,
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
      'module': lockedModule,
      'usedAt': FieldValue.serverTimestamp(),
    });

    try {
      print('🔥 準備 batch commit');
      await batch.commit();
      print('✅ batch commit 成功');
    } catch (e, st) {
      print('🔥 建立店家 batch commit 失敗: $e');
      print(st);
      rethrow;
    }
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
        'enabledModules': effectiveEnabledModules(shopData),

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
    return ShopProfileService.instance.getShop(shopId);
  }

  /// 依 shopCode 取得店家
  Future<Map<String, dynamic>?> getShopByCode(String shopCode) async {
    final snapshot = await _shops.doc(shopCode).get();

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  /// 監聽單一店家
  Stream<Map<String, dynamic>?> streamShop(String shopId) {
    return ShopProfileService.instance.streamShop(shopId);
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
    return ShopProfileService.instance.updateShopBasicInfo(
      shopId: shopId,
      name: name,
      businessType: businessType,
      phone: phone,
      address: address,
      description: description,
      city: city,
      district: district,
      lineUrl: lineUrl,
      igUrl: igUrl,
      fbUrl: fbUrl,
      businessHours: businessHours,
      licenseNumber: licenseNumber,
      taxId: taxId,
      showTaxId: showTaxId,
    );
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
    return ShopProfileService.instance.updateBusinessInfo(
      shopId: shopId,
      isOpen: isOpen,
      businessHours: businessHours,
      openTime: openTime,
      closeTime: closeTime,
      closedDays: closedDays,
      serviceTypes: serviceTypes,
      isPublic: isPublic,
    );
  }

  /// 更新預約基本設定
  Future<void> updateBookingSettings({
    required String shopId,
    bool? bookingEnabled,
    bool? daycareEnabled,
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
    if (daycareEnabled != null) data['daycareEnabled'] = daycareEnabled;
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
    return ShopProfileService.instance.uploadShopLogo(
      shopId: shopId,
      bytes: bytes,
    );
  }

  /// 上傳店家 Cover
  Future<String> uploadShopCover({
    required String shopId,
    required Uint8List bytes,
  }) async {
    return ShopProfileService.instance.uploadShopCover(
      shopId: shopId,
      bytes: bytes,
    );
  }

  Future<ShopAboutCoverImageUpload> uploadAboutCoverImage({
    required String shopId,
    required Uint8List bytes,
  }) {
    return ShopProfileService.instance.uploadAboutCoverImage(
      shopId: shopId,
      bytes: bytes,
    );
  }

  Future<bool> tryDeleteAboutCoverImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return ShopProfileService.instance.tryDeleteAboutCoverImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
    );
  }

  Future<ShopBannerImageUpload> uploadShopBannerImage({
    required String shopId,
    required Uint8List bytes,
  }) {
    return ShopProfileService.instance.uploadShopBannerImage(
      shopId: shopId,
      bytes: bytes,
    );
  }

  Future<bool> tryDeleteShopBannerImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return ShopProfileService.instance.tryDeleteShopBannerImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
    );
  }

  Future<ShopEnvironmentIntroImageUpload> uploadEnvironmentIntroImage({
    required String shopId,
    required String slot,
    required Uint8List bytes,
  }) {
    return ShopProfileService.instance.uploadEnvironmentIntroImage(
      shopId: shopId,
      slot: slot,
      bytes: bytes,
    );
  }

  Future<bool> tryDeleteEnvironmentIntroImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return ShopProfileService.instance.tryDeleteEnvironmentIntroImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
    );
  }

  Uint8List? compressEnvironmentImageBytes({
    required Uint8List bytes,
    required int maxSide,
    int quality = 85,
  }) {
    return ShopProfileService.instance.compressEnvironmentImageBytes(
      bytes: bytes,
      maxSide: maxSide,
      quality: quality,
    );
  }

  Future<ShopEnvironmentIntroImageUpload> uploadEnvironmentGalleryImage({
    required String shopId,
    required Uint8List bytes,
  }) {
    return ShopProfileService.instance.uploadEnvironmentGalleryImage(
      shopId: shopId,
      bytes: bytes,
    );
  }

  Future<ShopEnvironmentIntroImageUpload> uploadEnvironmentFeatureImage({
    required String shopId,
    required Uint8List bytes,
  }) {
    return ShopProfileService.instance.uploadEnvironmentFeatureImage(
      shopId: shopId,
      bytes: bytes,
    );
  }

  Future<bool> tryDeleteEnvironmentGalleryImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return ShopProfileService.instance.tryDeleteEnvironmentGalleryImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
    );
  }

  Future<bool> tryDeleteEnvironmentFeatureImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return ShopProfileService.instance.tryDeleteEnvironmentFeatureImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
    );
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
    bool cleaningCompleted = false,
    bool reopened = false,
  }) async {
    return ShopRoomService.instance.setRoomStatus(
      shopId: shopId,
      roomId: roomId,
      date: date,
      status: status,
      roomName: roomName,
      cleaningCompleted: cleaningCompleted,
      reopened: reopened,
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
  // 📜 入住條款
  // 已搬到 ShopPolicyService，這裡只保留代理
  // ===============================

  Future<Map<String, dynamic>?> getCheckinPolicy(String shopId) async {
    return ShopPolicyService.instance.getCheckinPolicy(shopId);
  }

  Future<void> updateCheckinPolicy({
    required String shopId,
    required Map<String, dynamic> sections,
    required Map<String, bool> enabled,
    required List<String> customPoliciesPage1,
    required List<String> customPoliciesPage2,
    Map<String, List<String>> sectionApplicableServices =
        const <String, List<String>>{},
    List<List<String>> customPolicyServicesPage1 = const <List<String>>[],
    List<List<String>> customPolicyServicesPage2 = const <List<String>>[],
  }) async {
    return ShopPolicyService.instance.updateCheckinPolicy(
      shopId: shopId,
      sections: sections,
      enabled: enabled,
      customPoliciesPage1: customPoliciesPage1,
      customPoliciesPage2: customPoliciesPage2,
      sectionApplicableServices: sectionApplicableServices,
      customPolicyServicesPage1: customPolicyServicesPage1,
      customPolicyServicesPage2: customPolicyServicesPage2,
    );
  }

  Future<bool> hasAcceptedPolicy({
    required String shopId,
    required String userId,
    String serviceType = 'accommodation',
  }) async {
    return ShopPolicyService.instance.hasAcceptedPolicy(
      shopId: shopId,
      userId: userId,
      serviceType: serviceType,
    );
  }

  Future<void> acceptPolicy({
    required String shopId,
    required String userId,
    String serviceType = 'accommodation',
  }) async {
    return ShopPolicyService.instance.acceptPolicy(
      shopId: shopId,
      userId: userId,
      serviceType: serviceType,
    );
  }

  Future<List<Map<String, dynamic>>> getPolicyAcceptances(String shopId) async {
    return ShopPolicyService.instance.getPolicyAcceptances(shopId);
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return ShopPolicyService.instance.getUserProfile(userId);
  }
}
