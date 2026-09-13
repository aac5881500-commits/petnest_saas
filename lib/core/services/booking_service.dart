// 檔案名稱：lib/core/services/booking_service.dart
// 功能說明：預約服務層（區間預約版）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/stay_booking_function_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/inventory_stock_service.dart';
import 'package:petnest_saas/core/services/booking_inventory_function_service.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:flutter/foundation.dart';

class BookingService {
  BookingService._();
  static final instance = BookingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  /// 建立預約（區間版）
  Future<String> createBooking({
    required String shopId,
    required String customerName,
    required String customerPhone,
    required List<String> petIds,
    required String serviceType,
    required DateTime startDate,
    required DateTime endDate,
    required int nights,
    required String roomId,
    required String roomName,
    required String roomTypeName,
    required int basePrice,
    required int extraPetPrice,
    required int extraPetCount,
    required int extraPetTotal,
    required int roomSubtotal,
    required List<dynamic> roomImages,
    String note = '',
    String address = '',
    String emergencyName = '',
    String emergencyPhone = '',
    String emergencyRelation = '',
    String emergencyAddress = '',
    String emergencyPhone2 = '',
    int totalPrice = 0,

    int originalTotal = 0,
    int specialDateSurchargeAmount = 0,
    List<Map<String, dynamic>> specialDateSurchargeDetails =
        const <Map<String, dynamic>>[],
    int discountAmount = 0,
    int discountUsedNights = 0,
    int discountPercent = 0,
    int discountMinNights = 0,
    String discountBase = '',

    String discountCampaignId = '',
    String discountCampaignName = '',
    String discountCampaignDescription = '',
    String discountCampaignType = '',
    String discountValueType = '',
    num discountValue = 0,
    bool allowCouponTogether = false,

    String couponId = '',
    String couponName = '',
    String couponType = '',
    int couponDiscountAmount = 0,

    int depositAmount = 0,
    String paymentMethod = '',
    String payAmountType = '', // deposit / full
    List<Map<String, dynamic>>? pets,
    List<Map<String, dynamic>>? addons,
    int policyVersion = 0,
    String policyTitle = '入住須知',
    Timestamp? policyAcceptedAt,
    TermsConsentSnapshot? termsConsent,

    /// 🔒 同一次送出請求的唯一識別碼，用來避免網路重送建立兩筆訂單
    String requestId = '',
    Map<String, dynamic>? customFormAnswers,
    Map<String, dynamic>? dailyCareEntitlement,
  }) async {
    final user = _currentUser;

    /// 🔒 有 requestId 時固定使用同一個訂單文件 ID
    final normalizedRequestId = requestId.trim();

    final doc = normalizedRequestId.isNotEmpty
        ? _bookings.doc(normalizedRequestId)
        : _bookings.doc();

    /// 🔒 相同請求已經建立過，就直接回傳原訂單，不再重建。
    /// 若上次停在「訂單已寫入、加購庫存尚未扣除」，這裡會再走一次
    /// 幂等 finalize，避免留下沒扣庫存的有效訂單。
    if (normalizedRequestId.isNotEmpty) {
      final existingBooking = await doc.get();

      if (existingBooking.exists) {
        final String existingStatus = (existingBooking.data()?['status'] ?? '')
            .toString();
        if (existingStatus == 'cancelled' ||
            existingBooking.data()?['cancelledAt'] != null) {
          debugPrint(
            '[BookingSubmit] existing requestId booking is cancelled: ${doc.id}',
          );
          throw const InventoryException('此預約無法完成，請重新送出');
        }
        debugPrint(
          '[BookingSubmit] existing requestId booking found: ${doc.id}',
        );
        await _afterBookingCreated(shopId: shopId, bookingId: doc.id);
        return doc.id;
      }
    }
    debugPrint('FRONT_BOOKING_STEP: load shop');
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

    /// 🔥 取得店家付款資料快照
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();

    final shopData = shopDoc.data() ?? {};

    final String normalizedPaymentMethod = ShopPaymentMethods.normalizeMethodId(
      paymentMethod,
    );
    final ShopPaymentCatalog paymentCatalog = ShopPaymentMethods.resolve(
      shopData: Map<String, dynamic>.from(shopData),
      serviceType: PolicyApplicableService.accommodation,
    );
    if (paymentCatalog.isEmpty) {
      throw Exception(ShopPaymentMethods.noMethodsMessage);
    }
    if (!paymentCatalog.isEnabled(normalizedPaymentMethod)) {
      throw Exception('請選擇有效的付款方式');
    }

    final bankName = shopData['bankName'] ?? '';
    final accountName = shopData['accountName'] ?? '';
    final accountNumber = shopData['accountNumber'] ?? '';
    final depositExpireHours = shopData['depositExpireHours'] ?? 1;

    // 🔥 取得寵物資料（快照）
    if (user == null) throw Exception('未登入');

    final petDocs = await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .collection('pets')
        .where(FieldPath.documentId, whereIn: petIds)
        .get();

    final Map<String, Map<String, dynamic>> petsById =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> pet in pets ?? <Map<String, dynamic>>[]) {
      final String id = (pet['petId'] ?? pet['id'] ?? '').toString().trim();
      if (id.isNotEmpty) {
        petsById[id] = pet;
      }
    }
    final finalPets = petDocs.docs.map((doc) {
      final Map<String, dynamic> merged = <String, dynamic>{
        ...doc.data(),
        ...?petsById[doc.id],
        'petId': doc.id,
      };
      return PetSnapshot.fromPet(merged);
    }).toList();

