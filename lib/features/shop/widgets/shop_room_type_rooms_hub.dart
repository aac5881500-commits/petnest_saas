// 檔案名稱：lib/features/shop/widgets/shop_room_type_rooms_hub.dart
// 功能說明：房型與房間同一操作畫面：左預覽、右管理，房間內嵌於房型卡片。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/widgets/room_management_section.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_editor.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';

class ShopRoomTypeRoomsHub extends StatefulWidget {
  const ShopRoomTypeRoomsHub({
    super.key,
    required this.shopId,
    this.embeddedInSetupCenter = false,
    this.canManageRoomTypes = true,
    this.canManageRooms = true,
    this.roomTypesStream,
    this.roomsStream,
  });

  final String shopId;
  final bool embeddedInSetupCenter;
  final bool canManageRoomTypes;
  final bool canManageRooms;
  final Stream<List<Map<String, dynamic>>>? roomTypesStream;
  final Stream<List<Map<String, dynamic>>>? roomsStream;

  @override
  State<ShopRoomTypeRoomsHub> createState() => _ShopRoomTypeRoomsHubState();
}

class _ShopRoomTypeRoomsHubState extends State<ShopRoomTypeRoomsHub> {
  String? _selectedRoomTypeId;
  final Set<String> _expandedIds = <String>{};
  bool _creating = false;
  Map<String, dynamic>? _editing;
  ShopRoomTypeDraft? _draft;
  bool _mobilePreview = false;

  static const double splitMinWidth = 1100;

  void _ensureSelection(List<Map<String, dynamic>> types) {
    if (types.isEmpty) {
      _selectedRoomTypeId = null;
      return;
    }
    final bool exists = types.any(
      (Map<String, dynamic> item) =>
          SafeParse.parseString(item['id']) == _selectedRoomTypeId,
    );
    if (!exists) {
      _selectedRoomTypeId = SafeParse.parseString(types.first['id']);
    }
  }

