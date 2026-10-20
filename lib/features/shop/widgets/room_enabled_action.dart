import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';

Future<bool> confirmLastStayRoom(BuildContext context) async {
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('最後一間住宿房間'),
          content: const Text('停用後將沒有可預約的住宿房間，住宿預約也會關閉。既有訂單仍會保留，是否繼續？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('繼續'),
            ),
          ],
        ),
      ) ==
      true;
}

final Set<String> _changingShops = <String>{};

Future<bool> guardStayRoomChange(
  BuildContext context,
  String shopId,
  Set<String> roomIds,
  Future<void> Function(bool closeStay) commit,
) async {
  if (!_changingShops.add(shopId)) {
    throw StateError('房間狀態儲存中，請稍候再操作');
  }
  try {
    return await applyStayRoomChange(
      affectedIds: roomIds,
      load: () => StayBookingReadiness.load(shopId),
      bookingEnabled: () async =>
          (await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopId)
                  .get(const GetOptions(source: Source.server)))
              .data()?['bookingEnabled'] !=
          false,
      confirmLast: () => confirmLastStayRoom(context),
      commit: commit,
    );
  } finally {
    _changingShops.remove(shopId);
  }
}

Future<bool> deleteRoomsWithStayGuard(
  BuildContext context,
  String shopId,
  Set<String> roomIds, {
  String? roomTypeId,
}) async {
  return guardStayRoomChange(context, shopId, roomIds, (closeStay) async {
    if (roomIds.length + (roomTypeId == null ? 0 : 1) + (closeStay ? 1 : 0) >
        500) {
      throw StateError('刪除範圍超過單次操作上限，請先分次處理房間');
    }
    final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
    final batch = FirebaseFirestore.instance.batch();
    for (final id in roomIds) {
      batch.delete(shopRef.collection('rooms').doc(id));
    }
    if (roomTypeId != null) {
      batch.delete(shopRef.collection('room_types').doc(roomTypeId));
    }
    if (closeStay) batch.update(shopRef, {'bookingEnabled': false});
    await batch.commit();
  });
}

/// Both updates succeed together or neither is saved; daycare is untouched.
Future<void> changeRoomEnabled(
  BuildContext context,
  String shopId,
  String roomId,
  bool enabled,
) async {
  try {
    final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
    Future<void> commit(bool closeStay) async {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(shopRef.collection('rooms').doc(roomId), {
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (closeStay) batch.update(shopRef, {'bookingEnabled': false});
      await batch.commit();
    }

    if (enabled) {
      await ShopRoomService.instance.updateRoomStatus(
        shopId: shopId,
        roomId: roomId,
        enabled: true,
      );
    } else {
      if (!await guardStayRoomChange(context, shopId, {roomId}, commit)) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房間狀態已儲存')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }
}
