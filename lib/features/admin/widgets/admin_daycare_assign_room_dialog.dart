// 檔案名稱：lib/features/admin/widgets/admin_daycare_assign_room_dialog.dart
// 功能說明：臨托確認後分房：先選房型，再選此時段無衝突的實際房間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_assign_room_rules.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';

Future<void> showDaycareAssignRoomDialog({
  required BuildContext context,
  required String shopId,
  required String bookingId,
  required Map<String, dynamic> booking,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _AssignRoomDialog(
        shopId: shopId,
        bookingId: bookingId,
        booking: booking,
      );
    },
  );
}

class _AssignRoomDialog extends StatefulWidget {
  const _AssignRoomDialog({
    required this.shopId,
    required this.bookingId,
    required this.booking,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;

  @override
  State<_AssignRoomDialog> createState() => _AssignRoomDialogState();
}

class _AssignRoomDialogState extends State<_AssignRoomDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _selectedTypeId;
  String? _selectedRoomId;
  List<DaycareAssignableRoom> _rooms = const <DaycareAssignableRoom>[];

  bool get _roomTypeLocked =>
      DaycareAssignRoomRules.lockRoomType(widget.booking);

  String get _requestedTypeId =>
      DaycareAssignRoomRules.requestedRoomTypeId(widget.booking);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DateTime? start = _ts(widget.booking['scheduledStartAt']);
    final DateTime? end = _ts(widget.booking['scheduledEndAt']);
    if (start == null || end == null) {
      setState(() {
        _loading = false;
        _error = '訂單時間不完整，無法分房';
      });
      return;
    }
    final List<dynamic> pets = widget.booking['petIds'] is List
        ? widget.booking['petIds'] as List<dynamic>
        : const <dynamic>[];
    try {
      final List<DaycareAssignableRoom> listed = await DaycareOccupancyService
          .instance
          .listAssignableRooms(
            shopId: widget.shopId,
            startAt: start,
            endAt: end,
            petCount: pets.isEmpty ? 1 : pets.length,
            excludeBookingId: widget.bookingId,
          );
      if (!mounted) {
        return;
      }
      List<DaycareAssignableRoom> rooms = List<DaycareAssignableRoom>.from(
        listed,
      );
      if (_roomTypeLocked) {
        final DaycareSettingsModel settings = await DaycareSettingsService
            .instance
            .get(widget.shopId);
        if (!mounted) {
          return;
        }
        final DocumentSnapshot<Map<String, dynamic>> typeSnap =
            await FirebaseFirestore.instance
                .collection('shops')
                .doc(widget.shopId)
                .collection('room_types')
                .doc(_requestedTypeId)
                .get();
        final DaycareRoomTypeSetting? setting = settings.roomTypeSetting(
          _requestedTypeId,
        );
        if (!typeSnap.exists || setting == null || setting.enabled != true) {
          setState(() {
            _error = '客戶選擇的房型不存在或已停用，無法分配房間';
            _loading = false;
          });
          return;
        }
        rooms = listed
            .where(
              (DaycareAssignableRoom room) =>
                  room.roomTypeId == _requestedTypeId,
            )
            .toList();
      }
      _sortAssignableRooms(rooms);
      setState(() {
        _rooms = rooms;
        _selectedTypeId = _roomTypeLocked
            ? _requestedTypeId
            : (rooms.isEmpty ? null : rooms.first.roomTypeId);
        _selectedRoomId = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _assign(DaycareAssignableRoom room) async {
    if (!DaycareAssignRoomRules.allowsAssignedRoomType(
      booking: widget.booking,
      assignedRoomTypeId: room.roomTypeId,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不可更換客戶選擇的房型')));
      return;
    }
    setState(() => _saving = true);
    try {
      await DaycareFunctionService.instance.assignRoom(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        roomId: room.roomId,
        roomName: room.roomName,
        roomTypeId: room.roomTypeId,
        roomTypeName: room.roomTypeName,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? start = _ts(widget.booking['scheduledStartAt']);
    final DateTime? end = _ts(widget.booking['scheduledEndAt']);
    final int petCount = (widget.booking['petIds'] is List)
        ? (widget.booking['petIds'] as List).length
        : 0;
    final String currentRoom =
        (widget.booking['roomName'] ??
                widget.booking['roomNumberSnapshot'] ??
                '')
            .toString()
            .trim();
    final Set<String> typeIds = _rooms
        .map((DaycareAssignableRoom room) => room.roomTypeId)
        .toSet();
    final List<DaycareAssignableRoom> filtered = _rooms
        .where(
          (DaycareAssignableRoom room) =>
              _selectedTypeId == null || room.roomTypeId == _selectedTypeId,
        )
        .toList();
    _sortAssignableRooms(filtered);
    DaycareAssignableRoom? selectedRoom;
    for (final DaycareAssignableRoom room in filtered) {
      if (room.roomId == _selectedRoomId) {
        selectedRoom = room;
        break;
      }
    }
    final DaycareAssignableRoom? picked = selectedRoom;
    final bool canConfirm = !_saving && picked != null && picked.available;
    return AlertDialog(
      title: const Text('分配房間'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Text(_error!)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (start != null && end != null)
                    Text(
                      '${DaycareTimeHelper.formatDate(start)}  '
                      '${DaycareTimeHelper.formatHm(start)}-'
                      '${DaycareTimeHelper.formatHm(end)}',
                    ),
                  Text('寵物數：$petCount'),
                  if (_roomTypeLocked) Text('客戶選擇房型：${_lockedRoomTypeName()}'),
                  if (currentRoom.isNotEmpty) Text('目前已分配：$currentRoom'),
                  const SizedBox(height: 8),
                  if (!_roomTypeLocked)
                    Wrap(
                      spacing: 8,
                      children: typeIds.map((String id) {
                        final String name = _rooms
                            .firstWhere(
                              (DaycareAssignableRoom room) =>
                                  room.roomTypeId == id,
                            )
                            .roomTypeName;
                        return ChoiceChip(
                          label: Text(name),
                          selected: _selectedTypeId == id,
                          onSelected: (_) {
                            setState(() {
                              _selectedTypeId = id;
                              _selectedRoomId = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: filtered.isEmpty
                        ? const Text('此房型目前沒有房間可列出。')
                        : ListView(
                            shrinkWrap: true,
                            children: filtered.map((
                              DaycareAssignableRoom room,
                            ) {
                              final bool canPick = room.available && !_saving;
                              final bool selected =
                                  _selectedRoomId == room.roomId;
                              return Card(
                                color: canPick
                                    ? (selected ? Colors.indigo.shade50 : null)
                                    : Colors.grey.shade200,
                                child: ListTile(
                                  enabled: canPick,
                                  selected: selected,
                                  leading: Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.meeting_room_outlined,
                                  ),
                                  title: Text(
                                    '${room.roomName}　${room.roomTypeName}',
                                  ),
                                  subtitle: Text(
                                    <String>[
                                      if (room.capacity > 0)
                                        '容量 ${room.capacity} 隻',
                                      if (room.status.trim().isNotEmpty)
                                        '狀態 ${room.status}',
                                      if (room.available)
                                        '此時段可分配'
                                      else
                                        room.blockedReason,
                                    ].join('\n'),
                                  ),
                                  onTap: canPick
                                      ? () => setState(
                                          () => _selectedRoomId = room.roomId,
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: canConfirm ? () => _assign(picked) : null,
          child: const Text('確認分配'),
        ),
      ],
    );
  }

  String _lockedRoomTypeName() {
    final String named = (widget.booking['requestedRoomTypeName'] ?? '')
        .toString()
        .trim();
    if (named.isNotEmpty) {
      return named;
    }
    for (final DaycareAssignableRoom room in _rooms) {
      if (room.roomTypeId == _requestedTypeId) {
        return room.roomTypeName;
      }
    }
    return _requestedTypeId;
  }

  static void _sortAssignableRooms(List<DaycareAssignableRoom> rooms) {
    rooms.sort((DaycareAssignableRoom a, DaycareAssignableRoom b) {
      return compareRoomCodes(
        a.roomCode.trim().isEmpty ? a.roomName : a.roomCode,
        b.roomCode.trim().isEmpty ? b.roomName : b.roomCode,
        tieA: a.roomId,
        tieB: b.roomId,
      );
    });
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
}
