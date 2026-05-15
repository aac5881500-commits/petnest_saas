// lib/features/room/pages/room_dashboard_page.dart
// 🏨 房務管理（最終穩定版🔥 小日曆 + 防呆）

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
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

  DateTime get weekStart {
  final d = selectedDate;
  return DateTime(d.year, d.month, d.day)
      .subtract(Duration(days: d.weekday - 1));
}

List<DateTime> get weekDays {
  return List.generate(
    7,
    (index) => weekStart.add(Duration(days: index)),
  );
}

  String get dateStr => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房務管理')),
      body: Column(
        children: [
/// 📅 週日期切換
Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
  child: Row(
    children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () {
          setState(() {
            selectedDate = selectedDate.subtract(const Duration(days: 7));
          });
        },
      ),
      Expanded(
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(7, (i) {
      final day = weekDays[i];
      final isSelected =
    day.year == selectedDate.year &&
    day.month == selectedDate.month &&
    day.day == selectedDate.day;

      final weekNames = [
        '一',
        '二',
        '三',
        '四',
        '五',
        '六',
        '日',
      ];

      return GestureDetector(
  onTap: () {
    setState(() {
      selectedDate = day;
    });
  },
  child: Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isSelected ? Colors.blue : Colors.transparent,
    ),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
          Text(
            '${day.month}/${day.day}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weekNames[i],
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
       ],
),
),
);
    }),
  ),
),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: () {
          setState(() {
            selectedDate = selectedDate.add(const Duration(days: 7));
          });
        },
      ),
    ],
  ),
),
          /// 🏠 房間列表
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ShopService.instance.streamRooms(widget.shopId),
              builder: (context, snapshot) {
                final rooms = snapshot.data ?? [];

rooms.sort((a, b) {
  final aName = (a['name'] ?? '').toString();
  final bName = (b['name'] ?? '').toString();

  return aName.compareTo(bName);
});
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

  return StreamBuilder<QuerySnapshot>(
    stream: ShopService.instance
        .roomCalendarRef(widget.shopId)
        .snapshots(),
    builder: (context, calendarSnap) {
      final calendarDocs = calendarSnap.data?.docs ?? [];

      final roomCalendarStatus = <String, String>{};

      for (var doc in calendarDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final roomId = (data['roomId'] ?? '').toString();
        final date = (data['date'] ?? '').toString();
        final status = (data['status'] ?? '').toString();

        roomCalendarStatus['$roomId|$date'] = status;
      }

final roomStatusList = rooms.map((room) {
  Map<String, dynamic>? todayBooking;

  for (var doc in bookings) {
    final data = doc.data() as Map<String, dynamic>;

    if (data['roomId'] != room['id']) continue;

    final start = (data['startDate'] as Timestamp).toDate();
    final end = (data['endDate'] as Timestamp).toDate();
    final now = DateTime.parse(dateStr);

    if (now.isAfter(start.subtract(const Duration(days: 1))) &&
        now.isBefore(end)) {
      todayBooking = data;
      break;
    }
  }

  final roomId = (room['id'] ?? '').toString();
final roomStatus = roomCalendarStatus['$roomId|$dateStr'];

if (roomStatus == 'blocked') {
  return '維修中';
}

return _getRoomStatusText(todayBooking);
}).toList();

final emptyCount =
    roomStatusList.where((status) => status == '空房').length;
final checkInCount =
    roomStatusList.where((status) => status == '今日入住').length;
final stayingCount =
    roomStatusList.where((status) => status == '入住中').length;
    final blockedCount =
    roomStatusList.where((status) => status == '維修中').length;

                    return Column(
  children: [
    Padding(
  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '目前顯示：${DateFormat('yyyy-MM-dd').format(selectedDate)} 當日房況',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          _buildSummaryCard('空房', emptyCount, Colors.green),
          const SizedBox(width: 8),
          _buildSummaryCard('今日入住', checkInCount, Colors.orange),
          const SizedBox(width: 8),
          _buildSummaryCard('入住中', stayingCount, Colors.blue),
                ],
      ),
    ],
  ),
),
    Expanded(
      child: ListView.builder(
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
                              color = Colors.red;
                              break;
                            case 'checked_in':
                              color = Colors.blue;
                              break;
                            default:
                              color = Colors.green;
                          }
                        }

                       return InkWell(
  onTap: () async {
  String roomTypeName = '未設定房型';
  String roomImageUrl = '';

  final roomTypeId = room['roomTypeId'] ?? '';

  if (roomTypeId.toString().isNotEmpty) {
    final roomTypeDoc = await FirebaseFirestore.instance
    .collection('shops')
    .doc(widget.shopId)
    .collection('room_types')
    .doc(roomTypeId)
    .get();

    final roomTypeData = roomTypeDoc.data();

    if (roomTypeData != null) {
      roomTypeName = roomTypeData['name'] ?? '未設定房型';

      final images = roomTypeData['images'];

if (images is List && images.isNotEmpty) {
  final firstImage = images.first;

  if (firstImage is String) {
    roomImageUrl = firstImage;
  } else if (firstImage is Map) {
    roomImageUrl = firstImage['imageUrl']?.toString() ?? '';
  }
}
    }
  }

  if (!context.mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RoomCalendarPage(
        shopId: widget.shopId,
        roomId: room['id'],
        roomName: room['name'] ?? '',
        roomTypeName: roomTypeName,
        roomImageUrl: roomImageUrl,
      ),
    ),
  );
},
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        /// 房號
       SizedBox(
  width: 78,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Text(
        room['roomTypeName'] ?? '未分類',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),

      const SizedBox(height: 2),

      Text(
        room['name'] ?? '',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF222222),
        ),
      ),
    ],
  ),
),

        const SizedBox(width: 8),

        /// 中間資訊
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todayBooking != null) ...[
                Text(
                  todayBooking['customerName'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MM/dd').format(
                    (todayBooking['startDate'] as Timestamp).toDate(),
                  )} - ${DateFormat('MM/dd').format(
                    (todayBooking['endDate'] as Timestamp).toDate(),
                  )}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 6),
              ] else ...[
                const Text(
                  '空房',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              /// 近 7 天小圓點
              /// 星期 + 近 7 天狀態
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Row(
      children: const [
        _WeekText('一'),
        _WeekText('二'),
        _WeekText('三'),
        _WeekText('四'),
        _WeekText('五'),
        _WeekText('六'),
        _WeekText('日'),
      ],
    ),

    const SizedBox(height: 4),

    Row(
      children: List.generate(7, (i) {
                  final day = weekDays[i];
final dayKey = DateFormat('yyyy-MM-dd').format(day);
final roomId = (room['id'] ?? '').toString();

Color dotColor = Colors.green;

final manualStatus = roomCalendarStatus['$roomId|$dayKey'];

if (manualStatus == 'blocked') {
  dotColor = Colors.black;
}
for (var doc in bookings) {
  final data = doc.data() as Map<String, dynamic>;

  if (data['roomId'] != room['id']) continue;

  final start = (data['startDate'] as Timestamp).toDate();
  final end = (data['endDate'] as Timestamp).toDate();
  final status = data['status'] ?? '';

  final dayOnly = DateTime(day.year, day.month, day.day);
  final startOnly = DateTime(start.year, start.month, start.day);
  final endOnly = DateTime(end.year, end.month, end.day);

  if (!dayOnly.isBefore(startOnly) && dayOnly.isBefore(endOnly)) {
  if (status == 'checked_in') {
    dotColor = Colors.blue;
  } else {
    dotColor = Colors.red;
  }
  break;
}
}

return _buildDot(dotColor);
}),
),
],
),
            ],
          ),
        ),

        const SizedBox(width: 8),

        /// 右邊狀態
        _buildStatusChip(
          color: color,
          text: _getRoomStatusText(todayBooking),
        ),

        const SizedBox(width: 4),

        const Icon(
          Icons.chevron_right,
          size: 20,
          color: Colors.grey,
        ),
      ],
    ),
  ),
);
                             },
      ),
    ),
  ],
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

 /// 🔥 房間狀態文字
String _getRoomStatusText(Map<String, dynamic>? booking) {
  if (booking == null) {
    return '空房';
  }

  final status = booking['status'] ?? '';

  switch (status) {
    case 'pending':
    case 'confirmed':
      return '今日入住';
    case 'checked_in':
      return '入住中';
    default:
      return '空房';
  }
}

/// 🔥 狀態膠囊
Widget _buildStatusChip({
  required Color color,
  required String text,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}
/// 🔥 今日統計卡
Widget _buildSummaryCard(String title, int count, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
}
class _WeekText extends StatelessWidget {
  const _WeekText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}