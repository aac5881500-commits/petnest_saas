// 檔案名稱：lib/core/services/daycare_occupancy_service.dart
// 功能說明：前台剩餘名額預覽：同時看住宿日期占用與臨托時段

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';

class DaycareAssignableRoom {
  const DaycareAssignableRoom({
    required this.roomId,
    required this.roomName,
    required this.roomTypeId,
    required this.roomTypeName,
    required this.capacity,
    required this.status,
    this.roomCode = '',
    this.overlappingSummaries = const <String>[],
    this.available = true,
    this.blockedReason = '',
  });

  final String roomId;
  final String roomName;
  final String roomTypeId;
  final String roomTypeName;
  final int capacity;
  final String status;
  final String roomCode;
  final List<String> overlappingSummaries;
  final bool available;
  final String blockedReason;
}

class DaycareRoomRemaining {
  const DaycareRoomRemaining({
    required this.remaining,
    required this.createdCount,
    required this.usableCount,
    required this.reservedCount,
    required this.freeCount,
    this.disabledCount = 0,
    this.cleaningCount = 0,
    this.maintenanceCount = 0,
    this.closedCount = 0,
    this.occupiedCount = 0,
    this.zeroReason = '',
  });

  final int remaining;
  final int createdCount;
  final int usableCount;
  final int reservedCount;
  final int freeCount;
  final int disabledCount;
  final int cleaningCount;
  final int maintenanceCount;
  final int closedCount;
  final int occupiedCount;
  final String zeroReason;

  int get vacantCount => remaining;

  bool get oversold => remaining <= 0 && createdCount > 0;
}

class DaycareAvailabilityException implements Exception {
  const DaycareAvailabilityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DaycareAvailabilityDay {
  const DaycareAvailabilityDay({
    required this.date,
    required this.capacity,
    required this.occupied,
    required this.remaining,
    required this.available,
    required this.unlimited,
  });

  final String date;
  final int capacity;
  final int occupied;
  final int? remaining;
  final bool available;
  final bool unlimited;
}

class DaycareRoomAvailability {
  const DaycareRoomAvailability({
    required this.roomTypeId,
    required this.capacity,
    required this.occupied,
    required this.remaining,
    required this.available,
  });

  final String roomTypeId;
  final int capacity;
  final int occupied;
  final int remaining;
  final bool available;
}

class DaycareAvailabilitySnapshot {
  const DaycareAvailabilitySnapshot({
    required this.days,
    required this.roomTypes,
  });

  final List<DaycareAvailabilityDay> days;
  final List<DaycareRoomAvailability> roomTypes;
}

class DaycareOccupancyService {
  DaycareOccupancyService._();

  static final DaycareOccupancyService instance = DaycareOccupancyService._();

  static const String vacantLabel = '空房';
  static const String disabledLabel = '未啟用';
  static const String cleaningLabel = '清潔中';
  static const String checkoutHoldLabel = '待清潔';
  static const String maintenanceLabel = '維修中';
  static const String closedLabel = '今日關閉';

  static bool isRoomEnabled(Map<String, dynamic> room) {
    return room['enabled'] != false;
  }

  static String roomDocumentStatus(Map<String, dynamic> room) {
    return (room['status'] ?? '').toString().trim().toLowerCase();
  }

