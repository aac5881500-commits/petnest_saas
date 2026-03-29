// 檔案名稱 lib/features/auth/pages/shop_room_calendar_page.dart
// 📅 房間日曆管理（第一版）

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopRoomCalendarPage extends StatefulWidget {
  const ShopRoomCalendarPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopRoomCalendarPage> createState() =>
      _ShopRoomCalendarPageState();
}

class _ShopRoomCalendarPageState extends State<ShopRoomCalendarPage> {
  DateTime selectedDate = DateTime.now();

  String get dateStr => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房間日曆')),
      body: Column(
        children: [
          /// 日期選擇
          ListTile(
            title: Text('日期：$dateStr'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );

              if (picked != null) {
                setState(() => selectedDate = picked);
              }
            },
          ),


          /// 房間列表
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream:
                  ShopService.instance.streamRooms(widget.shopId),
              builder: (context, roomSnap) {
                final rooms = roomSnap.data ?? [];

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ShopService.instance
                      .streamRoomCalendarByDate(
                    widget.shopId,
                    dateStr,
                  ),
                  builder: (context, calSnap) {
                    final calendar = calSnap.data ?? [];

                    return ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];

                        final cal = calendar.firstWhere(
                          (e) => e['roomId'] == room['id'],
                          orElse: () => {},
                        );

                        final status =
                            cal['status'] ?? 'available';

                        return ListTile(
                          title: Text(room['name']),
                          subtitle: Text('狀態：$status'),
                          trailing: DropdownButton<String>(
                            value: status,
                            items: const [
                              DropdownMenuItem(
                                value: 'available',
                                child: Text('可用'),
                              ),
                              DropdownMenuItem(
                                value: 'blocked',
                                child: Text('關閉'),
                              ),
                              DropdownMenuItem(
                                value: 'cleaning',
                                child: Text('清潔中'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              ShopService.instance.setRoomStatus(
                                shopId: widget.shopId,
                                roomId: room['id'],
                                date: dateStr,
                                status: value,
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}