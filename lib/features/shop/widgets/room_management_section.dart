// 檔案名稱：lib/features/shop/widgets/room_management_section.dart
// 功能說明：房型卡片內嵌的房間列表、新增、啟用與刪除，不另開管理頁。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_quick_create_sheet.dart';

class RoomManagementSection extends StatefulWidget {
  const RoomManagementSection({
    super.key,
    required this.shopId,
    required this.roomType,
    required this.rooms,
    required this.canManage,
  });

  final String shopId;
  final Map<String, dynamic> roomType;
  final List<Map<String, dynamic>> rooms;
  final bool canManage;

  @override
  State<RoomManagementSection> createState() => _RoomManagementSectionState();
}

class _RoomManagementSectionState extends State<RoomManagementSection> {
  final TextEditingController _nameController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _roomTypeId => SafeParse.parseString(widget.roomType['id']);
  String get _roomTypeName =>
      SafeParse.parseString(widget.roomType['name'], fallback: '未命名房型');
  int get _limit => SafeParse.parseInt(widget.roomType['totalRooms']);

  List<Map<String, dynamic>> get _sortedRooms {
    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
      widget.rooms,
    );
    list.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      return naturalCompare(
        SafeParse.parseString(a['name']),
        SafeParse.parseString(b['name']),
      );
    });
    return list;
  }

  Future<void> _createRoom() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫房號')));
      return;
    }
    final List<Map<String, dynamic>> roomTypes = await ShopService.instance
        .getRoomTypes(widget.shopId);
    final Map<String, dynamic> selectedType = roomTypes.firstWhere(
      (Map<String, dynamic> e) => e['id'] == _roomTypeId,
      orElse: () => widget.roomType,
    );
    final int totalRooms = SafeParse.parseInt(selectedType['totalRooms']);
    final List<Map<String, dynamic>> allRooms = await ShopService.instance
        .getRooms(widget.shopId);
    final List<Map<String, dynamic>> sameTypeRooms = allRooms
        .where(
          (Map<String, dynamic> room) =>
              SafeParse.parseString(room['roomTypeId']) == _roomTypeId,
        )
        .toList();
    final DocumentSnapshot<Map<String, dynamic>> shopDoc =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .get();
    final Map<String, dynamic> shop = shopDoc.data() ?? <String, dynamic>{};
    final int planLimit = ShopPlanService.roomLimit(shop);
    if (allRooms.length >= planLimit) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('免費版最多建立 $planLimit 間房間，升級 999 方案即可解除限制')),
      );
      return;
    }
    if (sameTypeRooms.length >= totalRooms) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房型已達最大房間數')));
      return;
    }
    final bool isDuplicate = allRooms.any(
      (Map<String, dynamic> room) =>
          SafeParse.parseString(room['name']) == name,
    );
    if (isDuplicate) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房號已存在，請使用不同房號')));
      return;
    }
    await ShopService.instance.createRoom(
      shopId: widget.shopId,
      name: name,
      roomTypeId: _roomTypeId,
    );
    if (!mounted) {
      return;
    }
    _nameController.clear();
    setState(() => _adding = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('新增房間成功')));
  }

  Future<void> _renameRoom(Map<String, dynamic> room) async {
    final TextEditingController controller = TextEditingController(
      text: SafeParse.parseString(room['name']),
    );
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('編輯房號'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '房號'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null || next.isEmpty || !mounted) {
      return;
    }
    final List<Map<String, dynamic>> allRooms = await ShopService.instance
        .getRooms(widget.shopId);
    final bool duplicate = allRooms.any((Map<String, dynamic> item) {
      return SafeParse.parseString(item['id']) !=
              SafeParse.parseString(room['id']) &&
          SafeParse.parseString(item['name']) == next;
    });
    if (duplicate) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房號已存在，請使用不同房號')));
      return;
    }
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('rooms')
        .doc(SafeParse.parseString(room['id']))
        .update(<String, dynamic>{
          'name': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已更新房號')));
  }

  Future<void> _deleteRoom(String roomId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: const Text('確定要刪除此房間嗎？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }
    await ShopService.instance.deleteRoom(
      shopId: widget.shopId,
      roomId: roomId,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除房間')));
  }

  Future<void> _openQuickCreate() async {
    try {
      final List<Map<String, dynamic>> allRooms = await ShopService.instance
          .getRooms(widget.shopId);
      if (!mounted) {
        return;
      }
      final RoomQuickCreateResult? result = await RoomQuickCreateSheet.show(
        context: context,
        shopId: widget.shopId,
        roomType: widget.roomType,
        existingRooms: allRooms,
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法開啟快速建房：$error')));
    }
  }

  Widget _actionButtons({required bool atCap, required bool compact}) {
    final Widget addButton = FilledButton.tonalIcon(
      onPressed: atCap
          ? null
          : () {
              setState(() => _adding = true);
            },
      icon: const Icon(Icons.add),
      label: const Text('新增房間'),
    );
    final Widget quickButton = FilledButton.icon(
      onPressed: atCap ? null : _openQuickCreate,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('快速建房'),
    );
    if (compact) {
      return Row(
        children: <Widget>[
          Expanded(child: addButton),
          const SizedBox(width: 8),
          Expanded(child: quickButton),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[addButton, const SizedBox(width: 8), quickButton],
    );
  }

  String _statusLabel(Map<String, dynamic> room) {
    final bool enabled = SafeParse.parseBool(room['enabled'], fallback: true);
    final String permanent = DaycareOccupancyService.permanentStatusOf(room);
    final bool paused = DaycareOccupancyService.isPermanentStatusUnsellable(
      permanent,
    );
    if (!enabled) {
      return '未啟用';
    }
    if (paused) {
      return '暫停預約';
    }
    return '可預約';
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rooms = _sortedRooms;
    final int created = rooms.length;
    final int remaining = _limit - created;
    final bool atCap = remaining <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 520;
              final Widget title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$_roomTypeName的房間',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '已建立 $created 間／上限 $_limit 間',
                    style: TextStyle(
                      fontSize: 12,
                      color: atCap
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                ],
              );
              if (!widget.canManage) {
                return title;
              }
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    title,
                    const SizedBox(height: 8),
                    _actionButtons(atCap: atCap, compact: true),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  _actionButtons(atCap: atCap, compact: false),
                ],
              );
            },
          ),
          if (atCap && widget.canManage)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('已達此房型的房間上限'),
            ),
          if (rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('此房型尚未建立實際房間'),
            ),
          ...rooms.map((Map<String, dynamic> room) {
            final bool enabled = SafeParse.parseBool(
              room['enabled'],
              fallback: true,
            );
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(SafeParse.parseString(room['name'])),
              subtitle: Text(_statusLabel(room)),
              trailing: widget.canManage
                  ? FittedBox(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Switch(
                            value: enabled,
                            onChanged: (bool value) {
                              ShopService.instance.updateRoomStatus(
                                shopId: widget.shopId,
                                roomId: SafeParse.parseString(room['id']),
                                enabled: value,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: '編輯房號',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _renameRoom(room),
                          ),
                          IconButton(
                            tooltip: '刪除',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _deleteRoom(SafeParse.parseString(room['id'])),
                          ),
                        ],
                      ),
                    )
                  : null,
            );
          }),
          if (widget.canManage && _adding && !atCap) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '房號（例如 A1）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _adding = false);
                    },
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _createRoom,
                    child: const Text('確認新增'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
