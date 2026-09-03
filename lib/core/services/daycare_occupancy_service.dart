// lib/core/services/daycare_occupancy_service.dart
// 🐾 前台剩餘名額預覽：同時看住宿日期占用與臨托時段

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class DaycareAssignableRoom {
  const DaycareAssignableRoom({
    required this.roomId,
    required this.roomName,
    required this.roomTypeId,
    required this.roomTypeName,
    required this.capacity,
    required this.status,
    this.overlappingSummaries = const <String>[],
  });

  final String roomId;
  final String roomName;
  final String roomTypeId;
  final String roomTypeName;
  final int capacity;
  final String status;
  final List<String> overlappingSummaries;
}

class DaycareOccupancyService {
  DaycareOccupancyService._();

  static final DaycareOccupancyService instance = DaycareOccupancyService._();

  static const List<String> activeStatuses = <String>[
    'pending',
    'confirmed',
    'checked_in',
  ];

  CollectionReference<Map<String, dynamic>> _bookings() {
    return FirebaseFirestore.instance.collection('bookings');
  }

  Future<int> remainingPets({
    required String shopId,
    required DateTime serviceDate,
    required int dailyMaxPets,
    String excludeBookingId = '',
  }) async {
    if (dailyMaxPets <= 0) {
      return 999999;
    }
    final DateTime day = DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
    );
    final QuerySnapshot<Map<String, dynamic>> snap = await _bookings()
        .where('shopId', isEqualTo: shopId)
        .where('bookingKind', isEqualTo: BookingKind.daycare)
        .where('serviceDate', isEqualTo: _dateKey(day))
        .get();
    int used = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      if (doc.id == excludeBookingId) {
        continue;
      }
      final Map<String, dynamic> data = doc.data();
      if (!activeStatuses.contains((data['status'] ?? '').toString())) {
        continue;
      }
      final List<dynamic> pets = data['petIds'] is List
          ? data['petIds'] as List<dynamic>
          : const <dynamic>[];
      used += pets.isEmpty ? 1 : pets.length;
    }
    return (dailyMaxPets - used).clamp(0, dailyMaxPets);
  }

  Future<Map<String, int>> usedPetsByDate({
    required String shopId,
    required DateTime start,
    required DateTime end,
  }) async {
    final String startKey = _dateKey(
      DateTime(start.year, start.month, start.day),
    );
    final String endKey = _dateKey(DateTime(end.year, end.month, end.day));
    final QuerySnapshot<Map<String, dynamic>> snap = await _bookings()
        .where('shopId', isEqualTo: shopId)
        .where('bookingKind', isEqualTo: BookingKind.daycare)
        .where('serviceDate', isGreaterThanOrEqualTo: startKey)
        .where('serviceDate', isLessThanOrEqualTo: endKey)
        .get();
    final Map<String, int> used = <String, int>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      if (!activeStatuses.contains((data['status'] ?? '').toString())) {
        continue;
      }
      final String date = (data['serviceDate'] ?? '').toString();
      if (date.isEmpty) {
        continue;
      }
      final List<dynamic> pets = data['petIds'] is List
          ? data['petIds'] as List<dynamic>
          : const <dynamic>[];
      used[date] = (used[date] ?? 0) + (pets.isEmpty ? 1 : pets.length);
    }
    return used;
  }

  Future<bool> hasPetConflict({
    required String shopId,
    required List<String> petIds,
    required DateTime startAt,
    required DateTime endAt,
    String excludeBookingId = '',
  }) async {
    if (petIds.isEmpty) {
      return false;
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await _bookings()
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: activeStatuses)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      if (doc.id == excludeBookingId) {
        continue;
      }
      final Map<String, dynamic> data = doc.data();
      final List<String> otherPets = ((data['petIds'] as List?) ?? const [])
          .map((dynamic e) => e.toString())
          .toList();
      if (!petIds.any(otherPets.contains)) {
        continue;
      }
      if (BookingKind.isDaycare(data)) {
        final DateTime? otherStart = _ts(data['scheduledStartAt']);
        final DateTime? otherEnd = _ts(data['scheduledEndAt']);
        if (otherStart != null &&
            otherEnd != null &&
            DaycareTimeHelper.overlaps(startAt, endAt, otherStart, otherEnd)) {
          return true;
        }
      } else {
        final DateTime? stayStart = _ts(data['startDate']);
        final DateTime? stayEnd = _ts(data['endDate']);
        if (stayStart != null &&
            stayEnd != null &&
            _stayContains(stayStart, stayEnd, startAt)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<int> remainingRoomsForSlot({
    required String shopId,
    required String roomTypeId,
    required DateTime startAt,
    required DateTime endAt,
    String excludeBookingId = '',
  }) async {
    if (roomTypeId.trim().isEmpty) {
      return 0;
    }
    final QuerySnapshot<Map<String, dynamic>> roomSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .where('roomTypeId', isEqualTo: roomTypeId)
        .get();
    final QuerySnapshot<Map<String, dynamic>> bookingSnap = await _bookings()
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: activeStatuses)
        .get();
    final List<Map<String, dynamic>> rooms = roomSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    final List<Map<String, dynamic>> bookings = bookingSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    return remainingRoomsFromData(
      rooms: rooms,
      bookings: bookings,
      roomTypeId: roomTypeId,
      startAt: startAt,
      endAt: endAt,
      excludeBookingId: excludeBookingId,
    );
  }

  static bool _roomUnavailable(Map<String, dynamic> room) {
    if (room.containsKey('enabled') && !DaycareBool.parse(room['enabled'])) {
      return true;
    }
    final String status = (room['status'] ?? '').toString();
    return status == 'cleaning' ||
        status == 'maintenance' ||
        status == 'blocked';
  }

  /// 店家確認後分房：列出此時段無衝突、非維修／待清潔、容量足夠的實際房間。
  Future<List<DaycareAssignableRoom>> listAssignableRooms({
    required String shopId,
    required DateTime startAt,
    required DateTime endAt,
    required int petCount,
    String excludeBookingId = '',
  }) async {
    final QuerySnapshot<Map<String, dynamic>> roomSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .get();
    final QuerySnapshot<Map<String, dynamic>> typeSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('room_types')
        .get();
    final QuerySnapshot<Map<String, dynamic>> bookingSnap = await _bookings()
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: activeStatuses)
        .get();
    final Map<String, Map<String, dynamic>> types =
        <String, Map<String, dynamic>>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in typeSnap.docs)
            doc.id: doc.data(),
        };
    final List<DaycareAssignableRoom> result = <DaycareAssignableRoom>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in roomSnap.docs) {
      final Map<String, dynamic> room = doc.data();
      if (_roomUnavailable(room)) {
        continue;
      }
      final String roomTypeId = (room['roomTypeId'] ?? '').toString();
      final Map<String, dynamic> type =
          types[roomTypeId] ?? const <String, dynamic>{};
      final int capacity = ((room['capacity'] as num?)?.toInt() ?? 0) > 0
          ? (room['capacity'] as num).toInt()
          : ((type['capacity'] as num?)?.toInt() ?? 0);
      if (capacity > 0 && petCount > capacity) {
        continue;
      }
      final List<String> summaries = <String>[];
      bool busy = false;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> bookingDoc
          in bookingSnap.docs) {
        if (bookingDoc.id == excludeBookingId) {
          continue;
        }
        final Map<String, dynamic> booking = bookingDoc.data();
        if ((booking['roomId'] ?? '').toString() != doc.id) {
          continue;
        }
        final String customer = (booking['customerName'] ?? '訂單').toString();
        if (BookingKind.isDaycare(booking)) {
          final DateTime? otherStart = _ts(booking['scheduledStartAt']);
          final DateTime? otherEnd = _ts(booking['scheduledEndAt']);
          if (otherStart != null &&
              otherEnd != null &&
              DaycareTimeHelper.overlaps(
                startAt,
                endAt,
                otherStart,
                otherEnd,
              )) {
            busy = true;
            summaries.add(
              '安親 $customer ${DaycareTimeHelper.formatHm(otherStart)}-'
              '${DaycareTimeHelper.formatHm(otherEnd)}',
            );
          }
        } else {
          final DateTime? stayStart = _ts(booking['startDate']);
          final DateTime? stayEnd = _ts(booking['endDate']);
          if (stayStart != null &&
              stayEnd != null &&
              _stayContains(stayStart, stayEnd, startAt)) {
            busy = true;
            summaries.add('住宿 $customer');
          }
        }
      }
      if (busy) {
        continue;
      }
      result.add(
        DaycareAssignableRoom(
          roomId: doc.id,
          roomName: (room['name'] ?? doc.id).toString(),
          roomTypeId: roomTypeId,
          roomTypeName: (type['name'] ?? roomTypeId).toString(),
          capacity: capacity,
          status: (room['status'] ?? '').toString(),
          overlappingSummaries: summaries,
        ),
      );
    }
    result.sort((DaycareAssignableRoom a, DaycareAssignableRoom b) {
      final int typeCmp = a.roomTypeName.compareTo(b.roomTypeName);
      if (typeCmp != 0) {
        return typeCmp;
      }
      return a.roomName.compareTo(b.roomName);
    });
    return result;
  }

  static int remainingRoomsFromData({
    required List<Map<String, dynamic>> rooms,
    required List<Map<String, dynamic>> bookings,
    required String roomTypeId,
    required DateTime startAt,
    required DateTime endAt,
    String excludeBookingId = '',
  }) {
    int free = 0;
    for (final Map<String, dynamic> room in rooms) {
      if ((room['roomTypeId'] ?? '').toString() != roomTypeId) {
        continue;
      }
      if (_roomUnavailable(room)) {
        continue;
      }
      final String roomId = (room['id'] ?? '').toString();
      bool busy = false;
      for (final Map<String, dynamic> booking in bookings) {
        if ((booking['id'] ?? '').toString() == excludeBookingId) {
          continue;
        }
        if (!activeStatuses.contains((booking['status'] ?? '').toString())) {
          continue;
        }
        if ((booking['roomId'] ?? '').toString() != roomId) {
          continue;
        }
        if (BookingKind.isDaycare(booking)) {
          final DateTime? otherStart = _ts(booking['scheduledStartAt']);
          final DateTime? otherEnd = _ts(booking['scheduledEndAt']);
          if (otherStart != null &&
              otherEnd != null &&
              DaycareTimeHelper.overlaps(
                startAt,
                endAt,
                otherStart,
                otherEnd,
              )) {
            busy = true;
            break;
          }
        } else {
          final DateTime? stayStart = _ts(booking['startDate']);
          final DateTime? stayEnd = _ts(booking['endDate']);
          if (stayStart != null &&
              stayEnd != null &&
              _stayContains(stayStart, stayEnd, startAt)) {
            busy = true;
            break;
          }
        }
      }
      if (!busy) {
        free++;
      }
    }
    int reserved = 0;
    for (final Map<String, dynamic> booking in bookings) {
      if ((booking['id'] ?? '').toString() == excludeBookingId) {
        continue;
      }
      if (!activeStatuses.contains((booking['status'] ?? '').toString())) {
        continue;
      }
      if (!BookingKind.isDaycare(booking)) {
        continue;
      }
      if ((booking['roomTypeId'] ?? '').toString() != roomTypeId) {
        continue;
      }
      if ((booking['roomId'] ?? '').toString().trim().isNotEmpty) {
        continue;
      }
      final DateTime? otherStart = _ts(booking['scheduledStartAt']);
      final DateTime? otherEnd = _ts(booking['scheduledEndAt']);
      if (otherStart != null &&
          otherEnd != null &&
          DaycareTimeHelper.overlaps(startAt, endAt, otherStart, otherEnd)) {
        reserved++;
      }
    }
    return (free - reserved).clamp(0, 9999);
  }

  static String _dateKey(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  static DateTime? _ts(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  static bool _stayContains(
    DateTime stayStart,
    DateTime stayEnd,
    DateTime slot,
  ) {
    final DateTime start = DateTime(
      stayStart.year,
      stayStart.month,
      stayStart.day,
    );
    final DateTime end = DateTime(stayEnd.year, stayEnd.month, stayEnd.day);
    final DateTime day = DateTime(slot.year, slot.month, slot.day);
    return !day.isBefore(start) && day.isBefore(end);
  }
}
