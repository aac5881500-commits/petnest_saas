// 檔案名稱：lib/features/shop/widgets/booking/booking_submit_helper.dart
// 功能說明：建立店家會員、防重複預約、防刷訂單、回寫會員資料、建立 booking
// 🧾 前台預約送出 Helper

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/member_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/stay_booking_function_service.dart';

/// 前台住宿送出失敗。訊息已轉成顧客可讀文字，並標明停在哪個階段。
class BookingSubmitException implements Exception {
  const BookingSubmitException({
    required this.message,
    required this.stage,
    required this.operation,
    this.firebaseCode = '',
    this.bookingCreated = false,
    this.keepRequestId = false,
  });

  final String message;
  final String stage;
  final String operation;
  final String firebaseCode;

  /// 住宿訂單文件已經存在。
  final bool bookingCreated;

  /// 訂單仍有效時，重試必須沿用同一個 requestId，避免再建立一筆。
  final bool keepRequestId;

  @override
  String toString() => message;
}

class BookingSubmitHelper {
  BookingSubmitHelper._();

  static bool isEcpayPayment(String paymentMethod) {
    return paymentMethod == 'credit_card' ||
        paymentMethod == 'atm' ||
        paymentMethod == 'cvs_code';
  }

  /// 與 firestore.rules 裡顧客更新 shops/{shopId}/members/{uid} 的 hasOnly 清單一致。
  static const Set<String> customerMemberUpdateKeys = <String>{
    'email',
    'name',
    'phone',
    'address',
    'emergencyContact',
    'petCount',
    'bookingCount',
    'updatedAt',
    'lastLoginAt',
    'lastBookingAt',
    'avatarUrl',
    'avatarStoragePath',
    'policyAccepted',
    'policyVersion',
    'policyTitle',
    'policyAcceptedAt',
    'policyAcceptedFrom',
  };

  /// 訂單成立後回寫會員快取。只含顧客有權更新的欄位。
  static Map<String, dynamic> customerBookingMemberPatch({
    required int bookingCount,
    required int petCount,
    required int policyVersion,
    required String policyTitle,
    Object? policyAcceptedAt,
  }) {
    return <String, dynamic>{
      'bookingCount': bookingCount,
      'petCount': petCount,
      'policyAccepted': policyVersion > 0,
      'policyVersion': policyVersion,
      'policyTitle': policyTitle,
      'policyAcceptedFrom': 'customer',
      'policyAcceptedAt': ?policyAcceptedAt,
    };
  }

  /// 已取消的訂單可以換新 requestId；仍有效的訂單必須沿用原 ID。
  static bool shouldKeepBookingRequestId({
    required bool bookingExists,
    required String status,
    required bool cancelledAtPresent,
  }) {
    if (!bookingExists) {
      return false;
    }
    if (status == 'cancelled' || cancelledAtPresent) {
      return false;
    }
    return true;
  }

  static void logStageFailure({
    required String stage,
    required String operation,
    required Object error,
    String firebaseCode = '',
  }) {
    final String code = firebaseCode.isNotEmpty
        ? firebaseCode
        : _firebaseCodeOf(error);
    debugPrint(
      '[BookingSubmit] stage=$stage operation=$operation firebaseCode=$code',
    );
  }

  static String userFacingSubmitMessage({
    required String stage,
    required Object error,
    bool bookingStillActive = false,
  }) {
    if (error is BookingSubmitException) {
      return error.message;
    }

    final String raw = _plainMessage(error);
    if (stage == 'addon_inventory') {
      if (raw.isNotEmpty && !_isTechnicalMessage(raw)) {
        return raw;
      }
      if (bookingStillActive) {
        return '加購商品處理失敗，請重新確認。';
      }
      return '加購商品處理失敗，這次預約未成立，請重新確認。';
    }

    if (raw.isNotEmpty && !_isTechnicalMessage(raw)) {
      return raw;
    }

    return '預約送出失敗，請稍後再試。';
  }

  static String _firebaseCodeOf(Object error) {
    if (error is FirebaseException) {
      return error.code;
    }
    if (error is BookingSubmitException) {
      return error.firebaseCode;
    }
    return '';
  }