  Future<void> _deleteRoomType(Map<String, dynamic> item) async {
    final String roomTypeId = SafeParse.parseString(item['id']);
    final String roomTypeName = SafeParse.parseString(
      item['name'],
      fallback: '此房型',
    );
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除房型'),
          content: Text('確定要刪除「$roomTypeName」嗎？刪除後，這個房型底下建立的房間也會一併刪除，且無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }
    final List<Map<String, dynamic>> rooms = await ShopService.instance
        .getRooms(widget.shopId);
    final Iterable<Map<String, dynamic>> targetRooms = rooms.where(
      (Map<String, dynamic> room) =>
          SafeParse.parseString(room['roomTypeId']) == roomTypeId,
    );
    for (final Map<String, dynamic> room in targetRooms) {
      await ShopService.instance.deleteRoom(
        shopId: widget.shopId,
        roomId: SafeParse.parseString(room['id']),
      );
    }
    await ShopService.instance.deleteRoomType(
      shopId: widget.shopId,
      roomTypeId: roomTypeId,
    );
    final User? user = FirebaseAuth.instance.currentUser;
    await ActionLogService.instance.logAction(
      shopId: widget.shopId,
      targetType: 'room_type',
      targetId: roomTypeId,
      action: '刪除房型',
      operatorUid: user?.uid ?? '',
      operatorRole: 'owner',
      payload: <String, dynamic>{
        'roomTypeName': roomTypeName,
        'deletedRoomCount': targetRooms.length,
      },
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除房型與其底下房間')));
  }

  ShopRoomTypeDraft _previewDraft(List<Map<String, dynamic>> types) {
    if (_creating || _editing != null) {
      return _draft ??
          ShopRoomTypeDraft.fromRoomType(_editing ?? <String, dynamic>{});
    }
    if (types.isEmpty) {
      return ShopRoomTypeDraft.fromRoomType(<String, dynamic>{});
    }
    final Map<String, dynamic> selected = types.firstWhere(
      (Map<String, dynamic> item) =>
          SafeParse.parseString(item['id']) == _selectedRoomTypeId,
      orElse: () => types.first,
    );
    return ShopRoomTypeDraft.fromRoomType(selected);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = StreamBuilder<List<Map<String, dynamic>>>(
      stream:
          widget.roomTypesStream ??
          ShopService.instance.streamRoomTypes(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> typeSnap,
          ) {
            if (typeSnap.hasError) {
              return const Center(child: Text('房型資料讀取失敗，請稍後再試'));
            }
            if (typeSnap.connectionState == ConnectionState.waiting &&
                !typeSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream:
                  widget.roomsStream ??
                  ShopService.instance.streamRooms(widget.shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> roomSnap,
                  ) {
                    if (roomSnap.hasError) {
                      return const Center(child: Text('房間資料讀取失敗，請稍後再試'));
                    }
                    if (roomSnap.connectionState == ConnectionState.waiting &&
                        !roomSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<Map<String, dynamic>> types =
                        typeSnap.data ?? <Map<String, dynamic>>[];
                    final List<Map<String, dynamic>> rooms =
                        roomSnap.data ?? <Map<String, dynamic>>[];
                    _ensureSelection(types);
                    return LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool split =
                                constraints.maxWidth >= splitMinWidth;
                            final Widget pane;
                            if (split) {
                              pane = Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 4,
                                      child:
                                          types.isEmpty &&
                                              !_creating &&
                                              _editing == null
                                          ? const Center(
                                              child: Text('新增房型後即可在此預覽'),
                                            )
                                          : ShopRoomTypeLivePreview(
                                              draft: _previewDraft(types),
                                            ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 6,
                                      child: _rightPane(types, rooms),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              pane = Column(
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      0,
                                    ),
                                    child: SegmentedButton<bool>(
                                      showSelectedIcon: false,
                                      segments: const <ButtonSegment<bool>>[
                                        ButtonSegment<bool>(
                                          value: false,
                                          label: Text('管理'),
                                        ),
                                        ButtonSegment<bool>(
                                          value: true,
                                          label: Text('前台預覽'),
                                        ),
                                      ],
                                      selected: <bool>{_mobilePreview},
                                      onSelectionChanged: (Set<bool> value) {
                                        setState(() {
                                          _mobilePreview = value.first;
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: IndexedStack(
                                      index: _mobilePreview ? 1 : 0,
                                      children: <Widget>[
                                        _rightPane(types, rooms),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            children: <Widget>[
                                              if (types.isNotEmpty)
                                                DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _selectedRoomTypeId,
                                                  items: types.map((
                                                    Map<String, dynamic> item,
                                                  ) {
                                                    final String id =
                                                        SafeParse.parseString(
                                                          item['id'],
                                                        );
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: id,
                                                      child: Text(
                                                        SafeParse.parseString(
                                                          item['name'],
                                                          fallback: '未命名房型',
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? id) {
                                                    setState(() {
                                                      _selectedRoomTypeId = id;
                                                    });
                                                  },
                                                ),
                                              Expanded(
                                                child:
                                                    types.isEmpty &&
                                                        !_creating &&
                                                        _editing == null
                                                    ? const Center(
                                                        child: Text(
                                                          '新增房型後即可在此預覽',
                                                        ),
                                                      )
                                                    : ShopRoomTypeLivePreview(
                                                        draft: _previewDraft(
                                                          types,
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Center(
                              child: SizedBox(
                                width: constraints.maxWidth > 1460
                                    ? 1460
                                    : constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: pane,
                              ),
                            );
                          },
                    );
                  },
            );
          },
    );

    if (widget.embeddedInSetupCenter) {
      return Material(color: const Color(0xFFF6F8FB), child: body);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('房型與房間管理'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
      ),
      body: body,
    );
  }

  Widget _rightPane(
    List<Map<String, dynamic>> types,
    List<Map<String, dynamic>> rooms,
  ) {
    if (_creating || _editing != null) {
      return ShopRoomTypeEditorPage(
        key: ValueKey<String>(
          _creating
              ? 'create-room-type'
              : 'edit-${SafeParse.parseString(_editing?['id'])}',
        ),
        shopId: widget.shopId,
        existing: _editing,
        embedded: true,
        onDraftChanged: (ShopRoomTypeDraft draft) {
          setState(() => _draft = draft);
        },
        onCancel: () {
          setState(() {
            _creating = false;
            _editing = null;
            _draft = null;
          });
        },
        onSaved: (String id) {
          setState(() {
            _creating = false;
            _editing = null;
            _draft = null;
            if (id.isNotEmpty) {
              _selectedRoomTypeId = id;
            }
          });
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '房型與房間管理',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '先建立客戶看到的房型，再於房型下建立實際房號。',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.canManageRoomTypes)
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _creating = true;
                    _editing = null;
                    _draft = null;
                    _mobilePreview = false;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('新增房型'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8D4B8)),
          ),
          child: const Text(
            '刪除房型時，該房型底下的房間也會一併刪除。若只是暫停開放，請停用房間或關閉可預約日期。',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF5C4A38),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (types.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: <Widget>[
                const Text('尚未建立房型'),
                const SizedBox(height: 12),
                if (widget.canManageRoomTypes)
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _creating = true;
                        _mobilePreview = false;
                      });
                    },
                    child: const Text('新增第一個房型'),
                  ),
              ],
            ),
          )
        else
          ...types.map((Map<String, dynamic> type) {
            return _RoomTypeManageCard(
              shopId: widget.shopId,
              roomType: type,
              rooms: rooms
                  .where(
                    (Map<String, dynamic> room) =>
                        SafeParse.parseString(room['roomTypeId']) ==
                        SafeParse.parseString(type['id']),
                  )
                  .toList(),
              selected:
                  SafeParse.parseString(type['id']) == _selectedRoomTypeId,
              expanded: _expandedIds.contains(
                SafeParse.parseString(type['id']),
              ),
              canManageTypes: widget.canManageRoomTypes,
              canManageRooms: widget.canManageRooms,
              onSelect: () {
                setState(() {
                  _selectedRoomTypeId = SafeParse.parseString(type['id']);
                });
              },
              onToggleExpand: () {
                final String id = SafeParse.parseString(type['id']);
                setState(() {
                  if (_expandedIds.contains(id)) {
                    _expandedIds.remove(id);
                  } else {
                    _expandedIds.add(id);
                  }
                  _selectedRoomTypeId = id;
                });
              },
              onEdit: () {
                setState(() {
                  _editing = type;
                  _creating = false;
                  _draft = ShopRoomTypeDraft.fromRoomType(type);
                  _selectedRoomTypeId = SafeParse.parseString(type['id']);
                  _mobilePreview = false;
                });
              },
              onDelete: () => _deleteRoomType(type),
            );
          }),
      ],
    );
  }
}

class _RoomTypeManageCard extends StatelessWidget {
  const _RoomTypeManageCard({
    required this.shopId,
    required this.roomType,
    required this.rooms,
    required this.selected,
    required this.expanded,
    required this.canManageTypes,
    required this.canManageRooms,
    required this.onSelect,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
  });

  final String shopId;
  final Map<String, dynamic> roomType;
  final List<Map<String, dynamic>> rooms;
  final bool selected;
  final bool expanded;
  final bool canManageTypes;
  final bool canManageRooms;
  final VoidCallback onSelect;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String name = SafeParse.parseString(
      roomType['name'],
      fallback: '未命名房型',
    );
    final int price = SafeParse.parseInt(roomType['price']);
    final int capacity = SafeParse.parseInt(roomType['capacity']);
    final int limit = SafeParse.parseInt(roomType['totalRooms']);
    final int enabledCount = rooms.where((Map<String, dynamic> room) {
      return SafeParse.parseBool(room['enabled'], fallback: true) &&
          !DaycareOccupancyService.isPermanentStatusUnsellable(
            DaycareOccupancyService.permanentStatusOf(room),
          );
    }).length;
    final List<String> images = SafeParse.parseList(roomType['images'])
        .map((dynamic e) => e.toString())
        .where((String url) => url.isNotEmpty)
        .toList();
    final bool bookable = enabledCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: selected ? colors.primary.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : const Color(0xFFE6EAF0),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onSelect,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: images.isEmpty
                          ? ColoredBox(
                              color: const Color(0xFFF1F3F7),
                              child: Icon(
                                Icons.bed_outlined,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : Image.network(
                              images.first,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return ColoredBox(
                                      color: const Color(0xFFF1F3F7),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey.shade500,
                                      ),
                                    );
                                  },
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'NT\$ $price / 晚　可住 $capacity 隻',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已建立 ${rooms.length}／上限 $limit　啟用中 $enabledCount　${bookable ? '可預約' : '不可預約'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManageTypes)
                    IconButton(
                      tooltip: '編輯房型',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return <PopupMenuEntry<String>>[
                        if (canManageTypes)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('編輯房型'),
                          ),
                        if (canManageTypes)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              '刪除房型',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: const Text('展開／收合房間'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggleExpand,
          ),
          if (expanded)
            RoomManagementSection(
              shopId: shopId,
              roomType: roomType,
              rooms: rooms,
              canManage: canManageRooms,
            ),
        ],
      ),
    );
  }
}
