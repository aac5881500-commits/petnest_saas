// 檔案名稱：lib/core/services/shop_device_service.dart
// 功能說明：管理攝影機、溫度監控、濕度監控等設備
// 📡 店家設備管理 Service

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

  CollectionReference<Map<String, dynamic>> devicesRef(String shopId) {
    return _deviceRef(shopId);
  }

  Map<String, dynamic> defaultCameraPayload({
    required String shopId,
    required String roomId,
    required String roomName,
  }) {
    final FieldValue now = FieldValue.serverTimestamp();
    return <String, dynamic>{
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
    };
  }

  /// 替房間建立預設攝影機
  /// 房間新增時自動建立，先不啟用，等店家填網址後再開啟
  Future<String> createDefaultCameraForRoom({
    required String shopId,
    required String roomId,
    required String roomName,
  }) async {
    final DocumentReference<Map<String, dynamic>> deviceDoc = _deviceRef(
      shopId,
    ).doc();
    await deviceDoc.set(
      defaultCameraPayload(shopId: shopId, roomId: roomId, roomName: roomName),
    );
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

  /// 寫入房間的主攝影機，並可把同房其他攝影機停用。不刪除任何文件。
  ///
  /// [persistSettings] 為 true 時寫入網址與備註，且主攝影機維持未啟用。
  /// 房間尚無攝影機時會新建一筆，並把文件 id 補進 rooms.cameraIds。
  Future<void> writePrimaryRoomCamera({
    required String shopId,
    required String roomId,
    required String roomName,
    String? primaryDeviceId,
    required String url,
    required String note,
    required bool enabled,
    required bool persistSettings,
    required List<String> siblingDeviceIds,
  }) async {
    final WriteBatch batch = _firestore.batch();
    final String existingId = (primaryDeviceId ?? '').trim();
    final String resolvedId = existingId.isEmpty
        ? _deviceRef(shopId).doc().id
        : existingId;
    final DocumentReference<Map<String, dynamic>> primaryRef = _deviceRef(
      shopId,
    ).doc(resolvedId);
    if (existingId.isEmpty) {
      final Map<String, dynamic> payload = defaultCameraPayload(
        shopId: shopId,
        roomId: roomId,
        roomName: roomName,
      );
      payload['url'] = url.trim();
      payload['note'] = note.trim();
      payload['enabled'] = false;
      payload['platformLocked'] = false;
      batch.set(primaryRef, payload);
      batch.update(ShopRoomService.instance.roomsRef(shopId).doc(roomId), {
        'cameraIds': FieldValue.arrayUnion(<String>[resolvedId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (persistSettings) {
      batch.update(primaryRef, <String, dynamic>{
        'url': url.trim(),
        'note': note.trim(),
        'roomName': roomName,
        'enabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(primaryRef, <String, dynamic>{
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (persistSettings || enabled) {
      for (final String rawId in siblingDeviceIds) {
        final String siblingId = rawId.trim();
        if (siblingId.isEmpty || siblingId == resolvedId) {
          continue;
        }
        batch.update(_deviceRef(shopId).doc(siblingId), <String, dynamic>{
          'enabled': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
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
