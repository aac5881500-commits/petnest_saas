// lib/features/shop/widgets/booking/front_calendar_helper.dart
// 🔥 前台預約月曆 helper：查詢月曆價格、關閉日、滿房日與剩餘房數

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';

class FrontCalendarHelper {
  static Future<FrontCalendarPayload> buildPayload({
    required String shopId,
    required Map<String, dynamic> shop,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    if (kDebugMode) {
      print('🔥 抓資料了：$firstDate ~ $lastDate');
    }

    final blockedDateKeys = List<String>.from(shop['blockedDates'] ?? [])
        .map((e) => e.toString())
        .toSet();

    final Map<String, String> blockedDateReasons =
        Map<String, dynamic>.from(shop['blockedDateReasons'] ?? {}).map(
      (key, value) => MapEntry(key, value.toString()),
    );

    final Map<String, int> priceMap = {};
    final Map<String, int> remainingRoomsMap = {};
    final Set<String> unbookableDateKeys = {};

    final roomsSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .where('enabled', isEqualTo: true)
        .get();

    final totalRooms = roomsSnapshot.docs.length;

    final calendarSnapshot = await FirebaseFirestore.instance
    .collection('shops')
    .doc(shopId)
    .collection('room_calendar')
    .get();

final blockedRoomDateSet = <String>{};

for (final doc in calendarSnapshot.docs) {
  final data = doc.data();

  if (data['status'] != 'blocked') continue;

  final roomId = (data['roomId'] ?? '').toString();
  final date = (data['date'] ?? '').toString();

  if (roomId.isEmpty || date.isEmpty) continue;

  blockedRoomDateSet.add('$roomId|$date');
}

    DateTime cursor = DateTime(
      firstDate.year,
      firstDate.month,
      firstDate.day,
    );

    final last = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );

    final monthStart = DateTime(
      firstDate.year,
      firstDate.month,
      firstDate.day,
    );

    final monthEnd = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shop['shopId'])
        .where('status', whereIn: ['pending', 'confirmed'])
        .where(
          'startDate',
          isLessThanOrEqualTo: Timestamp.fromDate(monthEnd),
        )
        .get();

    final bookings = snapshot.docs
        .map((doc) {
          final data = doc.data();

          final start = (data['startDate'] as Timestamp).toDate();
          final end = (data['endDate'] as Timestamp).toDate();

          if (end.isBefore(monthStart) || start.isAfter(monthEnd)) {
            return null;
          }

          return data;
        })
        .where((e) => e != null)
        .cast<Map<String, dynamic>>()
        .toList();

    while (!cursor.isAfter(last)) {
      final key = ShopService.instance.formatDateKey(cursor);

      priceMap[key] = ShopService.instance.getPriceForDate(
        shop,
        cursor,
      );

      int occupied = 0;

      int blockedRooms = 0;

for (final roomDoc in roomsSnapshot.docs) {
  final roomId = roomDoc.id;

  if (blockedRoomDateSet.contains('$roomId|$key')) {
    blockedRooms++;
  }
}

      for (final booking in bookings) {
        final start = (booking['startDate'] as Timestamp).toDate();
        final end = (booking['endDate'] as Timestamp).toDate();

        if (end.isBefore(monthStart) || start.isAfter(monthEnd)) {
          continue;
        }

        DateTime temp = DateTime(
          start.year,
          start.month,
          start.day,
        );

        while (!temp.isAfter(end.subtract(const Duration(days: 1)))) {
          final dKey = ShopService.instance.formatDateKey(temp);

          if (dKey == key) {
            occupied++;
            break;
          }

          temp = temp.add(const Duration(days: 1));
        }
      }

      final remaining = totalRooms - occupied - blockedRooms;

      remainingRoomsMap[key] = remaining;

      if (remaining <= 0) {
        unbookableDateKeys.add(key);
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    return FrontCalendarPayload(
      blockedDateKeys: blockedDateKeys,
      blockedDateReasons: blockedDateReasons,
      unbookableDateKeys: unbookableDateKeys,
      priceMap: priceMap,
      remainingRoomsMap: remainingRoomsMap,
    );
  }
}