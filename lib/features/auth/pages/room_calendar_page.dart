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
  required this.roomTypeName,
  required this.roomImageUrl,
});

final String shopId;
final String roomId;
final String roomName;
final String roomTypeName;
final String roomImageUrl;

  @override
  State<RoomCalendarPage> createState() => _RoomCalendarPageState();
}

class _RoomCalendarPageState extends State<RoomCalendarPage> {
  DateTime _currentMonth = DateTime.now();
DateTime? _selectedDate;
String _selectedStatus = 'available';

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
                .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
                .snapshots(),
            builder: (context, bookingSnap) {
              final bookings = bookingSnap.data?.docs ?? [];

              final daysInMonth = DateUtils.getDaysInMonth(
                _currentMonth.year,
                _currentMonth.month,
              );

final firstDayOfMonth = DateTime(
  _currentMonth.year,
  _currentMonth.month,
  1,
);

final leadingEmptyDays = firstDayOfMonth.weekday % 7;
final totalGridCount = daysInMonth + leadingEmptyDays;

              return Column(
                children: [

                  Container(
  width: double.infinity,
  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey.shade200),
  ),
  child: Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 72,
          height: 72,
          color: Colors.orange.withOpacity(0.12),
          child: widget.roomImageUrl.isNotEmpty
              ? Image.network(
                  widget.roomImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.meeting_room,
                      color: Colors.orange,
                      size: 34,
                    );
                  },
                )
              : const Icon(
                  Icons.meeting_room,
                  color: Colors.orange,
                  size: 34,
                ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.roomName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.roomTypeName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A5A32),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '房間月曆 / 可設定關閉單日房號',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

/// 🔥 月份切換列
Padding(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
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
      Text(
        '${_currentMonth.year} 年 ${_currentMonth.month} 月',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
),
/// 🔥 星期列
Padding(
  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
  child: Row(
    children: const [
      _WeekdayText('日'),
      _WeekdayText('一'),
      _WeekdayText('二'),
      _WeekdayText('三'),
      _WeekdayText('四'),
      _WeekdayText('五'),
      _WeekdayText('六'),
    ],
  ),
),

                 /// 📅 月曆主卡片
Expanded(
  child: Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      gridDelegate:
    const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 7,
  childAspectRatio: 0.72,
),
                      itemCount: totalGridCount,
itemBuilder: (context, index) {
  if (index < leadingEmptyDays) {
    return const SizedBox.shrink();
  }

  final dayNumber = index - leadingEmptyDays + 1;

  final date = DateTime(
    _currentMonth.year,
    _currentMonth.month,
    dayNumber,
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
                            if (data['status'] == 'checked_in') {
  status = 'occupied';
} else {
  status = 'booked';
}
break;
                          }
                        }

                        /// 🔥 可操作範圍
                       final isDisabled =
    date.isBefore(
      today.subtract(const Duration(days: 1)),
    ) ||
    date.isAfter(lastAllowedDate);

    final isSelected =
    _selectedDate != null &&
    date.year == _selectedDate!.year &&
    date.month == _selectedDate!.month &&
    date.day == _selectedDate!.day;

                        /// 🎨 顏色
                        Color color;
                        switch (status) {
                          case 'booked':
  color = Colors.deepOrange;
  break;
                          case 'occupied':
                            color = Colors.blue;
                            break;
                        
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
    : () {
        setState(() {
  _selectedDate = date;
  _selectedStatus = status;
});
      },
                          child: Container(
  margin: const EdgeInsets.all(5),
padding: const EdgeInsets.symmetric(vertical: 6),
  decoration: BoxDecoration(
    color: isDisabled
    ? Colors.grey.shade100
    : status == 'booked'
        ? Colors.deepOrange.withOpacity(0.05)
        : status == 'occupied'
            ? Colors.blue.withOpacity(0.06)
            : status == 'blocked'
                ? Colors.black.withOpacity(0.04)
                    : Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
  color: isSelected
    ? Colors.blue
    : isDisabled
        ? Colors.grey.shade300
        : color.withOpacity(0.35),
width: isSelected ? 2 : 1,
),
    boxShadow: isDisabled
        ? []
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        '$dayNumber',
        style: TextStyle(
          color: isDisabled
    ? Colors.grey
    : const Color(0xFF333333),
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 4),
      Container(
  width: 10,
  height: 10,
  decoration: BoxDecoration(
    color: isDisabled ? Colors.grey.shade400 : color,
    shape: BoxShape.circle,
  ),
),
    ],
  ),
),
                        );
                      },
                    ),
                  ),
),

if (_selectedDate != null)
  _selectedDateActionPanel(
    date: _selectedDate!,
    status: _selectedStatus,
  ),

                  /// 🔥 圖例
Container(
  width: double.infinity,
  margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey.shade200),
  ),
  child: Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      _legend(Colors.green, '空房'),
      _legend(Colors.deepOrange, '已訂'),
      _legend(Colors.blue, '入住'),
      _legend(Colors.black, '維修中'),
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

/// 🔥 選取日期操作區
Widget _selectedDateActionPanel({
  required DateTime date,
  required String status,
}) {
  final key = _format(date);
final lockedByBooking = status == 'booked' || status == 'occupied';

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '選取日期資訊',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          '$key　目前狀態：${_statusText(status)}',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const Text(
  '關閉此日後，前台該房間當日將無法被預訂。',
  style: TextStyle(
    fontSize: 12,
    color: Colors.red,
    fontWeight: FontWeight.w600,
  ),
),
        const SizedBox(height: 12),

if (lockedByBooking)
  const Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Text(
      '此日期已有訂單或正在入住，不能改成維修或恢復空房。',
      style: TextStyle(
        fontSize: 12,
        color: Colors.red,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),

Row(
          children: [
            Expanded(
  child: _smallActionButton(
  label: '關閉此日',
  color: Colors.black,
  status: 'blocked',
  dateKey: key,
  enabled: !lockedByBooking,
),
),
const SizedBox(width: 8),
Expanded(
  child: _smallActionButton(
  label: '恢復開放',
  color: Colors.green,
  status: 'available',
  dateKey: key,
  enabled: !lockedByBooking,
),
),
          ],
        ),
      ],
    ),
  );
}

/// 🔥 下方小操作按鈕
Widget _smallActionButton({
  required String label,
  required Color color,
  required String status,
  required String dateKey,
  bool enabled = true,
}) {
  return OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withOpacity(0.35)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    onPressed: enabled
    ? () async {
        await ShopService.instance.setRoomStatus(
          shopId: widget.shopId,
          roomId: widget.roomId,
          date: dateKey,
          status: status,
        );
      }
    : null,
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 🔥 狀態文字
String _statusText(String status) {
  switch (status) {
    case 'booked':
      return '已預訂';
    case 'occupied':
      return '入住中';
    case 'blocked':
      return '維修中';
    case 'available':
    default:
      return '空房';
  }
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
class _WeekdayText extends StatelessWidget {
  const _WeekdayText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}