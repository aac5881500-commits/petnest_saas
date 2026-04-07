// lib/features/auth/pages/room_calendar_page.dart
// 🗓 房間日曆（最終完整版🔥 訂單自動上色）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomCalendarPage extends StatefulWidget {
  const RoomCalendarPage({
    super.key,
    required this.shopId,
    required this.roomId,
    required this.roomName,
  });

  final String shopId;
  final String roomId;
  final String roomName;

  @override
  State<RoomCalendarPage> createState() => _RoomCalendarPageState();
}

class _RoomCalendarPageState extends State<RoomCalendarPage> {
  DateTime _currentMonth = DateTime.now();

  int bookingRangeDays = 30;

  String _format(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lastAllowedDate = today.add(Duration(days: bookingRangeDays));

    return Scaffold(
      appBar: AppBar(
        title: Text('房間日曆 - ${widget.roomName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            },
          ),
          Center(
            child: Text(
              '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),

      body: StreamBuilder(
        stream: ShopService.instance
            .roomCalendarRef(widget.shopId)
            .where('roomId', isEqualTo: widget.roomId)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          final map = <String, String>{};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            map[data['date']] = data['status'];
          }

          /// 🔥 訂單監聽
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('shopId', isEqualTo: widget.shopId)
                .where('roomId', isEqualTo: widget.roomId)
                .where('status', whereIn: ['pending', 'confirmed'])
                .snapshots(),
            builder: (context, bookingSnap) {
              final bookings = bookingSnap.data?.docs ?? [];

              final daysInMonth = DateUtils.getDaysInMonth(
                _currentMonth.year,
                _currentMonth.month,
              );

              return Column(
                children: [

                  /// 📅 月曆
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                      ),
                      itemCount: daysInMonth,
                      itemBuilder: (context, index) {
                        final date = DateTime(
                          _currentMonth.year,
                          _currentMonth.month,
                          index + 1,
                        );

                        final key = _format(date);

                        /// 🔥 預設狀態
                        String status = map[key] ?? 'available';

                        /// 🔥 訂單覆蓋（紅色）
                        for (var doc in bookings) {
                          final data =
                              doc.data() as Map<String, dynamic>;

                          final start =
                              (data['startDate'] as Timestamp).toDate();
                          final end =
                              (data['endDate'] as Timestamp).toDate();

                          final dateObj = DateTime.parse(key);

                          if (dateObj.isAfter(
                                  start.subtract(const Duration(days: 1))) &&
                              dateObj.isBefore(end)) {
                            status = 'booked';
                            break;
                          }
                        }

                        /// 🔥 可操作範圍
                        final isDisabled = date.isBefore(today) ||
                            date.isAfter(lastAllowedDate);

                        /// 🎨 顏色
                        Color color;
                        switch (status) {
                          case 'booked':
                            color = Colors.red;
                            break;
                          case 'occupied':
                            color = Colors.blue;
                            break;
                          case 'cleaning':
                          case 'blocked':
                            color = Colors.black;
                            break;
                          default:
                            color = Colors.green;
                        }

                        if (isDisabled) {
                          color = Colors.grey.shade300;
                        }

                        return GestureDetector(
                          onTap: isDisabled
                              ? null
                              : () async {
                                  final current =
                                      map[key] ?? 'available';

                                  String next;
                                  switch (current) {
                                    case 'available':
                                      next = 'blocked';
                                      break;
                                    case 'blocked':
                                      next = 'cleaning';
                                      break;
                                    case 'cleaning':
                                      next = 'available';
                                      break;
                                    default:
                                      next = 'available';
                                  }

                                  await ShopService.instance
                                      .setRoomStatus(
                                    shopId: widget.shopId,
                                    roomId: widget.roomId,
                                    date: key,
                                    status: next,
                                  );
                                },
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isDisabled
                                      ? Colors.grey
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  /// 🔥 圖例
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        _legend(Colors.green, '空房'),
                        _legend(Colors.red, '已訂'),
                        _legend(Colors.blue, '入住'),
                        _legend(Colors.black, '清潔/整修'),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}