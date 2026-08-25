// lib/features/shop/widgets/booking/booking_submit_helper.dart
// 🧾 前台預約送出 Helper
// 功能：建立店家會員、防重複預約、防刷訂單、回寫會員資料、建立 booking

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/member_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

class BookingSubmitHelper {
  BookingSubmitHelper._();

  static Future<void> checkDuplicatePetBooking({
    required String shopId,
    required List<String> selectedPetIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (selectedPetIds.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
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
  }) async {
    await MemberService.instance.ensureMember(
      shopId: shopId,
      name: customerName,
      phone: customerPhone,
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('請先登入');
    }

    await checkDuplicatePetBooking(
      shopId: shopId,
      selectedPetIds: selectedPetIds,
      startDate: startDate,
      endDate: endDate,
    );

    await checkTooManyOpenBookings(shopId: shopId, userId: user.uid);

    await FirebaseFirestore.instance
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
        }, SetOptions(merge: true));

    await ShopPolicyService.instance.acceptPolicy(
      shopId: shopId,
      userId: user.uid,
    );

    final policyAcceptanceDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('policy_acceptances')
        .doc(shopId)
        .get();

    final policyAcceptance = policyAcceptanceDoc.data() ?? {};

    final rawPolicyVersion = policyAcceptance['acceptedVersion'];

    final int policyVersion = rawPolicyVersion is int
        ? rawPolicyVersion
        : int.tryParse(rawPolicyVersion?.toString() ?? '') ?? 0;

    final policyTitle = '入住須知';

    final Timestamp? policyAcceptedAt =
        policyAcceptance['acceptedAt'] is Timestamp
        ? policyAcceptance['acceptedAt'] as Timestamp
        : null;

    final basePrice = (selectedRoomType['price'] ?? 0).toInt();
    final petCount = selectedPetIds.length;
    final extraPrice = (selectedRoomType['extraPrice'] ?? 0).toInt();
    final extraPetCount = petCount > 1 ? petCount - 1 : 0;
    final extraPetTotal = (extraPetCount * extraPrice * nights).toInt();
    final int roomSubtotal =
        (basePrice * nights) + extraPetTotal + specialDateSurchargeAmount;
    final pricePerNight = nights > 0 ? (totalPrice ~/ nights) : 0;

    final bookingId = await BookingService.instance.createBooking(
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
          .map(
            (p) => {
              'photoUrl': p['photoUrl'],
              'name': p['name'],
              'breed': p['breed'] ?? p['type'],
              'age': p['age'],
              'gender': p['gender'],
              'isNeutered': p['isNeutered'],
              'medicalStatus': p['medicalStatus'],
              'litterType': p['litterType'],
              'note': p['note'],
            },
          )
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
      depositAmount: depositAmount,
      paymentMethod: paymentMethod,
      payAmountType: payAmountType,
      addons: addons,
      policyVersion: policyVersion,
      policyTitle: policyTitle,
      policyAcceptedAt: policyAcceptedAt,

      /// 🔒 傳入固定訂單文件 ID，避免同一請求重送建立兩筆
      requestId: requestId,
    );

    final String normalizedCouponId = couponId.trim();

    if (normalizedCouponId.isNotEmpty) {
      try {
        await MemberCouponService.instance.reserveCoupon(
          shopId: shopId,
          couponId: normalizedCouponId,
          userId: user.uid,
          bookingId: bookingId,
        );
      } catch (error) {
        // 優惠券保留失敗時，不直接刪除訂單。
        //
        // 一般會員沒有刪除 Booking 的權限，
        // 若呼叫 delete()，會蓋掉原本真正的錯誤，
        // 最後前端只會看到 permission-denied。
        //
        // 改成將剛建立的訂單標記為取消，
        // 避免訂單繼續占用房間與住宿日期。
        try {
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .update({
                'status': 'cancelled',
                'cancelReason': '優惠券保留失敗，系統自動取消訂單',
                'cancelBy': 'system',
                'cancelledAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {
          // 回復訂單失敗時，不覆蓋原本的優惠券錯誤。
        }

        rethrow;
      }
    }
    final bookingCountSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: user.uid)
        .get();

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(user.uid)
        .set({
          // 第一次建立會員快取時，Firestore Rules 必須驗證這些欄位。
          'userId': user.uid,
          'blacklisted': false,
          'isBlocked': false,

          // 預約與會員統計資料。
          'bookingCount': bookingCountSnap.docs.length,
          'petCount': selectedPetIds.length,
          'policyAccepted': policyVersion > 0,
          'policyVersion': policyVersion,
          'policyTitle': policyTitle,
          'policyAcceptedAt': policyAcceptedAt,
          'policyAcceptedFrom': 'customer',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    return bookingId;
  }
}