  static String _plainMessage(Object error) {
    if (error is InventoryException ||
        error is StayBookingFunctionException ||
        error is BookingSubmitException) {
      return error.toString().trim();
    }
    if (error is FirebaseException) {
      return '';
    }

    var text = error.toString().trim();
    const List<String> prefixes = <String>[
      'Exception: ',
      'Bad state: ',
      'Invalid argument(s): ',
    ];
    for (final String prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }
    return text;
  }

  static bool _isTechnicalMessage(String text) {
    final String lower = text.toLowerCase();
    return lower.contains('permission-denied') ||
        lower.contains('firebase') ||
        lower.contains('exception') ||
        lower.contains('cloud_firestore') ||
        text.contains('沒有權限執行此庫存操作');
  }

  static Future<bool> _activeBookingExists(String requestId) async {
    final String id = requestId.trim();
    if (id.isEmpty) {
      return false;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance.collection('bookings').doc(id).get();
      final Map<String, dynamic>? data = snap.data();
      return shouldKeepBookingRequestId(
        bookingExists: snap.exists,
        status: (data?['status'] ?? '').toString(),
        cancelledAtPresent: data?['cancelledAt'] != null,
      );
    } catch (error) {
      logStageFailure(
        stage: 'booking_status',
        operation: 'bookings.get',
        error: error,
      );
      return true;
    }
  }

  static Future<T> _runStage<T>({
    required String stage,
    required String operation,
    required String requestId,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      logStageFailure(stage: stage, operation: operation, error: error);
      if (error is BookingSubmitException) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      final bool keep = await _activeBookingExists(requestId);
      final bool addonFailure =
          stage == 'create_booking' &&
          error is InventoryException &&
          error.message != '此預約無法完成，請重新送出';
      final String resolvedStage = addonFailure ? 'addon_inventory' : stage;
      Error.throwWithStackTrace(
        BookingSubmitException(
          message: userFacingSubmitMessage(
            stage: resolvedStage,
            error: error,
            bookingStillActive: keep,
          ),
          stage: resolvedStage,
          operation: addonFailure ? 'finalizeBookingAddonInventory' : operation,
          firebaseCode: _firebaseCodeOf(error),
          bookingCreated: keep,
          keepRequestId: keep,
        ),
        stackTrace,
      );
    }
  }

