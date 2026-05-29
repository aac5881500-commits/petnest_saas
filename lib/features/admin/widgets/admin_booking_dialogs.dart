// lib/features/admin/widgets/admin_booking_dialogs.dart
// 🪟 後台訂單詳細頁：Dialog 整包
// 功能：選擇房間、更換房間、取消訂單原因

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_service.dart';

Future<void> showAdminAssignRoomDialog({
  required BuildContext context,
  required String bookingId,
  required Map<String, dynamic> data,
}) async {
  final shopId = data['shopId']?.toString() ?? '';
  final roomTypeId = data['roomTypeId']?.toString() ?? '';
  final startDate = (data['startDate'] as Timestamp).toDate();
  final endDate = (data['endDate'] as Timestamp).toDate();

  final rooms = await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('rooms')
      .where('roomTypeId', isEqualTo: roomTypeId)
      .where('enabled', isEqualTo: true)
      .get();

  final availableRooms = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  for (final roomDoc in rooms.docs) {
    final available = await BookingService.instance.isRoomAvailable(
      shopId: shopId,
      roomId: roomDoc.id,
      startDate: startDate,
      endDate: endDate,
    );

    if (available) {
      availableRooms.add(roomDoc);
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('選擇房間'),
        content: SizedBox(
          width: double.maxFinite,
          child: availableRooms.isEmpty
              ? const Text('此房型目前沒有可用房間')
              : ListView(
                  shrinkWrap: true,
                  children: availableRooms.map((doc) {
                    final room = doc.data();
                    final roomName = room['name']?.toString() ?? '未命名房間';

                    return ListTile(
                      leading: const Icon(Icons.meeting_room),
                      title: Text(roomName),
                      onTap: () async {
                        try {
                          await BookingService.instance.assignRoomToBooking(
                            bookingId: bookingId,
                            shopId: shopId,
                            roomId: doc.id,
                            roomName: roomName,
                            startDate: startDate,
                            endDate: endDate,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已完成分房')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('分房失敗：$e')),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

Future<void> showAdminChangeRoomDialog({
  required BuildContext context,
  required String bookingId,
  required Map<String, dynamic> data,
}) async {
  final shopId = data['shopId']?.toString() ?? '';
  final roomTypeId = data['roomTypeId']?.toString() ?? '';
  final oldRoomId = data['roomId']?.toString() ?? '';
  final oldRoomName = data['roomName']?.toString() ?? '';

  if (oldRoomId.isEmpty || oldRoomName.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此訂單尚未分房，不能更換房間')),
      );
    }
    return;
  }

  final startDate = (data['startDate'] as Timestamp).toDate();
  final endDate = (data['endDate'] as Timestamp).toDate();

  final changeReasonController = TextEditingController();
  String selectedChangeReason = '攝影機故障';

  final rooms = await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('rooms')
      .where('roomTypeId', isEqualTo: roomTypeId)
      .where('enabled', isEqualTo: true)
      .get();

  final availableRooms = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  for (final roomDoc in rooms.docs) {
    if (roomDoc.id == oldRoomId) continue;

    final available = await BookingService.instance.isRoomAvailable(
      shopId: shopId,
      roomId: roomDoc.id,
      startDate: startDate,
      endDate: endDate,
    );

    if (available) {
      availableRooms.add(roomDoc);
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('更換房間｜目前：$oldRoomName'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedChangeReason,
                        decoration: const InputDecoration(
                          labelText: '更換原因（必選）',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '攝影機故障',
                            child: Text('攝影機故障'),
                          ),
                          DropdownMenuItem(
                            value: '冷氣異常',
                            child: Text('冷氣異常'),
                          ),
                          DropdownMenuItem(
                            value: '設備維修',
                            child: Text('設備維修'),
                          ),
                          DropdownMenuItem(
                            value: '貓咪適應問題',
                            child: Text('貓咪適應問題'),
                          ),
                          DropdownMenuItem(
                            value: '客戶要求',
                            child: Text('客戶要求'),
                          ),
                          DropdownMenuItem(
                            value: '店家安排調整',
                            child: Text('店家安排調整'),
                          ),
                          DropdownMenuItem(
                            value: '其他',
                            child: Text('其他'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedChangeReason = value ?? '攝影機故障';
                          });
                        },
                      ),

                      if (selectedChangeReason == '其他') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: changeReasonController,
                          decoration: const InputDecoration(
                            labelText: '其他原因',
                            hintText: '請輸入更換房間原因',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              if (availableRooms.isEmpty)
                const Text('目前沒有其他可更換房間')
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: availableRooms.map((doc) {
                      final room = doc.data();
                      final newRoomName =
                          room['name']?.toString() ?? '未命名房間';

                      return ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: Text(newRoomName),
                        onTap: () async {
                          final reason = selectedChangeReason == '其他'
                              ? changeReasonController.text.trim()
                              : selectedChangeReason;

                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請填寫更換房間原因')),
                            );
                            return;
                          }

                          try {
                            await BookingService.instance.changeAssignedRoom(
                              bookingId: bookingId,
                              shopId: shopId,
                              oldRoomId: oldRoomId,
                              oldRoomName: oldRoomName,
                              newRoomId: doc.id,
                              newRoomName: newRoomName,
                              startDate: startDate,
                              endDate: endDate,
                              reason: reason,
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已更換房間')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('更換失敗：$e')),
                              );
                            }
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

Future<void> showAdminCancelBookingDialog({
  required BuildContext context,
  required String bookingId,
}) async {
  String selectedReason = '客戶未付款';
  final otherReasonController = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('取消訂單原因'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  items: const [
                    DropdownMenuItem(value: '客戶未付款', child: Text('客戶未付款')),
                    DropdownMenuItem(value: '客戶自行取消', child: Text('客戶自行取消')),
                    DropdownMenuItem(value: '店家無法接待', child: Text('店家無法接待')),
                    DropdownMenuItem(value: '重複預約', child: Text('重複預約')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      selectedReason = v ?? '客戶未付款';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: '取消原因',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (selectedReason == '其他') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otherReasonController,
                    decoration: const InputDecoration(
                      labelText: '其他原因',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = selectedReason == '其他'
                      ? otherReasonController.text.trim()
                      : selectedReason;

                  if (reason.isEmpty) return;

                  Navigator.pop(context, reason);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('確認取消'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == null) return;

  await BookingService.instance.cancelBooking(
    bookingId: bookingId,
    cancelReason: result,
    cancelBy: 'admin',
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('訂單已取消並釋放房間')),
    );
  }
}