  static String permanentStatusOf(Map<String, dynamic> room) {
    final String permanent = (room['permanentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (permanent == 'available' ||
        permanent == 'maintenance' ||
        permanent == 'blocked' ||
        permanent == 'unavailable') {
      return permanent;
    }
    final String legacy = roomDocumentStatus(room);
    if (legacy == 'maintenance' ||
        legacy == 'blocked' ||
        legacy == 'unavailable') {
      return legacy;
    }
    return 'available';
  }

  static bool isPermanentStatusUnsellable(String status) {
    switch (status.trim().toLowerCase()) {
      case 'maintenance':
      case 'blocked':
      case 'unavailable':
        return true;
      default:
        return false;
    }
  }

  static bool isRoomDocumentUnsellable(Map<String, dynamic> room) {
    return !isRoomEnabled(room) ||
        isPermanentStatusUnsellable(permanentStatusOf(room));
  }

  static String stayBookingLabel(Map<String, dynamic>? booking) {
    if (booking == null) {
      return vacantLabel;
    }
    final String status = (booking['status'] ?? '').toString();
    switch (status) {
      case 'pending':
      case 'confirmed':
        return '已訂';
      case 'checked_in':
        return '入住中';
      case 'completed':
        return '已完成';
      default:
        return vacantLabel;
    }
  }

  static String housekeepingLabel({
    required Map<String, dynamic> room,
    String calendarStatus = '',
    Map<String, dynamic>? stayBooking,
  }) {
    if (!isRoomEnabled(room)) {
      return disabledLabel;
    }
    final String permanent = permanentStatusOf(room);
    if (isPermanentStatusUnsellable(permanent)) {
      return maintenanceLabel;
    }
    final String cal = calendarStatus.trim().toLowerCase();
    if (cal == 'closed') {
      return closedLabel;
    }
    if (cal == 'blocked' || cal == 'maintenance' || cal == 'unavailable') {
      return maintenanceLabel;
    }
    if (cal == 'checkout_cleaning') {
      return checkoutHoldLabel;
    }
    if (cal == 'cleaning') {
      return cleaningLabel;
    }
    if (cal == 'booked' || cal == 'checked_in' || cal == 'occupied') {
      final String fromBooking = stayBookingLabel(stayBooking);
      return fromBooking == vacantLabel ? '已訂' : fromBooking;
    }
    return stayBookingLabel(stayBooking);
  }

  static String describeUnusableRooms({
    required int createdCount,
    required int remaining,
    required int usableCount,
    required int disabledCount,
    required int cleaningCount,
    required int maintenanceCount,
    required int closedCount,
    required int occupiedCount,
  }) {
    if (createdCount <= 0) {
      return noPhysicalRooms;
    }
    if (remaining > 0) {
      return '';
    }
    if (disabledCount == createdCount) {
      return '此房型有 $createdCount 間實體房，但 $disabledCount 間目前未啟用';
    }
    if (cleaningCount == createdCount) {
      return '此房型有 $createdCount 間實體房，目前 $cleaningCount 間清潔中';
    }
    if (maintenanceCount == createdCount) {
      return '此房型有 $createdCount 間實體房，目前 $maintenanceCount 間維修／封鎖';
    }
    if (closedCount == createdCount) {
      return '此房型有 $createdCount 間實體房，目前 $closedCount 間今日關閉';
    }
    if (usableCount <= 0 ||
        disabledCount + cleaningCount + maintenanceCount + closedCount > 0) {
      final String closedBit = closedCount > 0 ? '、關閉 $closedCount' : '';
      return '可用 $remaining / 共 $createdCount 間；未啟用 $disabledCount、清潔 $cleaningCount、維修或封鎖 $maintenanceCount$closedBit、住宿占用 $occupiedCount';
    }
    return roomTypeSoldOut;
  }

  static const String noPhysicalRooms = '此房型尚未建立可用實體房間，請聯絡店家';
  static const String roomTypeSoldOut = '該時段此安親房型已無可用房間，請重新選擇房型或時間。';
  static const String selectTimesFirst = '請先選擇完整時間後確認空房';
  static const List<String> activeStatuses = <String>[
    'pending',
    'confirmed',
    'checked_in',
  ];

  /// 取消、過期未付、安親結算後（已接回）不佔實體房間。
  static bool occupiesInventory(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString();
    if (status == 'cancelled' || status == 'no_show' || status == 'completed') {
      return false;
    }
    if (!activeStatuses.contains(status)) {
      return false;
    }
    if (BookingKind.isDaycare(data)) {
      if (BookingSettlementMath.isSettlementConfirmed(data)) {
        return false;
      }
    }
    if (data['depositExpired'] == true) {
      return false;
    }
    if (BookingPaymentStatus.isDeadlineOverdue(data) &&
        !BookingPaymentStatus.isDepositConfirmed(data)) {
      return false;
    }
    return true;
  }

  CollectionReference<Map<String, dynamic>> _bookings() {
    return FirebaseFirestore.instance.collection('bookings');
  }

  /// 顧客不能讀整店訂單。店家查詢失敗時回空，避免前台月曆整頁 permission-denied。
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _bookingDocs(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return (await query.get()).docs;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
      rethrow;
    }
  }

