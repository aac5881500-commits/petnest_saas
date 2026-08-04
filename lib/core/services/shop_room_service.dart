// lib/core/services/shop_room_service.dart
// 🏠 房型 / 房間 / 房務日曆 Service
// 功能：集中管理房型、房間、房務日曆相關 Firestore 讀取

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';

class ShopRoomService {
  ShopRoomService._();

  static final instance = ShopRoomService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  // ===============================
  // 🐱 房型（RoomType）
  // ===============================

  CollectionReference<Map<String, dynamic>> roomTypesRef(String shopId) {
    return _shops.doc(shopId).collection('room_types');
  }

  Stream<List<Map<String, dynamic>>> streamRoomTypes(String shopId) {
    return roomTypesRef(shopId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {...doc.data(), 'id': doc.id};
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getRoomTypes(String shopId) async {
    final snapshot = await roomTypesRef(shopId).get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  Future<void> createRoomType({
    required String shopId,
    required String name,
    required int capacity,
    required int price,
    required int totalRooms,
    required String description,
    required int extraPrice,
    required int width,
    required int depth,
    required int height,
    Map<String, dynamic>? extraData,
  }) async {
    final doc = roomTypesRef(shopId).doc();

    await doc.set({
      'name': name,
      'capacity': capacity,
      'price': price,
      'totalRooms': totalRooms,
      'description': description,
      'extraPrice': extraPrice,
      'width': width,
      'depth': depth,
      'height': height,
      'images': [],
      'isSingle': false,
      ...?extraData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRoomType({
    required String shopId,
    required String roomTypeId,
    required String name,
    required int capacity,
    required int price,
    required bool isSingle,
  }) async {
    await roomTypesRef(shopId).doc(roomTypeId).update({
      'name': name,
      'capacity': capacity,
      'price': price,
      'isSingle': isSingle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoomType({
    required String shopId,
    required String roomTypeId,
  }) async {
    await roomTypesRef(shopId).doc(roomTypeId).delete();
  }

  Future<String> uploadRoomTypeImage({
    required String shopId,
    required String roomTypeId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ext = contentType == 'image/png'
        ? 'png'
        : contentType == 'image/webp'
        ? 'webp'
        : 'jpg';

    final fileName = 'room_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final ref = FirebaseStorage.instance.ref().child(
      'shops/$shopId/room_types/$roomTypeId/$fileName',
    );

    await ref.putData(bytes, SettableMetadata(contentType: contentType));

    final url = await ref.getDownloadURL();

    await roomTypesRef(shopId).doc(roomTypeId).update({
      'images': FieldValue.arrayUnion([url]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return url;
  }

  Future<void> deleteRoomTypeImage({
    required String shopId,
    required String roomTypeId,
    required String imageUrl,
  }) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();

      await roomTypesRef(shopId).doc(roomTypeId).update({
        'images': FieldValue.arrayRemove([imageUrl]),
      });
    } catch (e) {
      print('刪除圖片錯誤: $e');
    }
  }
  // ===============================
  // 🏠 房間（Room）
  // ===============================

  CollectionReference<Map<String, dynamic>> roomsRef(String shopId) {
    return _shops.doc(shopId).collection('rooms');
  }

  Stream<List<Map<String, dynamic>>> streamRooms(String shopId) {
    return roomsRef(shopId).snapshots().asyncMap((snapshot) async {
      final roomTypesSnapshot = await roomTypesRef(shopId).get();

      final roomTypeMap = {
        for (final doc in roomTypesSnapshot.docs) doc.id: doc.data(),
      };

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final roomTypeId = data['roomTypeId']?.toString() ?? '';
        final roomTypeData = roomTypeMap[roomTypeId];

        return {
          'id': doc.id,
          ...data,
          'roomTypeName': roomTypeData?['name'] ?? '未分類',
        };
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getRooms(String shopId) async {
    final snapshot = await roomsRef(shopId).get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  Future<void> createRoom({
    required String shopId,
    required String name,
    required String roomTypeId,
  }) async {
    final roomDoc = await roomsRef(shopId).add({
      'name': name,
      'roomTypeId': roomTypeId,
      'enabled': true,
      'cameraIds': [],
      'blockedDates': [],
      'priceRules': [],
      'discountRules': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final cameraId = await ShopDeviceService.instance
        .createDefaultCameraForRoom(
          shopId: shopId,
          roomId: roomDoc.id,
          roomName: name,
        );

    await roomDoc.update({
      'cameraIds': [cameraId],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRoomStatus({
    required String shopId,
    required String roomId,
    required bool enabled,
  }) async {
    await roomsRef(shopId).doc(roomId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoom({
    required String shopId,
    required String roomId,
  }) async {
    await roomsRef(shopId).doc(roomId).delete();
  }

  Future<void> updateRoomBlockedDates({
    required String shopId,
    required String roomId,
    required List<String> blockedDates,
  }) async {
    await roomsRef(shopId).doc(roomId).update({
      'blockedDates': blockedDates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRoomPriceRules({
    required String shopId,
    required String roomId,
    required List<Map<String, dynamic>> rules,
  }) async {
    await roomsRef(shopId).doc(roomId).update({
      'priceRules': rules,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRoomDiscountRules({
    required String shopId,
    required String roomId,
    required List<Map<String, dynamic>> rules,
  }) async {
    await roomsRef(shopId).doc(roomId).update({
      'discountRules': rules,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===============================
  // 📅 房間日曆（Room Calendar）
  // ===============================

  CollectionReference<Map<String, dynamic>> roomCalendarRef(String shopId) {
    return _shops.doc(shopId).collection('room_calendar');
  }

  Stream<List<Map<String, dynamic>>> streamRoomCalendarByDate(
    String shopId,
    String date,
  ) {
    return roomCalendarRef(
      shopId,
    ).where('date', isEqualTo: date).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    });
  }

  Future<void> setRoomStatus({
    required String shopId,
    required String roomId,
    required String date,
    required String status,
    String roomName = '',

    bool cleaningCompleted = false,
    bool reopened = false,
  }) async {
    final docId = '${roomId}_$date';

    final oldDoc = await roomCalendarRef(shopId).doc(docId).get();
    final oldStatus = oldDoc.data()?['status'] ?? 'available';

    await roomCalendarRef(shopId).doc(docId).set({
      'roomId': roomId,
      'date': date,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    String actionType = 'room_calendar_status_update';

    if (cleaningCompleted) {
      actionType = 'room_cleaning_completed';
    } else if (status == 'maintenance' &&
        oldStatus != 'maintenance' &&
        oldStatus != 'blocked' &&
        oldStatus != 'unavailable') {
      actionType = 'room_maintenance_started';
    } else if ((oldStatus == 'maintenance' ||
            oldStatus == 'blocked' ||
            oldStatus == 'unavailable') &&
        status == 'available') {
      actionType = 'room_maintenance_completed';
    } else if ((oldStatus == 'maintenance' ||
            oldStatus == 'blocked' ||
            oldStatus == 'unavailable') &&
        status == 'closed') {
      actionType = 'room_maintenance_completed_closed';
    }
    await _firestore.collection('action_logs').add({
      'type': actionType,

      'shopId': shopId,
      'roomId': roomId,
      'roomName': roomName,

      'date': date,

      'fromStatus': oldStatus,
      'toStatus': status,

      'operatorUid': _currentUser?.uid,
      'operatorName': _currentUser?.displayName,
      'operatorEmail': _currentUser?.email,
      'operatorRole': 'staff',

      'cleaningCompleted': cleaningCompleted,
      'reopened': reopened,

      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 退房完成後，將退房當日設為清潔中。
  ///
  /// 只影響傳入的 checkoutDate，不會修改後續日期。
  Future<void> startCleaningAfterCheckout({
    required String shopId,
    required String roomId,
    required String bookingId,
    required DateTime checkoutDate,
    String roomName = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRoomId = roomId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedRoomId.isEmpty) {
      throw ArgumentError('缺少房間 ID');
    }

    if (normalizedBookingId.isEmpty) {
      throw ArgumentError('缺少訂單 ID');
    }

    final String dateKey = formatDateKey(checkoutDate);
    final String calendarDocId = '${normalizedRoomId}_$dateKey';

    final DocumentReference<Map<String, dynamic>> calendarDoc = roomCalendarRef(
      normalizedShopId,
    ).doc(calendarDocId);

    final DocumentReference<Map<String, dynamic>> actionLogDoc = _firestore
        .collection('action_logs')
        .doc();

    final WriteBatch batch = _firestore.batch();

    batch.set(calendarDoc, <String, dynamic>{
      'roomId': normalizedRoomId,
      'roomName': roomName.trim(),
      'date': dateKey,
      'status': 'cleaning',
      'bookingId': normalizedBookingId,
      'cleaningStartedAt': FieldValue.serverTimestamp(),
      'cleaningStartedByUid': _currentUser?.uid,
      'cleaningStartedByName': _currentUser?.displayName,
      'cleaningStartedByEmail': _currentUser?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(actionLogDoc, <String, dynamic>{
      'type': 'room_cleaning_started',
      'shopId': normalizedShopId,
      'roomId': normalizedRoomId,
      'roomName': roomName.trim(),
      'bookingId': normalizedBookingId,
      'date': dateKey,
      'fromStatus': 'checked_in',
      'toStatus': 'cleaning',
      'operatorUid': _currentUser?.uid,
      'operatorName': _currentUser?.displayName,
      'operatorEmail': _currentUser?.email,
      'operatorRole': 'staff',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  String formatDateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<List<Map<String, dynamic>>> getAvailableRoomTypes({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final roomTypesSnapshot = await roomTypesRef(shopId).get();
    final roomTypes = roomTypesSnapshot.docs;

    final roomsSnapshot = await roomsRef(shopId).get();
    final rooms = roomsSnapshot.docs;

    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    roomMap = {};

    for (final room in rooms) {
      final data = room.data();

      if (data['enabled'] != true) continue;

      final typeId = data['roomTypeId'];
      if (typeId == null) continue;

      roomMap.putIfAbsent(typeId, () => []);
      roomMap[typeId]!.add(room);
    }

    final stayDates = <String>[];
    DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);

    while (cursor.isBefore(endDate)) {
      stayDates.add(formatDateKey(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    final bookingSnapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
        .get();

    final bookedRoomTypeDateCount = <String, int>{};

    for (final doc in bookingSnapshot.docs) {
      final data = doc.data();

      final roomTypeId = (data['roomTypeId'] ?? data['roomId'] ?? '')
          .toString();
      if (roomTypeId.isEmpty) continue;

      final bookingStartRaw = data['startDate'];
      final bookingEndRaw = data['endDate'];

      if (bookingStartRaw is! Timestamp || bookingEndRaw is! Timestamp) {
        continue;
      }

      final bookingStart = bookingStartRaw.toDate();
      final bookingEnd = bookingEndRaw.toDate();

      DateTime cursor = DateTime(
        bookingStart.year,
        bookingStart.month,
        bookingStart.day,
      );

      final stopDate = DateTime(
        bookingEnd.year,
        bookingEnd.month,
        bookingEnd.day,
      );

      while (cursor.isBefore(stopDate)) {
        final dateKey = formatDateKey(cursor);

        if (stayDates.contains(dateKey)) {
          final key = '$roomTypeId|$dateKey';
          bookedRoomTypeDateCount[key] =
              (bookedRoomTypeDateCount[key] ?? 0) + 1;
        }

        cursor = cursor.add(const Duration(days: 1));
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final typeDoc in roomTypes) {
      final type = typeDoc.data();
      final typeId = typeDoc.id;

      final typeRooms = roomMap[typeId] ?? [];
      if (typeRooms.isEmpty) continue;

      int minAvailableRooms = 999999;

      for (final date in stayDates) {
        int availableCount = 0;

        final calendarSnapshot = await roomCalendarRef(
          shopId,
        ).where('date', isEqualTo: date).get();

        final calendarMap = {
          for (var doc in calendarSnapshot.docs) doc['roomId']: doc.data(),
        };

        for (final room in typeRooms) {
          final roomId = room.id;
          final cal = calendarMap[roomId];
          final status = cal?['status'] ?? 'available';

          // 前台庫存已經透過 bookings 扣除訂單。
          // room_calendar 額外排除手動關閉、維修與清潔中的房間。
          if (status == 'blocked' ||
              status == 'cleaning' ||
              status == 'closed' ||
              status == 'maintenance' ||
              status == 'unavailable') {
            continue;
          }

          final roomData = room.data();
          final List blocked = roomData['blockedDates'] ?? [];

          if (blocked.contains(date)) {
            continue;
          }

          availableCount++;
        }

        final bookingBookedCount =
            bookedRoomTypeDateCount['$typeId|$date'] ?? 0;

        final realAvailableCount = availableCount - bookingBookedCount;

        if (realAvailableCount < minAvailableRooms) {
          minAvailableRooms = realAvailableCount;
        }
      }

      result.add({
        'roomTypeId': typeId,
        'name': type['name'],
        'price': type['price'],
        'capacity': type['capacity'],
        'availableRooms': minAvailableRooms,
        'images': type['images'] ?? [],
        'description': type['description'] ?? '',
        'features': type['features'] ?? [],
        'extraPrice': type['extraPrice'] ?? 0,
        'width': type['width'] ?? 0,
        'depth': type['depth'] ?? 0,
        'height': type['height'] ?? 0,
      });
    }

    return result;
  }

  int calculateRoomPrice({
    required Map<String, dynamic> room,
    required int basePrice,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    int total = 0;

    final List priceRules = room['priceRules'] ?? [];
    final List discountRules = room['discountRules'] ?? [];

    DateTime cursor = startDate;
    int days = 0;

    while (cursor.isBefore(endDate)) {
      int price = basePrice;
      final dateKey = formatDateKey(cursor);

      for (final rule in priceRules) {
        if (dateKey.compareTo(rule['start']) >= 0 &&
            dateKey.compareTo(rule['end']) <= 0) {
          final extra = rule['extra'];

          if (extra is num) {
            price += extra.toInt();
          }
        }
      }

      total += price;
      days++;
      cursor = cursor.add(const Duration(days: 1));
    }

    double discount = 1.0;

    for (final rule in discountRules) {
      if (days >= (rule['minDays'] ?? 0)) {
        discount = rule['discount'] ?? 1.0;
      }
    }

    return (total * discount).toInt();
  }
}
