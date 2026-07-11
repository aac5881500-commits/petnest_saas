// lib/core/services/shop_device_service.dart
// 📡 店家設備管理 Service
// 功能：管理攝影機、溫度監控、濕度監控等設備

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';

class ShopDeviceService {
  ShopDeviceService._();

  static final instance = ShopDeviceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _deviceRef(String shopId) {
    return _firestore.collection('shops').doc(shopId).collection('devices');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDevices(String shopId) {
    return _deviceRef(
      shopId,
    ).orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCameraDevicesByRoom({
    required String shopId,
    required String roomId,
  }) {
    return _deviceRef(shopId)
        .where('type', isEqualTo: 'camera')
        .where('roomId', isEqualTo: roomId)
        .where('enabled', isEqualTo: true)
        .where('platformLocked', isEqualTo: false)
        .limit(1)
        .snapshots();
  }

  Future<void> createCameraDevice({
    required String shopId,
    required String name,
    required String url,
    String? roomId,
    String? roomName,
    String note = '',
  }) async {
    final now = FieldValue.serverTimestamp();

    await _deviceRef(shopId).add({
      'shopId': shopId,
      'type': 'camera',
      'name': name.trim(),
      'url': url.trim(),
      'roomId': roomId,
      'roomName': roomName,
      'enabled': true,
      'platformLocked': false,
      'lockedReason': '',
      'note': note.trim(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  /// 替房間建立預設攝影機
  /// 房間新增時自動建立，先不啟用，等店家填網址後再開啟
  Future<String> createDefaultCameraForRoom({
    required String shopId,
    required String roomId,
    required String roomName,
  }) async {
    final now = FieldValue.serverTimestamp();

    final deviceDoc = await _deviceRef(shopId).add({
      'shopId': shopId,
      'type': 'camera',
      'name': '$roomName 攝影機',
      'url': '',
      'roomId': roomId,
      'roomName': roomName,
      'enabled': false,
      'platformLocked': false,
      'lockedReason': '',
      'note': '',
      'autoCreated': true,
      'createdAt': now,
      'updatedAt': now,
    });
    return deviceDoc.id;
  }

  Future<void> updateDevice({
    required String shopId,
    required String deviceId,
    required Map<String, dynamic> data,
  }) async {
    await _deviceRef(shopId).doc(deviceId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDevice({
    required String shopId,
    required String deviceId,
  }) async {
    await _deviceRef(shopId).doc(deviceId).delete();
  }

  /// 補齊既有房間的預設攝影機
  Future<int> syncDefaultCamerasForRooms({required String shopId}) async {
    final roomsSnapshot = await ShopRoomService.instance.roomsRef(shopId).get();

    int createdCount = 0;

    for (final roomDoc in roomsSnapshot.docs) {
      final data = roomDoc.data();
      final roomName = (data['name'] ?? '').toString();
      final cameraIds = List<String>.from(data['cameraIds'] ?? []);

      if (roomName.isEmpty || cameraIds.isNotEmpty) continue;

      final cameraId = await createDefaultCameraForRoom(
        shopId: shopId,
        roomId: roomDoc.id,
        roomName: roomName,
      );

      await roomDoc.reference.update({
        'cameraIds': [cameraId],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      createdCount++;
    }

    return createdCount;
  }

  /// 平台一鍵關閉店家所有攝影機
  Future<void> platformLockAllCameras({
    required String shopId,
    String reason = '平台一鍵關閉',
  }) async {
    final snapshot = await _deviceRef(
      shopId,
    ).where('type', isEqualTo: 'camera').get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'enabled': false,
        'platformLocked': true,
        'lockedReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// 平台一鍵解除鎖定並開啟所有攝影機
  Future<void> platformUnlockAllCameras({required String shopId}) async {
    final snapshot = await _deviceRef(
      shopId,
    ).where('type', isEqualTo: 'camera').get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'enabled': true,
        'platformLocked': false,
        'lockedReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