  /// 顧客只能拿到聚合名額。查不到就丟出錯誤，不能把占用量當成 0。
  Future<DaycareAvailabilitySnapshot> customerAvailability({
    required String shopId,
    required List<DateTime> dates,
    DateTime? startAt,
    DateTime? endAt,
    int petCount = 0,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw const DaycareAvailabilityException('請先登入後再查看剩餘名額');
    }
    final List<String> keys = dates
        .map(_dateKey)
        .where((String key) => key.isNotEmpty)
        .toSet()
        .toList();
    if (keys.isEmpty || keys.length > 31) {
      throw const DaycareAvailabilityException('暫時無法取得剩餘名額');
    }
    try {
      final Map<String, dynamic> raw = await DaycareFunctionService.instance
          .getAvailability(
            shopId: shopId,
            dates: keys,
            startAt: startAt,
            endAt: endAt,
            petCount: petCount,
          );
      return _snapshotFrom(raw);
    } on DaycareAvailabilityException {
      rethrow;
    } catch (error) {
      throw DaycareAvailabilityException(
        DaycareFunctionException.from(error),
      );
    }
  }

  DaycareAvailabilitySnapshot _snapshotFrom(Map<String, dynamic> raw) {
    final List<dynamic> dayRows = raw['days'] is List
        ? raw['days'] as List<dynamic>
        : const <dynamic>[];
    final List<dynamic> roomRows = raw['roomTypes'] is List
        ? raw['roomTypes'] as List<dynamic>
        : const <dynamic>[];
    return DaycareAvailabilitySnapshot(
      days: dayRows.map((dynamic row) {
        final Map<String, dynamic> data = row is Map
            ? Map<String, dynamic>.from(row)
            : <String, dynamic>{};
        final bool unlimited = data['unlimited'] == true;
        final int? remaining = unlimited ? null : _intOrNull(data['remaining']);
        return DaycareAvailabilityDay(
          date: (data['date'] ?? '').toString(),
          capacity: _intOrNull(data['capacity']) ?? 0,
          occupied: _intOrNull(data['occupied']) ?? 0,
          remaining: remaining,
          available: data['available'] == true,
          unlimited: unlimited,
        );
      }).toList(),
      roomTypes: roomRows.map((dynamic row) {
        final Map<String, dynamic> data = row is Map
            ? Map<String, dynamic>.from(row)
            : <String, dynamic>{};
        return DaycareRoomAvailability(
          roomTypeId: (data['roomTypeId'] ?? '').toString(),
          capacity: _intOrNull(data['capacity']) ?? 0,
          occupied: _intOrNull(data['occupied']) ?? 0,
          remaining: _intOrNull(data['remaining']) ?? 0,
          available: data['available'] == true,
        );
      }).toList(),
    );
  }