  static Future<void> checkDuplicatePetBooking({
    required String shopId,
    required List<String> selectedPetIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (selectedPetIds.isEmpty) return;

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: uid)
        .where('petIds', arrayContainsAny: selectedPetIds)
        .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final bookedPetIds = List<String>.from(data['petIds'] ?? []);

      final bookedStart = (data['startDate'] as Timestamp).toDate();

      final bookedEnd = (data['endDate'] as Timestamp).toDate();

      final selectedPetIdSet = selectedPetIds.map((e) => e.toString()).toSet();

      final bookedPetIdSet = bookedPetIds.map((e) => e.toString()).toSet();

      final hasSamePet = selectedPetIdSet.any(
        (id) => bookedPetIdSet.contains(id),
      );

      final newStart = DateTime(startDate.year, startDate.month, startDate.day);

      final newEnd = DateTime(endDate.year, endDate.month, endDate.day);

      final oldStart = DateTime(
        bookedStart.year,
        bookedStart.month,
        bookedStart.day,
      );

      final oldEnd = DateTime(bookedEnd.year, bookedEnd.month, bookedEnd.day);

      final isOverlap = newStart.isBefore(oldEnd) && newEnd.isAfter(oldStart);

      if (hasSamePet && isOverlap) {
        throw Exception('該寵物在此日期已有預約，請重新選擇日期或寵物');
      }
    }
  }

  static Future<void> checkTooManyOpenBookings({
    required String shopId,
    required String userId,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
        .get();

    if (snapshot.docs.length >= 3) {
      throw Exception('您已有多筆未完成訂單，請先完成或取消後再預約');
    }
  }

  static Future<String> submitBooking({
    required String shopId,
    required String customerName,
    required String customerPhone,
    required List<String> selectedPetIds,
    required List<Map<String, dynamic>> pets,
    required Map<String, dynamic> selectedRoomType,
    required String selectedServiceType,
    required DateTime startDate,
    required DateTime endDate,
    required int nights,
    required String note,
    required int totalPrice,
    required int originalTotal,
    int specialDateSurchargeAmount = 0,
    List<Map<String, dynamic>> specialDateSurchargeDetails =
        const <Map<String, dynamic>>[],
    required int discountAmount,
    required int discountUsedNights,
    required int discountPercent,
    required int discountMinNights,
    required String discountBase,
    required String discountCampaignId,
    required String discountCampaignName,
    required String discountCampaignDescription,
    required String discountCampaignType,
    required String discountValueType,
    required num discountValue,
    required bool allowCouponTogether,
    required String couponId,
    required String couponName,
    required String couponType,
    required int couponDiscountAmount,
    int requestedPoints = 0,
    required List<Map<String, dynamic>> addons,
    required String address,
    required String emergencyName,
    required String emergencyPhone,
    required String relation,
    required String emergencyAddress,
    required String phone2,
    required int depositAmount,
    required String paymentMethod,
    required String payAmountType,

    /// 🔒 同一次前台送出請求的唯一識別碼
    required String requestId,
    TermsConsentSnapshot? termsConsent,
    CustomFormAnswerSnapshot? customFormAnswers,
    Map<String, dynamic> petFormAnswersByPetId = const <String, dynamic>{},
    Map<String, dynamic>? dailyCareEntitlement,
  }) async {
    await _runStage<void>(
      stage: 'ensure_member',
      operation: 'MemberService.ensureMember',
      requestId: requestId,
      action: () => MemberService.instance.ensureMember(
        shopId: shopId,
        name: customerName,
        phone: customerPhone,
      ),
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const BookingSubmitException(
        message: '請先登入',
        stage: 'auth',
        operation: 'FirebaseAuth.currentUser',
      );
    }

    await _runStage<void>(
      stage: 'duplicate_booking',
      operation: 'bookings.duplicateCheck',
      requestId: requestId,
      action: () => checkDuplicatePetBooking(
        shopId: shopId,
        selectedPetIds: selectedPetIds,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    await _runStage<void>(
      stage: 'open_booking_limit',
      operation: 'bookings.openBookingCheck',
      requestId: requestId,
      action: () =>
          checkTooManyOpenBookings(shopId: shopId, userId: user.uid),
    );

    await _runStage<void>(
      stage: 'profile_sync',
      operation: 'user_profiles.set',
      requestId: requestId,
      action: () => FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .set({
            'name': customerName,
            'phone': customerPhone,
            'address': address,
            'emergencyContact': {
              'name': emergencyName,
              'phone': emergencyPhone,
              'relation': relation,
              'address': emergencyAddress,
              'phone2': phone2,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
    );

    final TermsConsentSnapshot resolvedConsent;
    if (termsConsent != null && termsConsent.termsVersion >= 0) {
      resolvedConsent = termsConsent;
    } else {
      resolvedConsent = await _runStage<TermsConsentSnapshot>(
        stage: 'terms_confirm',
        operation: 'ShopPolicyService.confirmTerms',
        requestId: requestId,
        action: () => ShopPolicyService.instance.confirmTerms(
          shopId: shopId,
          userId: user.uid,
          serviceType: PolicyApplicableService.accommodation,
        ),
      );
    }

    final int policyVersion = resolvedConsent.termsVersion;
    final String policyTitle = resolvedConsent.termsTitle;
    final Timestamp? policyAcceptedAt = resolvedConsent.termsAcceptedAt == null
        ? null
        : Timestamp.fromDate(resolvedConsent.termsAcceptedAt!);

    final basePrice = (selectedRoomType['price'] ?? 0).toInt();
    final petCount = selectedPetIds.length;
    final extraPrice = (selectedRoomType['extraPrice'] ?? 0).toInt();
    final extraPetCount = petCount > 1 ? petCount - 1 : 0;
    final extraPetTotal = (extraPetCount * extraPrice * nights).toInt();
    final int roomSubtotal =
        (basePrice * nights) + extraPetTotal + specialDateSurchargeAmount;

    final bookingId = await _runStage<String>(
      stage: 'create_booking',
      operation: 'BookingService.createBooking',
      requestId: requestId,
      action: () => BookingService.instance.createBooking(
      shopId: shopId,
      customerName: customerName,
      customerPhone: customerPhone,
      petIds: selectedPetIds,
      basePrice: basePrice,
      extraPetPrice: extraPrice,
      extraPetCount: extraPetCount,
      extraPetTotal: extraPetTotal,
      roomSubtotal: roomSubtotal,
      roomImages: selectedRoomType['images'] ?? [],
      pets: pets
          .where((p) => selectedPetIds.contains(p['petId']))
          .map(PetSnapshot.fromPet)
          .toList(),
      serviceType: selectedServiceType,
      roomId: selectedRoomType['roomTypeId'],
      roomName: selectedRoomType['name'],
      roomTypeName: selectedRoomType['name'],
      startDate: startDate,
      endDate: endDate,
      nights: nights,
      note: note,
      address: address,
      emergencyName: emergencyName,
      emergencyPhone: emergencyPhone,
      emergencyRelation: relation,
      emergencyAddress: emergencyAddress,
      emergencyPhone2: phone2,
      totalPrice: totalPrice,
      originalTotal: originalTotal,
      specialDateSurchargeAmount: specialDateSurchargeAmount,
      specialDateSurchargeDetails: specialDateSurchargeDetails,
      discountAmount: discountAmount,
      discountUsedNights: discountUsedNights,
      discountPercent: discountPercent,
      discountMinNights: discountMinNights,
      discountBase: discountBase,
      discountCampaignId: discountCampaignId,
      discountCampaignName: discountCampaignName,
      discountCampaignDescription: discountCampaignDescription,
      discountCampaignType: discountCampaignType,
      discountValueType: discountValueType,
      discountValue: discountValue,
      allowCouponTogether: allowCouponTogether,
      couponId: couponId,
      couponName: couponName,
      couponType: couponType,
      couponDiscountAmount: couponDiscountAmount,
      requestedPoints: requestedPoints,
      depositAmount: depositAmount,
      paymentMethod: paymentMethod,
      payAmountType: payAmountType,
      addons: addons,
      dailyCareEntitlement: dailyCareEntitlement,
      policyVersion: policyVersion,
      policyTitle: policyTitle,
      policyAcceptedAt: policyAcceptedAt,
      termsConsent: resolvedConsent,

      /// 🔒 傳入固定訂單文件 ID，避免同一請求重送建立兩筆
      requestId: requestId,
      customFormAnswers: customFormAnswers?.toCallableMap(),
      petFormAnswersByPetId: petFormAnswersByPetId.isEmpty
          ? null
          : petFormAnswersByPetId,
      ),
    );

    final String normalizedCouponId = couponId.trim();

    if (normalizedCouponId.isNotEmpty) {
      debugPrint('[BookingSubmit] start reserve coupon');
      await _runStage<void>(
        stage: 'reserve_coupon',
        operation: 'MemberCouponService.reserveCoupon',
        requestId: requestId,
        action: () async {
          try {
            await MemberCouponService.instance.reserveCoupon(
              shopId: shopId,
              couponId: normalizedCouponId,
              userId: user.uid,
              bookingId: bookingId,
            );
          } catch (error) {
            // 優惠券保留失敗時，不直接刪除訂單。
            // 一般會員沒有刪除 Booking 的權限。
            // 改成取消剛建立的訂單，避免繼續占用住宿日期。
            // 取消失敗時保留原錯誤，並由外層沿用同一個 requestId。
            try {
              await BookingService.instance.cancelBooking(
                bookingId: bookingId,
                cancelReason: '優惠券保留失敗，系統自動取消訂單',
                cancelBy: 'system',
              );
            } catch (cancelError) {
              logStageFailure(
                stage: 'reserve_coupon',
                operation: 'BookingService.cancelBooking',
                error: cancelError,
              );
            }
            rethrow;
          }
        },
      );
    }

    try {
      final bookingCountSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where('userId', isEqualTo: user.uid)
          .get();

      final Map<String, dynamic> memberPatch = customerBookingMemberPatch(
        bookingCount: bookingCountSnap.docs.length,
        petCount: selectedPetIds.length,
        policyVersion: policyVersion,
        policyTitle: policyTitle,
        policyAcceptedAt: policyAcceptedAt,
      );
      memberPatch['updatedAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(user.uid)
          .set(memberPatch, SetOptions(merge: true));
    } catch (error) {
      // 條款同意已寫入 policy_acceptances，並隨訂單送進 Cloud Function。
      // 會員快取只是附帶統計。訂單已成立時，不得把預約顯示成失敗。
      logStageFailure(
        stage: 'member_sync',
        operation: 'shops.members.mergeCustomerStats',
        error: error,
      );
      debugPrint('[BookingSubmit] member_sync kept bookingId=$bookingId');
    }

    return bookingId;
  }
}
