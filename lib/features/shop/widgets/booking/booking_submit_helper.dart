// lib/features/shop/widgets/booking/booking_submit_helper.dart
// 🧾 前台預約送出 Helper
// 功能：建立店家會員、防重複預約、防刷訂單、回寫會員資料、建立 booking

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/member_service.dart';

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
  }) async {
    await MemberService.instance.ensureMember(shopId: shopId);

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

    final basePrice = (selectedRoomType['price'] ?? 0).toInt();
    final petCount = selectedPetIds.length;
    final extraPrice = (selectedRoomType['extraPrice'] ?? 0).toInt();
    final extraPetCount = petCount > 1 ? petCount - 1 : 0;
    final extraPetTotal = (extraPetCount * extraPrice * nights).toInt();
    final roomSubtotal = basePrice + extraPetTotal;
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
      depositAmount: depositAmount,
      paymentMethod: paymentMethod,
      payAmountType: payAmountType,
      addons: addons,
    );

    await BookingService.instance.updateBooking(
      bookingId: bookingId,
      totalPrice: totalPrice,
      pricePerNight: pricePerNight,
    );

    return bookingId;
  }
}