    final String? depositExpireIso =
        paymentMethod == 'transfer' || paymentMethod == 'cash'
        ? DateTime.now()
              .add(
                depositExpireHours == 0
                    ? const Duration(minutes: 1)
                    : Duration(hours: depositExpireHours as int),
              )
              .toIso8601String()
        : null;
    final Map<String, dynamic> bookingPayload = <String, dynamic>{
      'addons': (addons ?? []).isNotEmpty ? addons : <dynamic>[],
      if (dailyCareEntitlement != null)
        'dailyCareEntitlement': dailyCareEntitlement,
      'shopName': shopData['name'],
      'policyVersion': policyVersion,
      'policyTitle': policyTitle,
      if (policyAcceptedAt != null)
        'policyAcceptedAt': policyAcceptedAt.toDate().toIso8601String(),
      if (termsConsent != null) ...termsConsent.toCallableFields(),
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
      'address': address,
      'roomTypeName': roomTypeName,
      'basePrice': basePrice,
      'extraPetPrice': extraPetPrice,
      'extraPetCount': extraPetCount,
      'extraPetTotal': extraPetTotal,
      'roomSubtotal': roomSubtotal,
      'roomImages': roomImages,
      'emergencyContact': <String, dynamic>{
        'name': emergencyName,
        'phone': emergencyPhone,
        'relation': emergencyRelation,
        'address': emergencyAddress,
        'phone2': emergencyPhone2,
      },
      'petIds': petIds,
      'pets': finalPets,
      'serviceType': serviceType,
      'nights': nights,
      'note': note.trim(),
      'totalPrice': totalPrice,
      'originalTotal': originalTotal,
      'specialDateSurchargeAmount': specialDateSurchargeAmount,
      'specialDateSurchargeDetails': specialDateSurchargeDetails,
      'discountAmount': discountAmount,
      'discountUsedNights': discountUsedNights,
      'discountPercent': discountPercent,
      'discountMinNights': discountMinNights,
      'discountBase': discountBase,
      'discountCampaignId': discountCampaignId,
      'discountCampaignName': discountCampaignName,
      'discountCampaignDescription': discountCampaignDescription.trim(),
      'discountCampaignType': discountCampaignType,
      'discountValueType': discountValueType,
      'discountValue': discountValue,
      'allowCouponTogether': allowCouponTogether,
      'couponId': couponId,
      'couponName': couponName,
      'couponType': couponType,
      'couponDiscountAmount': couponDiscountAmount,
      'depositAmount': depositAmount,
      'paymentMethod': normalizedPaymentMethod.isNotEmpty
          ? normalizedPaymentMethod
          : paymentMethod,
      'payAmountType': payAmountType,
      'paidAmount': 0,
      'remainingAmount': totalPrice,
      'paymentStatus': 'unpaid',
      'bankName': bankName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'depositExpireHours': depositExpireHours,
      if (depositExpireIso != null) 'depositExpireAt': depositExpireIso,
      'cameraAccessEnabled': false,
      if (customFormAnswers != null && customFormAnswers.isNotEmpty)
        'customFormAnswers': customFormAnswers,
    };
    final String bookingId =
        await StayBookingFunctionService.instance.createStayBooking(
          shopId: shopId,
          roomTypeId: roomId,
          startDate: normalizedStart,
          endDate: normalizedEnd,
          requestId: doc.id,
          source: 'customer',
          userId: user.uid,
          booking: bookingPayload,
        );

