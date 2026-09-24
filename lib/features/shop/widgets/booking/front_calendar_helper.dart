// 檔案名稱：lib/features/shop/widgets/booking/front_calendar_helper.dart
// 功能說明：前台預約月曆 helper：查詢月曆價格、關閉日、滿房日與剩餘房數

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
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
        .get();

    // 🔥 依房型統計可用房間數
    final Map<String, int> totalRoomsByRoomType = {};
    final List<Map<String, dynamic>> rooms = <Map<String, dynamic>>[];

    for (final roomDoc in roomsSnapshot.docs) {
      final room = roomDoc.data();
      final roomTypeId = (room['roomTypeId'] ?? '').toString();
      rooms.add(<String, dynamic>{'id': roomDoc.id, ...room});

      if (roomTypeId.isEmpty) continue;
      if (room['enabled'] == false) continue;

      totalRoomsByRoomType[roomTypeId] =
          (totalRoomsByRoomType[roomTypeId] ?? 0) + 1;
    }

    final calendarSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('room_calendar')
        .get();

    DateTime cursor = DateTime(firstDate.year, firstDate.month, firstDate.day);

    final last = DateTime(lastDate.year, lastDate.month, lastDate.day);

    final QuerySnapshot<Map<String, dynamic>> bookingSnap =
        await FirebaseFirestore.instance
            .collection('bookings')
            .where('shopId', isEqualTo: shopId)
            .where('status', whereIn: DaycareOccupancyService.activeStatuses)
            .get();
    final List<Map<String, dynamic>> bookings = bookingSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    final QuerySnapshot<Map<String, dynamic>> occSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('room_occupancies')
        .where('status', isEqualTo: 'active')
        .get();
    final List<Map<String, dynamic>> occupancies = occSnap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
        .toList();
    final List<Map<String, dynamic>> calendarEntries = calendarSnapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();

    while (!cursor.isAfter(last)) {
      final key = ShopService.instance.formatDateKey(cursor);

      priceMap[key] = ShopService.instance.getPriceForDate(shop, cursor);

      int totalRemaining = 0;

      for (final entry in totalRoomsByRoomType.entries) {
        final roomTypeId = entry.key;
        final DateTime slotStart = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
        );
        final DateTime slotEnd = slotStart.add(
          const Duration(hours: 23, minutes: 59),
        );
        final DaycareRoomRemaining computed =
            DaycareOccupancyService.remainingRoomsResultFromData(
              rooms: rooms,
              bookings: bookings,
              occupancies: occupancies,
              calendarEntries: calendarEntries,
              roomTypeId: roomTypeId,
              startAt: slotStart,
              endAt: slotEnd,
              dateKey: key,
            );
        totalRemaining += computed.remaining;
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
