// lib/features/room/pages/room_dashboard_page.dart
// 🏨 房務管理（最終穩定版🔥 小日曆 + 防呆）

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'room_action_page.dart';
import 'package:petnest_saas/features/auth/pages/room_calendar_page.dart';

class RoomDashboardPage extends StatefulWidget {
  const RoomDashboardPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<RoomDashboardPage> createState() => _RoomDashboardPageState();
}

class _RoomDashboardPageState extends State<RoomDashboardPage> {
  DateTime selectedDate = DateTime.now();

  String get dateStr => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房務管理')),
      body: Column(
        children: [

          /// 📅 日期選擇
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

          /// 🏠 房間列表
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ShopService.instance.streamRooms(widget.shopId),
              builder: (context, snapshot) {
                final rooms = snapshot.data ?? [];

                if (rooms.isEmpty) {
                  return const Center(child: Text('尚無房間'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('shopId', isEqualTo: widget.shopId)
                      .where('status', whereIn: [
                        'pending',
                        'confirmed',
                        'checked_in',
                      ])
                      .snapshots(),
                  builder: (context, bookingSnap) {
                    final bookings = bookingSnap.data?.docs ?? [];

                    return ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];

                        /// 🔍 找今天訂單
                        Map<String, dynamic>? todayBooking;

                        for (var doc in bookings) {
                          final data = doc.data() as Map<String, dynamic>;

                          if (data['roomId'] != room['id']) continue;

                          final start =
                              (data['startDate'] as Timestamp).toDate();
                          final end =
                              (data['endDate'] as Timestamp).toDate();

                          final now = DateTime.parse(dateStr);

                          if (now.isAfter(start.subtract(const Duration(days: 1))) &&
                              now.isBefore(end)) {
                            todayBooking = data;
                            break;
                          }
                        }

                        /// 🔥 右邊顏色
                        Color color = Colors.green;

                        if (todayBooking != null) {
                          final status = todayBooking['status'] ?? '';

                          switch (status) {
                            case 'pending':
                            case 'confirmed':
                              color = Colors.orange;
                              break;
                            case 'checked_in':
                              color = Colors.blue;
                              break;
                            default:
                              color = Colors.green;
                          }
                        }

                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoomCalendarPage(
                                  shopId: widget.shopId,
                                  roomId: room['id'],
                                  roomName: room['name'] ?? '',
                                ),
                              ),
                            );
                          },

                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              /// 🏠 房名
                              Text(
                                room['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              if (todayBooking != null) ...[

                                const SizedBox(height: 4),

                                /// 👤 客戶
                                Text(
                                  todayBooking['customerName'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),

                                /// 📅 日期
                                Text(
                                  '${DateFormat('MM/dd').format(
                                    (todayBooking['startDate'] as Timestamp).toDate(),
                                  )} - ${DateFormat('MM/dd').format(
                                    (todayBooking['endDate'] as Timestamp).toDate(),
                                  )}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                /// 🔥 小日曆（防呆版）
                                Row(
                                  children: List.generate(7, (i) {
                                    final day =
                                        selectedDate.add(Duration(days: i));

                                    /// 🟢 預設空房
                                    Color dotColor = Colors.green;

                                    /// ❗ 防 null crash
                                    if (todayBooking == null) {
                                      return _buildDot(dotColor);
                                    }

                                    final start =
                                        (todayBooking['startDate'] as Timestamp)
                                            .toDate();
                                    final end =
                                        (todayBooking['endDate'] as Timestamp)
                                            .toDate();
                                    final status =
                                        todayBooking['status'] ?? '';

                                    if (day.isAfter(start.subtract(const Duration(days: 1))) &&
                                        day.isBefore(end)) {

                                      switch (status) {
                                        case 'pending':
                                        case 'confirmed':
                                          dotColor = Colors.orange;
                                          break;
                                        case 'checked_in':
                                          dotColor = Colors.blue;
                                          break;
                                      }
                                    }

                                    return _buildDot(dotColor);
                                  }),
                                ),
                              ],
                            ],
                          ),

                          /// 🔥 右邊大顆狀態
                          trailing: _buildBigDot(color),
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

  /// 🔵 小圓點
  Widget _buildDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// 🔵 大圓點
  Widget _buildBigDot(Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}