    debugPrint(
      '[BookingSubmit] create booking success: $bookingId shopId=$shopId',
    );
    await _afterBookingCreated(shopId: shopId, bookingId: bookingId);
    return bookingId;
  }

  Future<String> createAdminBooking({
    required String shopId,
    required String userId,
    required String customerName,
    required String customerPhone,
    required List<String> petIds,
    required String serviceType,
    required DateTime startDate,
    required DateTime endDate,
    required int nights,
    required String roomId,
    required String roomName,
    required String roomTypeName,
    required int basePrice,
    required int extraPetPrice,
    required int extraPetCount,
    required int extraPetTotal,
    required int roomSubtotal,
    required List<dynamic> roomImages,
    String note = '',
    String address = '',
    String emergencyName = '',
    String emergencyPhone = '',
    String emergencyRelation = '',
    String emergencyAddress = '',
    String emergencyPhone2 = '',
    int totalPrice = 0,
    int originalTotal = 0,

    int specialDateSurchargeAmount = 0,
    List<Map<String, dynamic>> specialDateSurchargeDetails =
        const <Map<String, dynamic>>[],

    bool applyLongStayDiscount = false,
    int discountAmount = 0,
    int discountPercent = 0,
    int discountMinNights = 0,
    int discountUsedNights = 0,
    String discountBase = '',
    String discountCampaignId = '',
    String discountCampaignName = '',
    String discountCampaignDescription = '',
    String discountCampaignType = '',
    String discountValueType = '',
    num discountValue = 0,
    bool allowCouponTogether = false,
    int depositAmount = 0,
    String paymentMethod = '',
    String payAmountType = '', // deposit / full
    List<Map<String, dynamic>>? pets,
    List<Map<String, dynamic>>? addons,
    int policyVersion = 0,
    String policySignMethod = '',
    String policyServiceType = PolicyApplicableService.accommodation,
    Map<String, dynamic>? adminCustomFormAnswers,
    String adminOrderSource = '',
    Map<String, dynamic>? dailyCareEntitlement,
  }) async {
    final operator = _currentUser;
    final doc = _bookings.doc();

    debugPrint('ADMIN_BOOKING_STEP 1: 開始準備訂單');
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

    /// 🔥 取得店家付款資料快照
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();

    final shopData = shopDoc.data() ?? {};

    final String normalizedPaymentMethod = ShopPaymentMethods.normalizeMethodId(
      paymentMethod,
    );
    final ShopPaymentCatalog paymentCatalog = ShopPaymentMethods.resolve(
      shopData: Map<String, dynamic>.from(shopData),
      serviceType: PolicyApplicableService.accommodation,
    );
    if (paymentCatalog.isEmpty) {
      throw Exception(ShopPaymentMethods.noMethodsMessage);
    }
    if (!paymentCatalog.isEnabled(normalizedPaymentMethod)) {
      throw Exception('請選擇有效的付款方式');
    }
    if (!ShopPaymentMethods.isAdminCreateSelectable(normalizedPaymentMethod)) {
      throw Exception('手動建單請選擇到店付款或銀行轉帳');
    }

    final bankName = shopData['bankName'] ?? '';
    final accountName = shopData['accountName'] ?? '';
    final accountNumber = shopData['accountNumber'] ?? '';
    final depositExpireHours = shopData['depositExpireHours'] ?? 1;

    // 🔥 取得寵物資料（快照）
    if (operator == null) throw Exception('未登入');

    final finalPets = (pets ?? []).map((p) {
      final String petId = (p['petId'] ?? p['id'] ?? '').toString().trim();
      return PetSnapshot.fromPet(<String, dynamic>{...p, 'petId': petId});
    }).toList();

    debugPrint('ADMIN_BOOKING_STEP 3: 開始寫入 booking');
    final String? depositExpireIso =
        paymentMethod == 'transfer' || paymentMethod == 'cash'
        ? DateTime.now()
              .add(
                depositExpireHours == 0
                    ? const Duration(minutes: 1)
                    : Duration(hours: depositExpireHours as int),
              )
              .toIso8601String()
        : null;
    final String bookingId =
        await StayBookingFunctionService.instance.createStayBooking(
          shopId: shopId,
          roomTypeId: roomId,
          startDate: normalizedStart,
          endDate: normalizedEnd,
          requestId: doc.id,
          source: 'admin',
          userId: userId,
          booking: <String, dynamic>{
            'addons': (addons ?? []).isNotEmpty ? addons : <dynamic>[],
            if (dailyCareEntitlement != null)
              'dailyCareEntitlement': dailyCareEntitlement,
            'shopName': shopData['name'],
            'createdByUid': operator.uid,
            'createdByEmail': operator.email,
            'createdByDisplayName': operator.displayName,
            'policyVersion': policyVersion,
            'policySignMethod': policySignMethod,
            'policyServiceType': policyServiceType,
            'policyAcceptedByEmail': operator.email,
            'customerName': customerName.trim(),
            'customerPhone': customerPhone.trim(),
            'address': address,
            'roomTypeName': roomTypeName,
            'basePrice': basePrice,
            'extraPetPrice': extraPetPrice,
            'extraPetCount': extraPetCount,
            'extraPetTotal': extraPetTotal,
            'roomSubtotal': roomSubtotal,
            'roomImages': roomImages,
            'emergencyContact': <String, dynamic>{
              'name': emergencyName,
              'phone': emergencyPhone,
              'relation': emergencyRelation,
              'address': emergencyAddress,
              'phone2': emergencyPhone2,
            },
            'petIds': petIds,
            'pets': finalPets,
            'serviceType': serviceType,
            'nights': nights,
            'note': note.trim(),
            'adminOrderSource': adminOrderSource.trim(),
            'totalPrice': totalPrice,
            'originalTotal': originalTotal,
            'quotedTotalPrice': totalPrice,
            'specialDateSurchargeAmount': specialDateSurchargeAmount,
            'specialDateSurchargeDetails': specialDateSurchargeDetails,
            'applyLongStayDiscount': applyLongStayDiscount,
            'discountAmount': discountAmount,
            'discountUsedNights': discountUsedNights,
            'discountPercent': discountPercent,
            'discountMinNights': discountMinNights,
            'discountBase': discountBase,
            'discountCampaignId': discountCampaignId,
            'discountCampaignName': discountCampaignName,
            'discountCampaignDescription': discountCampaignDescription.trim(),
            'discountCampaignType': discountCampaignType,
            'discountValueType': discountValueType,
            'discountValue': discountValue,
            'allowCouponTogether': allowCouponTogether,
            'depositAmount': depositAmount,
            'paymentMethod': normalizedPaymentMethod.isNotEmpty
                ? normalizedPaymentMethod
                : paymentMethod,
            'payAmountType': payAmountType,
            'paidAmount': 0,
            'remainingAmount': totalPrice,
            'paymentStatus': 'unpaid',
            'bankName': bankName,
            'accountName': accountName,
            'accountNumber': accountNumber,
            'depositExpireHours': depositExpireHours,
            if (depositExpireIso != null) 'depositExpireAt': depositExpireIso,
            'cameraAccessEnabled': false,
            if (adminCustomFormAnswers != null &&
                adminCustomFormAnswers.isNotEmpty)
              'adminCustomFormAnswers': adminCustomFormAnswers,
          },
        );

    debugPrint('ADMIN_BOOKING_STEP 4: booking 寫入完成');

    await _afterBookingCreated(shopId: shopId, bookingId: bookingId);
    return bookingId;
  }

  /// 取得單筆預約
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    final doc = await _bookings.doc(bookingId).get();

    if (!doc.exists) return null;

    return {'bookingId': doc.id, ...doc.data()!};
  }

  /// 監聽單筆預約
  Stream<Map<String, dynamic>?> streamBooking(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {'bookingId': doc.id, ...doc.data()!};
    });
  }

  /// 監聽某店家的全部預約（最新建立排前面）
  Stream<List<Map<String, dynamic>>> streamShopBookings(String shopId) {
    return _bookings
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'bookingId': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// 依狀態監聽某店家預約
  Stream<List<Map<String, dynamic>>> streamShopBookingsByStatus({
    required String shopId,
    required String status,
  }) {
    return _bookings
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'bookingId': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// 取得某店家全部預約（一次性）
  Future<List<Map<String, dynamic>>> getShopBookings(String shopId) async {
    final snapshot = await _bookings
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return {'bookingId': doc.id, ...doc.data()};
    }).toList();
  }

  /// ===============================
  /// ❌ 統一取消訂單
  /// ===============================
  /// 功能：
  /// - 更新 bookings 狀態為 cancelled
  /// - 寫入取消原因 / 取消來源
  /// - 釋放 room_calendar 房間
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelReason,
    required String cancelBy, // customer / admin / system
  }) async {
    final docRef = _bookings.doc(bookingId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('訂單不存在');
    }

    final data = doc.data();
    if (data == null) {
      throw Exception('訂單資料不存在');
    }

    final status = data['status']?.toString() ?? '';
    final cancelledAt = data['cancelledAt'];

    /// 已取消就不重複處理
    if (status == 'cancelled' || cancelledAt != null) return;

    await docRef.update({
      'status': 'cancelled',
      'assignStatus': data['assignStatus'] ?? 'unassigned',
      'cancelReason': cancelReason,
      'cancelBy': cancelBy,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await StayBookingFunctionService.instance.manage(
        shopId: (data['shopId'] ?? '').toString(),
        bookingId: bookingId,
        action: 'release',
      );
    } catch (error, stackTrace) {
      debugPrint('取消訂單釋放房型保留失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    final String couponShopId = (data['shopId'] ?? '').toString().trim();
    final String couponId = (data['couponId'] ?? '').toString().trim();

    if (couponShopId.isNotEmpty && couponId.isNotEmpty) {
      try {
        await MemberCouponService.instance.restoreCouponForCancelledBooking(
          shopId: couponShopId,
          couponId: couponId,
          bookingId: bookingId,
        );
      } catch (error, stackTrace) {
        debugPrint('取消訂單退回優惠券失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final shopId = data['shopId'];
    final roomId = data['roomId'];
    final startDate = data['startDate'];
    final endDate = data['endDate'];

    if (shopId != null &&
        roomId != null &&
        roomId.toString().isNotEmpty &&
        startDate is Timestamp &&
        endDate is Timestamp) {
      await releaseRoomCalendar(
        shopId: shopId,
        roomId: roomId,
        startDate: startDate.toDate(),
        endDate: endDate.toDate(),
      );
    }

    await _returnBookingInventory(
      shopId: (data['shopId'] ?? '').toString(),
      bookingId: bookingId,
    );

    await _firestore.collection('action_logs').add({
      'type': 'booking_cancelled',

      /// 訂單資訊
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': data['shopId'],
      'roomId': data['roomId'],
      'roomName': data['roomName'],
      'roomTypeName': data['roomTypeName'],

      /// 狀態變化
      'fromStatus': status,
      'toStatus': 'cancelled',

      /// 取消資訊
      'cancelReason': cancelReason,
      'cancelBy': cancelBy, // customer / admin / system
      /// 操作者
      'operatorUid': _currentUser?.uid,
      'operatorRole': cancelBy,
      'operatorEmail': _currentUser?.email,

      /// 時間
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ===============================
  /// 🔁 更換房間（預留入住中換房用）
  /// ===============================
  /// 功能：
  /// - 釋放舊房間 room_calendar
  /// - 檢查新房間是否可用
  /// - 鎖定新房間
  /// - 更新 booking 房號
  Future<void> changeAssignedRoom({
    required String bookingId,
    required String shopId,
    required String oldRoomId,
    required String oldRoomName,
    required String newRoomId,
    required String newRoomName,
    required DateTime startDate,
    required DateTime endDate,
    String reason = '',
  }) async {
    final available = await isRoomAvailable(
      shopId: shopId,
      roomId: newRoomId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!available) {
      throw Exception('新房間在該日期區間已被預約');
    }
    if (reason.trim().isEmpty) {
      throw Exception('更換房間請填寫原因');
    }

    await StayBookingFunctionService.instance.manage(
      shopId: shopId,
      bookingId: bookingId,
      action: 'change',
      roomId: newRoomId,
      roomName: newRoomName,
      reason: reason.trim(),
    );
  }

  /// 更新預約狀態
  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await _bookings.doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 確認入住
  ///
  /// 住宿耗材在入住當下依最新晚數與寵物數扣除（僅店家成員）。
  /// 加購庫存已在建立訂單時由 Functions 扣除；
  /// 這裡再嘗試一次，看到 ba_{bookingId}_deduct 即安全 skip。
  Future<void> checkInBooking({required String bookingId}) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _bookings
        .doc(bookingId)
        .get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw Exception('找不到這筆訂單');
    }

    final String shopId = (data['shopId'] ?? '').toString();
    final String status = (data['status'] ?? '').toString();

    if (status == 'cancelled') {
      throw Exception('訂單已取消，無法入住');
    }

    if (shopId.isEmpty) {
      await _bookings.doc(bookingId).update({
        'status': 'checked_in',
        'checkInAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await BookingInventoryFunctionService.instance
        .finalizeBookingAddonInventory(shopId: shopId, bookingId: bookingId);
    await InventoryStockService.instance.consumeBookingSupplies(
      shopId: shopId,
      bookingId: bookingId,
    );

    await _bookings.doc(bookingId).update({
      'status': 'checked_in',
      'checkInAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _afterBookingCreated({
    required String shopId,
    required String bookingId,
  }) async {
    try {
      debugPrint(
        '[BookingSubmit] finalize inventory start bookingId=$bookingId shopId=$shopId',
      );
      await BookingInventoryFunctionService.instance
          .finalizeBookingAddonInventory(shopId: shopId, bookingId: bookingId);
      debugPrint(
        '[BookingSubmit] finalize inventory done bookingId=$bookingId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BookingSubmit] finalize failed: $error bookingId=$bookingId',
      );
      debugPrintStack(stackTrace: stackTrace);

      try {
        await cancelBooking(
          bookingId: bookingId,
          cancelReason: InventoryException.userMessage(error),
          cancelBy: 'system',
        );
        debugPrint('[BookingSubmit] rollback cancelled bookingId=$bookingId');
      } catch (rollbackError, rollbackStack) {
        debugPrint(
          '[BookingSubmit] rollback failed: $rollbackError bookingId=$bookingId',
        );
        debugPrintStack(stackTrace: rollbackStack);
      }

      if (error is InventoryException) {
        rethrow;
      }

      throw InventoryException(InventoryException.userMessage(error));
    }

    final DocumentSnapshot<Map<String, dynamic>> latest = await _bookings
        .doc(bookingId)
        .get();
    final Map<String, dynamic>? latestData = latest.data();
    if ((latestData?['status'] ?? '').toString() == 'cancelled') {
      final String reason = (latestData?['cancelReason'] ?? '此預約無法完成，請重新送出')
          .toString()
          .trim();
      throw InventoryException(reason.isEmpty ? '此預約無法完成，請重新送出' : reason);
    }
  }

  Future<void> _returnBookingInventory({
    required String shopId,
    required String bookingId,
  }) async {
    if (shopId.trim().isEmpty || bookingId.trim().isEmpty) {
      return;
    }

    try {
      await BookingInventoryFunctionService.instance.returnBookingInventory(
        shopId: shopId,
        bookingId: bookingId,
      );
    } catch (error, stackTrace) {
      debugPrint('取消訂單返還庫存失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// ===============================
  /// 🏠 後台分配房間
  /// ===============================
  /// 功能：
  /// - 確認房間區間可用
  /// - 更新 booking 房號
  /// - assignStatus 改為 assigned
  /// - 寫入 room_calendar 鎖房
  Future<void> assignRoomToBooking({
    required String bookingId,
    required String shopId,
    required String roomId,
    required String roomName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bookingDoc = await _bookings.doc(bookingId).get();

    if (!bookingDoc.exists) {
      throw Exception('找不到這筆訂單');
    }

    final bookingData = bookingDoc.data() ?? <String, dynamic>{};
    final bookingStatus = bookingData['status']?.toString() ?? '';

    if (bookingStatus != 'confirmed') {
      throw Exception('此訂單尚未確認，不能進行分房');
    }
    final available = await isRoomAvailable(
      shopId: shopId,
      roomId: roomId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!available) {
      throw Exception('此房間在該日期區間已被預約');
    }

    await StayBookingFunctionService.instance.manage(
      shopId: shopId,
      bookingId: bookingId,
      action: 'assign',
      roomId: roomId,
      roomName: roomName,
    );
  }

  /// 更新預約資料
  Future<void> updateBooking({
    required String bookingId,
    String? customerName,
    String? customerPhone,
    String? petName,
    String? petType,
    String? serviceType,
    DateTime? startDate,
    DateTime? endDate,
    int? nights,
    String? note,
    int? totalPrice,
    int? pricePerNight,
    String? roomId,
    String? roomName,
    bool? cameraAccessEnabled,
    String? cameraUrl,
  }) async {
    final Map<String, dynamic> data = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (customerName != null) data['customerName'] = customerName.trim();
    if (customerPhone != null) data['customerPhone'] = customerPhone.trim();
    if (petName != null) data['petName'] = petName.trim();
    if (petType != null) data['petType'] = petType.trim();
    if (serviceType != null) data['serviceType'] = serviceType;
    if (startDate != null) {
      data['startDate'] = Timestamp.fromDate(_dateOnly(startDate));
    }
    if (endDate != null) {
      data['endDate'] = Timestamp.fromDate(_dateOnly(endDate));
    }
    if (nights != null) data['nights'] = nights;
    if (note != null) data['note'] = note.trim();
    if (totalPrice != null) data['totalPrice'] = totalPrice;
    if (pricePerNight != null) data['pricePerNight'] = pricePerNight;
    if (roomId != null) data['roomId'] = roomId;
    if (roomName != null) data['roomName'] = roomName;
    if (cameraAccessEnabled != null) {
      data['cameraAccessEnabled'] = cameraAccessEnabled;
    }
    if (cameraUrl != null) data['cameraUrl'] = cameraUrl;

    await _bookings.doc(bookingId).update(data);
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return _dateOnly(value.toDate());
    if (value is DateTime) return _dateOnly(value);
    return null;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// ===============================
  /// 🔒 檢查房間在區間是否可用
  /// ===============================
  Future<bool> isRoomAvailable({
    required String shopId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    final DocumentSnapshot<Map<String, dynamic>> roomSnap = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .doc(roomId)
        .get();
    if (!roomSnap.exists) {
      return false;
    }
    if (DaycareOccupancyService.isRoomDocumentUnsellable(<String, dynamic>{
      'id': roomId,
      ...?roomSnap.data(),
    })) {
      return false;
    }

    // ======================
    // 先檢查 room_calendar
    // ======================

    final stayDates = getStayDates(startDate: start, endDate: end);

    for (final date in stayDates) {
      final dateKey = ShopService.instance.formatDateKey(date);

      final calendarDoc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_calendar')
          .doc('${roomId}_$dateKey')
          .get();

      if (calendarDoc.exists) {
        final status = calendarDoc.data()?['status']?.toString() ?? '';

        if (status == 'blocked' ||
            status == 'maintenance' ||
            status == 'closed' ||
            status == 'cleaning' ||
            status == 'unavailable' ||
            status == 'booked' ||
            status == 'checked_in' ||
            status == 'occupied') {
          return false;
        }
      }
    }

    // ======================
    // 再檢查 bookings
    // ======================

    final bookings = await getShopBookings(shopId);

    for (final booking in bookings) {
      final status = booking['status']?.toString() ?? '';

      if (status == 'cancelled' || status == 'completed') continue;

      if (booking['roomId'] != roomId) continue;

      if (BookingKind.isDaycare(booking)) {
        if (!DaycareOccupancyService.occupiesInventory(booking)) {
          continue;
        }
        final DateTime? otherStart = _timestampToDate(
          booking['scheduledStartAt'],
        );
        final DateTime? otherEnd = _timestampToDate(
          booking['scheduledEndAt'],
        );
        if (otherStart == null || otherEnd == null) {
          continue;
        }
        for (final DateTime date in stayDates) {
          final DateTime slotStart = DateTime(date.year, date.month, date.day);
          final DateTime slotEnd = slotStart.add(const Duration(days: 1));
          if (DaycareTimeHelper.overlaps(
            slotStart,
            slotEnd,
            otherStart,
            otherEnd,
          )) {
            return false;
          }
        }
        continue;
      }

      final bStart = _timestampToDate(booking['startDate']);
      final bEnd = _timestampToDate(booking['endDate']);

      if (bStart == null || bEnd == null) continue;

      final overlap = start.isBefore(bEnd) && end.isAfter(bStart);

      if (overlap) {
        return false;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> occSnap = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('room_occupancies')
        .where('roomId', isEqualTo: roomId)
        .where('status', isEqualTo: 'active')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in occSnap.docs) {
      final Map<String, dynamic> occ = doc.data();
      final DateTime? occStart = _timestampToDate(occ['startAt']);
      final DateTime? occEnd = _timestampToDate(occ['endAt']);
      if (occStart == null || occEnd == null) {
        continue;
      }
      for (final DateTime date in stayDates) {
        final DateTime slotStart = DateTime(date.year, date.month, date.day);
        final DateTime slotEnd = slotStart.add(const Duration(days: 1));
        if ((occ['occupancyMode'] ?? 'slot').toString() == 'full_day') {
          if (DaycareOccupancyService.dateKeyOf(occStart) ==
              ShopService.instance.formatDateKey(date)) {
            return false;
          }
        } else if (DaycareTimeHelper.overlaps(
          slotStart,
          slotEnd,
          occStart,
          occEnd,
        )) {
          return false;
        }
      }
    }

    final String roomTypeId =
        (roomSnap.data()?['roomTypeId'] ?? '').toString().trim();
    if (roomTypeId.isNotEmpty) {
      final QuerySnapshot<Map<String, dynamic>> roomTypeSnap = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('rooms')
          .where('roomTypeId', isEqualTo: roomTypeId)
          .get();
      final List<Map<String, dynamic>> typeRooms = roomTypeSnap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                <String, dynamic>{'id': doc.id, ...doc.data()},
          )
          .toList();
      final QuerySnapshot<Map<String, dynamic>> typeOccSnap = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_occupancies')
          .where('status', isEqualTo: 'active')
          .get();
      final List<Map<String, dynamic>> occupancies = typeOccSnap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.data(),
          )
          .toList();
      final List<Map<String, dynamic>> bookingMaps = bookings
          .map(
            (Map<String, dynamic> booking) => <String, dynamic>{
              'id': (booking['bookingId'] ?? booking['id'] ?? '').toString(),
              ...booking,
            },
          )
          .toList();
      for (final DateTime date in stayDates) {
        final String dateKey = ShopService.instance.formatDateKey(date);
        if (bookingMaps.every((Map<String, dynamic> booking) {
          if (!BookingKind.isDaycare(booking)) {
            return true;
          }
          if (!DaycareOccupancyService.occupiesInventory(booking)) {
            return true;
          }
          if ((booking['roomId'] ?? '').toString().trim().isNotEmpty) {
            return true;
          }
          final String held =
              ((booking['requestedRoomTypeId'] ??
                          booking['roomTypeId'] ??
                          '')
                      .toString())
                  .trim();
          return held != roomTypeId;
        })) {
          continue;
        }
        final List<Map<String, dynamic>> calendarEntries =
            <Map<String, dynamic>>[
              <String, dynamic>{
                'roomId': roomId,
                'date': dateKey,
                'status': 'booked',
              },
            ];
        final DateTime slotStart = DateTime(date.year, date.month, date.day, 0);
        final DateTime slotEnd = DateTime(date.year, date.month, date.day, 23, 59);
        final DaycareRoomRemaining computed =
            DaycareOccupancyService.remainingRoomsResultFromData(
              rooms: typeRooms,
              bookings: bookingMaps,
              occupancies: occupancies,
              calendarEntries: calendarEntries,
              roomTypeId: roomTypeId,
              startAt: slotStart,
              endAt: slotEnd,
              dateKey: dateKey,
            );
        if (computed.oversold) {
          return false;
        }
      }
    }

    return true;
  }

  /// ===============================
  /// 🔒 將房間寫入日曆（鎖房）
  /// ===============================
  Future<void> blockRoomCalendar({
    required String shopId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final stayDates = getStayDates(startDate: startDate, endDate: endDate);

    final batch = _firestore.batch();

    for (final date in stayDates) {
      final dateKey = ShopService.instance.formatDateKey(date);

      final docRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_calendar')
          .doc('${roomId}_$dateKey');

      batch.set(docRef, {
        'roomId': roomId,
        'date': dateKey,
        'status': 'booked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// ===============================
  /// 🔓 釋放房間（取消訂單）
  /// ===============================
  Future<void> releaseRoomCalendar({
    required String shopId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final stayDates = getStayDates(startDate: startDate, endDate: endDate);

    final batch = _firestore.batch();

    for (final date in stayDates) {
      final dateKey = ShopService.instance.formatDateKey(date);

      final docRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_calendar')
          .doc('${roomId}_$dateKey');

      batch.delete(docRef); // 🔥 直接刪掉
    }

    await batch.commit();
  }

  /// ===============================
  /// 📅 取得入住日期區間
  /// ===============================
  List<DateTime> getStayDates({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    final List<DateTime> result = [];

    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      result.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    return result;
  }

  /// ===============================
  /// 🌙 計算晚數
  /// ===============================
  int calculateNights({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    return end.difference(start).inDays;
  }

  /// ===============================
  /// 💰 計算總價
  /// ===============================
  int calculateTotalPrice({
    required Map<String, dynamic> roomType,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final stayDates = getStayDates(startDate: startDate, endDate: endDate);

    final pricePerNight = _toInt(roomType['price']);

    return stayDates.length * pricePerNight;
  }

  /// ===============================
  /// 🔍 找可用房間（自動分配）
  /// ===============================
  Future<Map<String, dynamic>?> findAvailableRoom({
    required String shopId,
    required String roomTypeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final roomsSnapshot = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .where('roomTypeId', isEqualTo: roomTypeId)
        .get();

    for (final roomDoc in roomsSnapshot.docs) {
      if (DaycareOccupancyService.isRoomDocumentUnsellable(<String, dynamic>{
        'id': roomDoc.id,
        ...roomDoc.data(),
      })) {
        continue;
      }
      final roomId = roomDoc.id;
      final available = await isRoomAvailable(
        shopId: shopId,
        roomId: roomId,
        startDate: startDate,
        endDate: endDate,
      );

      if (available) {
        return {'id': roomId, ...roomDoc.data()};
      }
    }

    return null;
  }

  /// 🔥 計算某一天被佔用幾間房
  Future<int> countRoomsByDate({
    required String shopId,
    required String date,
  }) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final start = (data['startDate'] as Timestamp).toDate();
      final end = (data['endDate'] as Timestamp).toDate();

      DateTime cursor = DateTime(start.year, start.month, start.day);

      while (!cursor.isAfter(end.subtract(const Duration(days: 1)))) {
        final key = _formatDateKey(cursor);

        if (key == date) {
          count++;
          break;
        }

        cursor = cursor.add(const Duration(days: 1));
      }
    }

    return count;
  }

  /// 日期轉 key（yyyy-MM-dd）
  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
