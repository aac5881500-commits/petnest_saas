// lib/features/admin/widgets/admin_daycare_assign_room_dialog.dart
// 🐾 臨托確認後分房：先選房型，再選此時段無衝突的實際房間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

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
  List<DaycareAssignableRoom> _rooms = const <DaycareAssignableRoom>[];

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
      final List<DaycareAssignableRoom> rooms = await DaycareOccupancyService
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
      setState(() {
        _rooms = rooms;
        _selectedTypeId = rooms.isEmpty ? null : rooms.first.roomTypeId;
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
    final Set<String> typeIds = _rooms
        .map((DaycareAssignableRoom room) => room.roomTypeId)
        .toSet();
    final List<DaycareAssignableRoom> filtered = _rooms
        .where(
          (DaycareAssignableRoom room) =>
              _selectedTypeId == null || room.roomTypeId == _selectedTypeId,
        )
        .toList();
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
            : _rooms.isEmpty
            ? const Text('目前沒有可分配的房間，請改約其他時間或取消訂單。')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (start != null && end != null)
                    Text(
                      '${DaycareTimeHelper.formatDate(start)}  '
                      '${DaycareTimeHelper.formatHm(start)}-'
                      '${DaycareTimeHelper.formatHm(end)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. 選擇房型',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: typeIds.map((String id) {
                      final String name = _rooms
                          .firstWhere(
                            (DaycareAssignableRoom room) =>
                                room.roomTypeId == id,
                          )
                          .roomTypeName;
                      final bool selected = _selectedTypeId == id;
                      return ChoiceChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedTypeId = id);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '2. 選擇實際房間',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView(
                      shrinkWrap: true,
                      children: filtered.map((DaycareAssignableRoom room) {
                        return Card(
                          child: ListTile(
                            enabled: !_saving,
                            leading: const Icon(Icons.meeting_room),
                            title: Text(
                              '${room.roomTypeName}　${room.roomName}',
                            ),
                            subtitle: Text(
                              <String>[
                                if (room.capacity > 0) '容量 ${room.capacity} 隻',
                                if (room.status == 'cleaning') '待清潔',
                                if (room.overlappingSummaries.isNotEmpty)
                                  room.overlappingSummaries.join('、'),
                                if (room.overlappingSummaries.isEmpty)
                                  '此時段無其他訂單',
                              ].join('\n'),
                            ),
                            onTap: _saving ? null : () => _assign(room),
                          ),
                        );
                      }).toList(),
                    ),
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
      ],
    );
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
