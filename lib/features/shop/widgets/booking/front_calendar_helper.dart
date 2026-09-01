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
    Set<int> extraClosedWeekdays = const <int>{},
    String extraClosedReason = '未開放',
    bool markFullRoomsUnbookable = true,
    Set<String> extraClosedDateKeys = const <String>{},
    Set<String> extraOpenDateKeys = const <String>{},
    Set<String> extraFullDateKeys = const <String>{},
    Set<String> specialOpenDateKeys = const <String>{},
    Map<String, int> remainingPetsMap = const <String, int>{},
  }) async {
    if (kDebugMode) {
      print('🔥 抓資料了：$firstDate ~ $lastDate');
    }

    final blockedDateKeys = List<String>.from(
      shop['blockedDates'] ?? [],
    ).map((e) => e.toString()).toSet();

    final Map<String, String> blockedDateReasons = Map<String, dynamic>.from(
      shop['blockedDateReasons'] ?? {},
    ).map((key, value) => MapEntry(key, value.toString()));

    final Map<String, int> priceMap = {};
    final Map<String, int> remainingRoomsMap = {};
    final Set<String> unbookableDateKeys = {};

    final roomsSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .where('enabled', isEqualTo: true)
        .get();

    // 🔥 依房型統計可用房間數
    final Map<String, int> totalRoomsByRoomType = {};

    for (final roomDoc in roomsSnapshot.docs) {
      final room = roomDoc.data();
      final roomTypeId = (room['roomTypeId'] ?? '').toString();

      if (roomTypeId.isEmpty) continue;

      totalRoomsByRoomType[roomTypeId] =
          (totalRoomsByRoomType[roomTypeId] ?? 0) + 1;
    }

    final calendarSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('room_calendar')
        .get();

    final unavailableRoomDateSet = <String>{};

    for (final doc in calendarSnapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString();

      if (status != 'blocked' && status != 'cleaning') {
        continue;
      }

      final roomId = (data['roomId'] ?? '').toString();
      final date = (data['date'] ?? '').toString();

      if (roomId.isEmpty || date.isEmpty) continue;

      unavailableRoomDateSet.add('$roomId|$date');
    }

    DateTime cursor = DateTime(firstDate.year, firstDate.month, firstDate.day);

    final last = DateTime(lastDate.year, lastDate.month, lastDate.day);

    final occupiedRoomDateSet = <String>{};

    for (final doc in calendarSnapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString();

      if (status != 'booked' && status != 'checked_in') continue;

      final roomId = (data['roomId'] ?? '').toString();
      final date = (data['date'] ?? '').toString();

      if (roomId.isEmpty || date.isEmpty) continue;

      occupiedRoomDateSet.add('$roomId|$date');
    }

    while (!cursor.isAfter(last)) {
      final key = ShopService.instance.formatDateKey(cursor);

      priceMap[key] = ShopService.instance.getPriceForDate(shop, cursor);

      final Map<String, int> occupiedByRoomType = {};
      final Map<String, int> blockedRoomsByRoomType = {};

      for (final roomDoc in roomsSnapshot.docs) {
        final roomId = roomDoc.id;
        final room = roomDoc.data();
        final roomTypeId = (room['roomTypeId'] ?? '').toString();

        if (roomTypeId.isEmpty) continue;

        if (unavailableRoomDateSet.contains('$roomId|$key')) {
          blockedRoomsByRoomType[roomTypeId] =
              (blockedRoomsByRoomType[roomTypeId] ?? 0) + 1;
        }
      }
      for (final roomDoc in roomsSnapshot.docs) {
        final roomId = roomDoc.id;
        final room = roomDoc.data();
        final roomTypeId = (room['roomTypeId'] ?? '').toString();

        if (roomTypeId.isEmpty) continue;

        if (occupiedRoomDateSet.contains('$roomId|$key')) {
          occupiedByRoomType[roomTypeId] =
              (occupiedByRoomType[roomTypeId] ?? 0) + 1;
        }
      }

      int totalRemaining = 0;

      for (final entry in totalRoomsByRoomType.entries) {
        final roomTypeId = entry.key;
        final total = entry.value;

        final occupied = occupiedByRoomType[roomTypeId] ?? 0;
        final blockedRooms = blockedRoomsByRoomType[roomTypeId] ?? 0;

        final remaining = total - occupied - blockedRooms;

        if (remaining > 0) {
          totalRemaining += remaining;
        }
      }

      remainingRoomsMap[key] = totalRemaining;

      if (totalRemaining <= 0) {
        unbookableDateKeys.add(key);
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    if (extraClosedWeekdays.isNotEmpty) {
      DateTime extraCursor = DateTime(
        firstDate.year,
        firstDate.month,
        firstDate.day,
      );
      while (!extraCursor.isAfter(last)) {
        if (extraClosedWeekdays.contains(extraCursor.weekday)) {
          final String key = ShopService.instance.formatDateKey(extraCursor);
          blockedDateKeys.add(key);
          blockedDateReasons.putIfAbsent(key, () => extraClosedReason);
        }
        extraCursor = extraCursor.add(const Duration(days: 1));
      }
    }

    for (final String key in extraClosedDateKeys) {
      blockedDateKeys.add(key);
      blockedDateReasons.putIfAbsent(key, () => extraClosedReason);
    }

    for (final String key in extraOpenDateKeys) {
      blockedDateKeys.remove(key);
      blockedDateReasons.remove(key);
    }

    if (!markFullRoomsUnbookable) {
      unbookableDateKeys.clear();
    }

    unbookableDateKeys.addAll(extraFullDateKeys);

    if (remainingPetsMap.isNotEmpty) {
      remainingRoomsMap.addAll(remainingPetsMap);
    }

    return FrontCalendarPayload(
      blockedDateKeys: blockedDateKeys,
      blockedDateReasons: blockedDateReasons,
      unbookableDateKeys: unbookableDateKeys,
      priceMap: priceMap,
      remainingRoomsMap: remainingRoomsMap,
      specialOpenDateKeys: specialOpenDateKeys,
    );
  }
}
