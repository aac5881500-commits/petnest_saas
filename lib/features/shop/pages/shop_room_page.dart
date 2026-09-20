// 檔案名稱：lib/features/shop/pages/shop_room_page.dart
// 功能說明：房間管理（完整升級版）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_quick_create_sheet.dart';

class ShopRoomPage extends StatefulWidget {
  const ShopRoomPage({
    super.key,
    required this.shopId,
    this.embeddedInSetupCenter = false,
  });

  final String shopId;
  final bool embeddedInSetupCenter;

  @override
  State<ShopRoomPage> createState() => _ShopRoomPageState();
}

class _ShopRoomPageState extends State<ShopRoomPage> {
  final _nameController = TextEditingController();

  String? _selectedRoomTypeId;
  String? _expandedRoomTypeId;
  Future<void> _createRoom() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _selectedRoomTypeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫完整資料')));
      return;
    }

    final roomTypes = await ShopService.instance.getRoomTypes(widget.shopId);

    final selectedType = roomTypes.firstWhere(
      (e) => e['id'] == _selectedRoomTypeId,
    );

    final totalRooms = selectedType['totalRooms'] ?? 0;
    final rooms = await ShopService.instance.getRooms(widget.shopId);

    final sameTypeRooms = rooms
        .where((r) => r['roomTypeId'] == _selectedRoomTypeId)
        .toList();

    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final shop = shopDoc.data() ?? {};
    final limit = ShopPlanService.roomLimit(shop);

    if (rooms.length >= limit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('免費版最多建立 $limit 間房間，升級 999 方案即可解除限制')),
      );
      return;
    }

    if (sameTypeRooms.length >= totalRooms) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房型已達最大房間數')));
      return;
    }

    final isDuplicate = rooms.any(
      (r) => (r['name'] ?? '').toString().trim() == name,
    );

    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房號已存在，請使用不同房號')));
      return;
    }

    await ShopService.instance.createRoom(
      shopId: widget.shopId,
      name: name,
      roomTypeId: _selectedRoomTypeId!,
    );

    if (!mounted) return;

    _nameController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('新增房間成功')));
  }

  Future<void> _deleteRoom(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此房間嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ShopService.instance.deleteRoom(
      shopId: widget.shopId,
      roomId: roomId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除房間')));
  }

  Future<void> _showBatchCreateRoomSheet({
    required Map<String, dynamic> roomType,
    required List<Map<String, dynamic>> existingRooms,
  }) async {
    final String roomTypeId = (roomType['id'] ?? '').toString();
    final int totalRooms = SafeParse.parseInt(roomType['totalRooms']);
    final int sameTypeCount = existingRooms
        .where((Map<String, dynamic> room) => room['roomTypeId'] == roomTypeId)
        .length;
    if (sameTypeCount >= totalRooms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房型已達房間數上限')));
      return;
    }
    final RoomQuickCreateResult? result = await RoomQuickCreateSheet.show(
      context: context,
      shopId: widget.shopId,
      roomType: roomType,
      existingRooms: existingRooms,
    );
    if (!mounted || result == null) {
      return;
    }
    final String message = result.skippedCount > 0
        ? '已新增 ${result.createdCount} 間，略過 ${result.skippedCount} 個重複房號'
        : '已新增 ${result.createdCount} 間房';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showLegacyCleaningRepair() async {
    final List<Map<String, dynamic>> rooms = await ShopService.instance
        .getRooms(widget.shopId);
    final List<Map<String, dynamic>> legacy = ShopRoomService.instance
        .legacyCleaningRooms(rooms);
    if (!mounted) {
      return;
    }
    if (legacy.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('沒有可修復的舊清潔狀態')));
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('修復舊清潔狀態'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '這些房間的 rooms.status=cleaning 是舊版安親結算寫入的永久髒資料，確認後只會清掉該欄位，不會解鎖維修／封鎖房。',
                ),
                const SizedBox(height: 12),
                ...legacy.map((Map<String, dynamic> room) {
                  return Text(
                    '${room['name'] ?? room['id']}　${room['cleaningStartedAt']}',
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認修復'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    for (final Map<String, dynamic> room in legacy) {
      await ShopRoomService.instance.repairLegacyCleaningStatus(
        shopId: widget.shopId,
        roomId: (room['id'] ?? '').toString(),
      );
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已修復 ${legacy.length} 間房間的舊清潔狀態')));
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.embeddedInSetupCenter)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.healing_outlined),
                  tooltip: '修復舊清潔狀態',
                  onPressed: _showLegacyCleaningRepair,
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: '使用說明',
                  onPressed: _showRoomHelpDialog,
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '房號（例如 A1）'),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ShopService.instance.streamRoomTypes(widget.shopId),
                  builder: (context, typeSnapshot) {
                    final roomTypes = typeSnapshot.data ?? [];

                    if (roomTypes.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('尚未建立房型，請先到房型管理新增房型'),
                        ),
                      );
                    }

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: ShopService.instance.streamRooms(widget.shopId),
                      builder: (context, roomSnapshot) {
                        final rooms = roomSnapshot.data ?? [];

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: roomTypes.length,
                          itemBuilder: (context, index) {
                            final roomType = roomTypes[index];
                            final roomTypeId = roomType['id'] as String;
                            final roomTypeName = roomType['name'] ?? '未命名房型';
                            final totalRooms = roomType['totalRooms'] ?? 0;

                            final typeRooms =
                                rooms
                                    .where(
                                      (room) =>
                                          room['roomTypeId'] == roomTypeId,
                                    )
                                    .toList()
                                  ..sort((a, b) {
                                    final roomA = (a['name'] ?? '').toString();
                                    final roomB = (b['name'] ?? '').toString();

                                    return naturalCompare(roomA, roomB);
                                  });

                            final createdCount = typeRooms.length;
                            final remainingCount = totalRooms - createdCount;
                            final isExpanded =
                                _expandedRoomTypeId == roomTypeId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      roomTypeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '已建立 $createdCount / 設定 $totalRooms 間'
                                      '${remainingCount > 0 ? '｜還可建立 $remainingCount 間' : '｜已達上限'}',
                                      style: TextStyle(
                                        color: remainingCount > 0
                                            ? Colors.blue
                                            : Colors.green,
                                      ),
                                    ),
                                    trailing: Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _expandedRoomTypeId = isExpanded
                                            ? null
                                            : roomTypeId;
                                      });
                                    },
                                  ),

                                  if (isExpanded) ...[
                                    const Divider(height: 1),

                                    if (typeRooms.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          '此房型尚未建立實際房間',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),

                                    ...typeRooms.map((room) {
                                      final bool enabled = SafeParse.parseBool(
                                        room['enabled'],
                                        fallback: true,
                                      );
                                      return ListTile(
                                        title: Text(room['name'] ?? ''),
                                        subtitle: Text(
                                          enabled ? '已啟用' : '未啟用',
                                          style: TextStyle(
                                            color: enabled
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Tooltip(
                                              message: '啟用此房間',
                                              child: Switch(
                                                value: enabled,
                                                onChanged: (value) {
                                                  ShopService.instance
                                                      .updateRoomStatus(
                                                        shopId: widget.shopId,
                                                        roomId: room['id'],
                                                        enabled: value,
                                                      );
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                _deleteRoom(room['id']);
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }),

                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: remainingCount <= 0
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _selectedRoomTypeId =
                                                            roomTypeId;
                                                      });

                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '已選擇「$roomTypeName」，請在上方輸入房號新增',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              icon: const Icon(Icons.add),
                                              label: const Text('新增'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: remainingCount <= 0
                                                  ? null
                                                  : () {
                                                      _showBatchCreateRoomSheet(
                                                        roomType: roomType,
                                                        existingRooms: rooms,
                                                      );
                                                    },
                                              icon: const Icon(Icons.bolt),
                                              label: const Text('快速建房'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _createRoom,
                  child: const Text('新增房間'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
    if (widget.embeddedInSetupCenter) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('房間管理'),
        actions: [
          ShopTaskCenterButton(shopId: widget.shopId),
          IconButton(
            icon: const Icon(Icons.healing_outlined),
            tooltip: '修復舊清潔狀態',
            onPressed: _showLegacyCleaningRepair,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '使用說明',
            onPressed: _showRoomHelpDialog,
          ),
        ],
      ),
      body: body,
    );
  }

  void _showRoomHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('房間管理說明'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 此頁用來建立實際房間，例如 A01、A02。\n\n'
            '2. 房型管理設定幾間房，這裡就需要建立幾次房間。\n\n'
            '3. 每個房號不可重複，不同房型也不能使用同一個房號。\n\n'
            '4. 關閉房間後，前台不會將此房間納入可預約數量。\n\n'
            '5. 刪除房型時，底下所有房間也會一起刪除。\n\n'
            '6. 若只是某一天維修，請到房務管理設定單日關閉。',
            style: TextStyle(
              height: 1.6,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
