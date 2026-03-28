// 檔案名稱：lib/core/services/booking_service.dart
// 說明：預約服務層（區間預約版）
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

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
  String note = '',
})async {
    final user = _currentUser;
    final doc = _bookings.doc();

    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

// 🔥 自動找房間
final room = await findAvailableRoom(
  shopId: shopId,
  roomTypeId: roomId, // 👈 先暫用 roomId 當 typeId
  startDate: normalizedStart,
  endDate: normalizedEnd,
);

if (room == null) {
  throw Exception('沒有可用房間');
}

final realRoomId = room['id'];
final realRoomName = room['name'];

// 🔥 取得寵物資料（快照）
if (user == null) throw Exception('未登入');

final petDocs = await _firestore
    .collection('users')
    .doc(user.uid)
    .collection('pets')
    .where(FieldPath.documentId, whereIn: petIds)
    .get();

final pets = petDocs.docs.map((doc) {
  final data = doc.data();
  return {
    'petId': doc.id,
    'name': data['name'],
    'type': data['type'],
  };
}).toList();

// 🔥 最終防呆：再次確認房間可用
final available = await isRoomAvailable(
  shopId: shopId,
  roomId: realRoomId, 
  startDate: normalizedStart,
  endDate: normalizedEnd,
);

if (!available) {
  throw Exception('房間已被預約');
}

    await doc.set({
      'shopId': shopId,
      'customerUid': user?.uid,

      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
      'petIds': petIds,
      'pets': pets,
      'roomId': realRoomId,
      'roomName': realRoomName,
      'serviceType': serviceType,

      /// 區間日期
      'startDate': Timestamp.fromDate(normalizedStart),
      'endDate': Timestamp.fromDate(normalizedEnd),
      'nights': nights,


      /// 狀態
      'status': 'pending', // pending / confirmed / completed / cancelled

      /// 備註
      'note': note.trim(),

      /// 價格欄位
      'pricePerNight': null,
      'totalPrice': null,

      /// 未來預留
      'checkedInAt': null,
      'checkedOutAt': null,
      'cameraAccessEnabled': false,
      'cameraUrl': null,

      /// 系統欄位
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

// 🔒 同步鎖房（確保不會漏）
await blockRoomCalendar(
  shopId: shopId,
  roomId: roomId,
  startDate: normalizedStart,
  endDate: normalizedEnd,
);

    return doc.id;
  }

  /// 取得單筆預約
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    final doc = await _bookings.doc(bookingId).get();

    if (!doc.exists) return null;

    return {
      'bookingId': doc.id,
      ...doc.data()!,
    };
  }

  /// 監聽單筆預約
  Stream<Map<String, dynamic>?> streamBooking(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {
        'bookingId': doc.id,
        ...doc.data()!,
      };
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
        return {
          'bookingId': doc.id,
          ...doc.data(),
        };
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
        return {
          'bookingId': doc.id,
          ...doc.data(),
        };
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
      return {
        'bookingId': doc.id,
        ...doc.data(),
      };
    }).toList();
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


  bool _isOccupyingBooking(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? '';
    return status != 'cancelled';
  }

  bool _containsStayDate({
    required DateTime targetDate,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final target = _dateOnly(targetDate);
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    return (target.isAtSameMomentAs(start) || target.isAfter(start)) &&
        target.isBefore(end);
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
  final bookings = await getShopBookings(shopId);

  final start = _dateOnly(startDate);
  final end = _dateOnly(endDate);

  for (final booking in bookings) {
    if (booking['status'] == 'cancelled') continue;

    if (booking['roomId'] != roomId) continue;

    final bStart = _timestampToDate(booking['startDate']);
    final bEnd = _timestampToDate(booking['endDate']);

    if (bStart == null || bEnd == null) continue;

    // 👉 區間重疊檢查
    final overlap =
        start.isBefore(bEnd) && end.isAfter(bStart);

    if (overlap) {
      return false;
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
  final stayDates = getStayDates(
    startDate: startDate,
    endDate: endDate,
  );

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
  final stayDates = getStayDates(
    startDate: startDate,
    endDate: endDate,
  );

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
  final stayDates = getStayDates(
    startDate: startDate,
    endDate: endDate,
  );

  final pricePerNight = _toInt(roomType['price']);

  return stayDates.length * pricePerNight;
}

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
      .where('enabled', isEqualTo: true)
      .get();

  for (final roomDoc in roomsSnapshot.docs) {
    final roomId = roomDoc.id;

    final available = await isRoomAvailable(
      shopId: shopId,
      roomId: roomId,
      startDate: startDate,
      endDate: endDate,
    );

    if (available) {
      return {
        'id': roomId,
        ...roomDoc.data(),
      };
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