  int? _intOrNull(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw.toString());
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
    final DaycareAvailabilitySnapshot snapshot = await customerAvailability(
      shopId: shopId,
      dates: <DateTime>[day],
    );
    final String key = _dateKey(day);
    DaycareAvailabilityDay? match;
    for (final DaycareAvailabilityDay item in snapshot.days) {
      if (item.date == key) {
        match = item;
        break;
      }
    }
    if (match == null) {
      throw const DaycareAvailabilityException('暫時無法取得剩餘名額');
    }
    if (match.unlimited || match.remaining == null) {
      return 999999;
    }
    return match.remaining!;
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
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
        await _bookingDocs(
          _bookings()
              .where('shopId', isEqualTo: shopId)
              .where('bookingKind', isEqualTo: BookingKind.daycare)
              .where('serviceDate', isGreaterThanOrEqualTo: startKey)
              .where('serviceDate', isLessThanOrEqualTo: endKey),
        );
    final Map<String, int> used = <String, int>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();
      if (!occupiesInventory(data)) {
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
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return false;
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await _bookings()
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: activeStatuses)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      if (doc.id == excludeBookingId) {
        continue;
      }
      final Map<String, dynamic> data = doc.data();
      if (!occupiesInventory(data)) {
        continue;
      }
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
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs =
        await _bookingDocs(
          _bookings()
              .where('shopId', isEqualTo: shopId)
              .where('status', whereIn: activeStatuses),
        );
    final QuerySnapshot<Map<String, dynamic>> occSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('room_occupancies')
        .where('status', isEqualTo: 'active')
        .get();
    final String dateKey = _dateKey(
      DailyCareDateHelper.calendarDateInTaipei(startAt),
    );
    final List<Map<String, dynamic>> rooms = roomSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    final List<Map<String, dynamic>> calendarEntries = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> room in rooms) {
      if ((room['roomTypeId'] ?? '').toString().trim() != roomTypeId.trim()) {
        continue;
      }
      final String roomId = (room['id'] ?? '').toString();
      if (roomId.isEmpty) {
        continue;
      }
      final DocumentSnapshot<Map<String, dynamic>> calSnap =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('room_calendar')
              .doc('${roomId}_$dateKey')
              .get();
      if (calSnap.exists) {
        calendarEntries.add(<String, dynamic>{
          'id': calSnap.id,
          ...?calSnap.data(),
        });
      }
    }
    final List<Map<String, dynamic>> bookings = bookingDocs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    final List<Map<String, dynamic>> occupancies = occSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    return remainingRoomsFromData(
      rooms: rooms,
      bookings: bookings,
      occupancies: occupancies,
      calendarEntries: calendarEntries,
      roomTypeId: roomTypeId,
      startAt: startAt,
      endAt: endAt,
      excludeBookingId: excludeBookingId,
    );
  }

  static bool _roomUnavailable(Map<String, dynamic> room) {
    return isRoomDocumentUnsellable(room);
  }

  static bool calendarBlocksRoom(String status) {
    return status == 'booked' ||
        status == 'checked_in' ||
        status == 'occupied' ||
        status == 'checkout_cleaning' ||
        status == 'blocked' ||
        status == 'cleaning' ||
        status == 'maintenance' ||
        status == 'closed' ||
        status == 'unavailable';
  }

  static bool roomMatchesType(
    Map<String, dynamic> room,
    String roomTypeId, {
    String alternateTypeId = '',
  }) {
    final String rid = (room['roomTypeId'] ?? '').toString().trim();
    final String wanted = roomTypeId.trim();
    if (wanted.isNotEmpty && rid == wanted) {
      return true;
    }
    final String alt = alternateTypeId.trim();
    return alt.isNotEmpty && rid == alt;
  }

  static String _bookingIdOf(Map<String, dynamic> booking) {
    final String id = (booking['id'] ?? '').toString();
    if (id.isNotEmpty) {
      return id;
    }
    return (booking['bookingId'] ?? '').toString();
  }

  static DateTime? _holdTime(dynamic raw) {
    final DateTime? parsed = _ts(raw);
    if (parsed != null) {
      return parsed;
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
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
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs =
        await _bookingDocs(
          _bookings()
              .where('shopId', isEqualTo: shopId)
              .where('status', whereIn: activeStatuses),
        );
    final Map<String, Map<String, dynamic>> types =
        <String, Map<String, dynamic>>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in typeSnap.docs)
            doc.id: doc.data(),
        };
    final QuerySnapshot<Map<String, dynamic>> occSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('room_occupancies')
        .where('status', isEqualTo: 'active')
        .get();
    final String dateKey = _dateKey(
      DailyCareDateHelper.calendarDateInTaipei(startAt),
    );
    final List<DaycareAssignableRoom> result = <DaycareAssignableRoom>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in roomSnap.docs) {
      final Map<String, dynamic> room = doc.data();
      if (_roomUnavailable(room)) {
        continue;
      }
      final DocumentSnapshot<Map<String, dynamic>> calSnap =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('room_calendar')
              .doc('${doc.id}_$dateKey')
              .get();
      final String calendarStatus = (calSnap.data()?['status'] ?? '')
          .toString();
      if (calSnap.exists && calendarBlocksRoom(calendarStatus)) {
        result.add(
          DaycareAssignableRoom(
            roomId: doc.id,
            roomName: (room['name'] ?? doc.id).toString(),
            roomCode:
                (room['roomCode'] ??
                        room['number'] ??
                        room['roomNumber'] ??
                        room['name'] ??
                        doc.id)
                    .toString(),
            roomTypeId: (room['roomTypeId'] ?? '').toString(),
            roomTypeName:
                (types[(room['roomTypeId'] ?? '').toString()]?['name'] ??
                        (room['roomTypeId'] ?? '').toString())
                    .toString(),
            capacity: ((room['capacity'] as num?)?.toInt() ?? 0) > 0
                ? (room['capacity'] as num).toInt()
                : ((types[(room['roomTypeId'] ?? '').toString()]?['capacity']
                              as num?)
                          ?.toInt() ??
                      0),
            status: (room['status'] ?? '').toString(),
            available: false,
            blockedReason: calendarStatus == 'checkout_cleaning'
                ? '此房間退房後待清潔'
                : '此房間已被住宿訂單占用',
          ),
        );
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
      for (final QueryDocumentSnapshot<Map<String, dynamic>> occDoc
          in occSnap.docs) {
        final Map<String, dynamic> occ = occDoc.data();
        if ((occ['roomId'] ?? '').toString() != doc.id) {
          continue;
        }
        if ((occ['bookingId'] ?? '').toString() == excludeBookingId) {
          continue;
        }
        if ((occ['status'] ?? 'active').toString() != 'active') {
          continue;
        }
        final DateTime? occStart = _ts(occ['startAt']);
        final DateTime? occEnd = _ts(occ['endAt']);
        if (occStart == null || occEnd == null) {
          continue;
        }
        final String occMode = (occ['occupancyMode'] ?? 'slot').toString();
        if (occMode == 'full_day') {
          if (_dateKey(occStart) == dateKey) {
            busy = true;
            summaries.add('房間占用中');
          }
        } else if (DaycareTimeHelper.overlaps(
          startAt,
          endAt,
          occStart,
          occEnd,
        )) {
          busy = true;
          summaries.add('房間占用中');
        }
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> bookingDoc
          in bookingDocs) {
        if (bookingDoc.id == excludeBookingId) {
          continue;
        }
        final Map<String, dynamic> booking = bookingDoc.data();
        if (!occupiesInventory(booking)) {
          continue;
        }
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
      final String roomName = (room['name'] ?? doc.id).toString();
      final String roomCode =
          (room['roomCode'] ?? room['number'] ?? room['roomNumber'] ?? roomName)
              .toString();
      if (busy) {
        result.add(
          DaycareAssignableRoom(
            roomId: doc.id,
            roomName: roomName,
            roomCode: roomCode,
            roomTypeId: roomTypeId,
            roomTypeName: (type['name'] ?? roomTypeId).toString(),
            capacity: capacity,
            status: (room['status'] ?? '').toString(),
            overlappingSummaries: summaries,
            available: false,
            blockedReason: summaries.isEmpty ? '此時段已被占用' : summaries.join('、'),
          ),
        );
        continue;
      }
      result.add(
        DaycareAssignableRoom(
          roomId: doc.id,
          roomName: roomName,
          roomCode: roomCode,
          roomTypeId: roomTypeId,
          roomTypeName: (type['name'] ?? roomTypeId).toString(),
          capacity: capacity,
          status: (room['status'] ?? '').toString(),
          overlappingSummaries: summaries,
        ),
      );
    }
    result.sort((DaycareAssignableRoom a, DaycareAssignableRoom b) {
      final int typeCmp = NaturalSort.compare(a.roomTypeName, b.roomTypeName);
      if (typeCmp != 0) {
        return typeCmp;
      }
      return compareRoomCodes(
        a.roomCode.isEmpty ? a.roomName : a.roomCode,
        b.roomCode.isEmpty ? b.roomName : b.roomCode,
        tieA: a.roomId,
        tieB: b.roomId,
      );
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
    int petCount = 0,
    int roomTypeCapacity = 0,
    List<Map<String, dynamic>> occupancies = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> calendarEntries = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> holdEntries = const <Map<String, dynamic>>[],
    String dateKey = '',
    String alternateTypeId = '',
  }) {
    return remainingRoomsResultFromData(
      rooms: rooms,
      bookings: bookings,
      roomTypeId: roomTypeId,
      startAt: startAt,
      endAt: endAt,
      excludeBookingId: excludeBookingId,
      petCount: petCount,
      roomTypeCapacity: roomTypeCapacity,
      occupancies: occupancies,
      calendarEntries: calendarEntries,
      holdEntries: holdEntries,
      dateKey: dateKey,
      alternateTypeId: alternateTypeId,
    ).remaining;
  }

  static DaycareRoomRemaining remainingRoomsResultFromData({
    required List<Map<String, dynamic>> rooms,
    required List<Map<String, dynamic>> bookings,
    required String roomTypeId,
    required DateTime startAt,
    required DateTime endAt,
    String excludeBookingId = '',
    int petCount = 0,
    int roomTypeCapacity = 0,
    List<Map<String, dynamic>> occupancies = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> calendarEntries = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> holdEntries = const <Map<String, dynamic>>[],
    String dateKey = '',
    String alternateTypeId = '',
  }) {
    if (petCount > 0 && roomTypeCapacity > 0 && petCount > roomTypeCapacity) {
      return DaycareRoomRemaining(
        remaining: 0,
        createdCount: 0,
        usableCount: 0,
        reservedCount: 0,
        freeCount: 0,
        zeroReason: '此房型最多容納 $roomTypeCapacity 隻寵物',
      );
    }
    final String resolvedDateKey = dateKey.isNotEmpty
        ? dateKey
        : _dateKey(DailyCareDateHelper.calendarDateInTaipei(startAt));
    final List<Map<String, dynamic>> typeRooms = rooms.where((
      Map<String, dynamic> room,
    ) {
      return roomMatchesType(
        room,
        roomTypeId,
        alternateTypeId: alternateTypeId,
      );
    }).toList();
    final int createdCount = typeRooms.length;
    if (createdCount <= 0) {
      return const DaycareRoomRemaining(
        remaining: 0,
        createdCount: 0,
        usableCount: 0,
        reservedCount: 0,
        freeCount: 0,
        zeroReason: noPhysicalRooms,
      );
    }
    int usableCount = 0;
    int free = 0;
    int disabledCount = 0;
    int cleaningCount = 0;
    int maintenanceCount = 0;
    int closedCount = 0;
    int occupiedCount = 0;
    for (final Map<String, dynamic> room in typeRooms) {
      if (!isRoomEnabled(room)) {
        disabledCount += 1;
        continue;
      }
      if (isPermanentStatusUnsellable(permanentStatusOf(room))) {
        maintenanceCount += 1;
        continue;
      }
      final int roomCap = ((room['capacity'] as num?)?.toInt() ?? 0) > 0
          ? (room['capacity'] as num).toInt()
          : roomTypeCapacity;
      if (petCount > 0 && roomCap > 0 && petCount > roomCap) {
        continue;
      }
      usableCount += 1;
      final String roomId = (room['id'] ?? room['roomId'] ?? '').toString();
      if (roomId.isEmpty) {
        continue;
      }
      final bool calendarHit = calendarEntries.any((Map<String, dynamic> item) {
        return (item['roomId'] ?? '').toString() == roomId &&
            (item['date'] ?? '').toString() == resolvedDateKey &&
            calendarBlocksRoom((item['status'] ?? '').toString());
      });
      if (calendarHit) {
        final String calStatus = calendarEntries
            .where((Map<String, dynamic> item) {
              return (item['roomId'] ?? '').toString() == roomId &&
                  (item['date'] ?? '').toString() == resolvedDateKey;
            })
            .map(
              (Map<String, dynamic> item) =>
                  (item['status'] ?? '').toString().trim().toLowerCase(),
            )
            .firstWhere((String status) => status.isNotEmpty, orElse: () => '');
        if (calStatus == 'cleaning') {
          cleaningCount += 1;
        } else if (calStatus == 'closed') {
          closedCount += 1;
        } else if (calStatus == 'maintenance' ||
            calStatus == 'blocked' ||
            calStatus == 'unavailable') {
          maintenanceCount += 1;
        } else {
          occupiedCount += 1;
        }
        continue;
      }
      final bool occupancyHit = occupancies.any((Map<String, dynamic> occ) {
        if ((occ['roomId'] ?? '').toString() != roomId) {
          return false;
        }
        if ((occ['bookingId'] ?? '').toString() == excludeBookingId) {
          return false;
        }
        if ((occ['status'] ?? 'active').toString().isNotEmpty &&
            (occ['status'] ?? 'active').toString() != 'active') {
          return false;
        }
        final DateTime? occStart = _ts(occ['startAt']);
        final DateTime? occEnd = _ts(occ['endAt']);
        if (occStart == null || occEnd == null) {
          return false;
        }
        if ((occ['occupancyMode'] ?? 'slot').toString() == 'full_day') {
          return _dateKey(occStart) == resolvedDateKey;
        }
        return DaycareTimeHelper.overlaps(startAt, endAt, occStart, occEnd);
      });
      if (occupancyHit) {
        occupiedCount += 1;
        continue;
      }
      bool busy = false;
      for (final Map<String, dynamic> booking in bookings) {
        if (_bookingIdOf(booking) == excludeBookingId) {
          continue;
        }
        if (!occupiesInventory(booking)) {
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
      if (busy) {
        occupiedCount += 1;
        continue;
      }
      free++;
    }
    final Set<String> reservedIds = <String>{};
    for (final Map<String, dynamic> item in holdEntries) {
      if ((item['bookingId'] ?? '').toString() == excludeBookingId) {
        continue;
      }
      final DateTime? otherStart = _holdTime(item['startAt']);
      final DateTime? otherEnd = _holdTime(item['endAt']);
      if (otherStart != null &&
          otherEnd != null &&
          DaycareTimeHelper.overlaps(startAt, endAt, otherStart, otherEnd)) {
        final String id = (item['bookingId'] ?? '').toString();
        if (id.isNotEmpty) {
          reservedIds.add(id);
        }
      }
    }
    for (final Map<String, dynamic> booking in bookings) {
      final String bookingId = _bookingIdOf(booking);
      if (bookingId == excludeBookingId) {
        continue;
      }
      if (!occupiesInventory(booking)) {
        continue;
      }
      if ((booking['roomId'] ?? '').toString().trim().isNotEmpty) {
        continue;
      }
      final String heldType =
          ((booking['requestedRoomTypeId'] ?? booking['roomTypeId'] ?? '')
                  .toString())
              .trim();
      if (heldType != roomTypeId.trim() &&
          (alternateTypeId.isEmpty || heldType != alternateTypeId.trim())) {
        continue;
      }
      if (BookingKind.isDaycare(booking)) {
        final DateTime? otherStart = _ts(booking['scheduledStartAt']);
        final DateTime? otherEnd = _ts(booking['scheduledEndAt']);
        if (otherStart != null &&
            otherEnd != null &&
            DaycareTimeHelper.overlaps(startAt, endAt, otherStart, otherEnd)) {
          reservedIds.add(bookingId);
        }
        continue;
      }
      final DateTime? stayStart = _ts(booking['startDate']);
      final DateTime? stayEnd = _ts(booking['endDate']);
      if (stayStart != null &&
          stayEnd != null &&
          _stayContains(stayStart, stayEnd, startAt)) {
        reservedIds.add(bookingId);
      }
    }
    final int reservedCount = reservedIds.length;
    final int remaining = (free - reservedCount).clamp(0, 9999);
    return DaycareRoomRemaining(
      remaining: remaining,
      createdCount: createdCount,
      usableCount: usableCount,
      reservedCount: reservedCount,
      freeCount: free,
      disabledCount: disabledCount,
      cleaningCount: cleaningCount,
      maintenanceCount: maintenanceCount,
      closedCount: closedCount,
      occupiedCount: occupiedCount,
      zeroReason: remaining <= 0
          ? describeUnusableRooms(
              createdCount: createdCount,
              remaining: remaining,
              usableCount: usableCount,
              disabledCount: disabledCount,
              cleaningCount: cleaningCount,
              maintenanceCount: maintenanceCount,
              closedCount: closedCount,
              occupiedCount: occupiedCount,
            )
          : '',
    );
  }

  static String dateKeyOf(DateTime date) => _dateKey(date);

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
    final DateTime start = DailyCareDateHelper.calendarDateInTaipei(stayStart);
    final DateTime end = DailyCareDateHelper.calendarDateInTaipei(stayEnd);
    final DateTime day = DailyCareDateHelper.calendarDateInTaipei(slot);
    return !day.isBefore(start) && day.isBefore(end);
  }
}
