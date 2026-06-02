// lib/features/auth/pages/room_calendar_page.dart
// 🗓 房間日曆（最終完整版🔥 訂單自動上色）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';

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
  Map<String, dynamic>? _selectedBooking;
  String? _selectedBookingId;
  final Map<String, String> _calendarStatusCache = {};

  int bookingRangeDays = 30;

  @override
  void initState() {
    super.initState();
    _loadBookingRangeDays();
  }

  Future<void> _loadBookingRangeDays() async {
    final shop = await ShopService.instance.getShop(widget.shopId);

    if (!mounted) return;

    setState(() {
      bookingRangeDays = shop?['maxAdvanceBookingDays'] ?? 30;
    });
  }

  String _format(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime get _monthStart {
    return DateTime(_currentMonth.year, _currentMonth.month, 1);
  }

  DateTime get _nextMonthStart {
    return DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
  }

  String get _monthStartKey => _format(_monthStart);

  String get _nextMonthStartKey => _format(_nextMonthStart);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lastAllowedDate = today.add(Duration(days: bookingRangeDays));

    return Scaffold(
      appBar: AppBar(title: Text('單房紀錄 - ${widget.roomName}')),

      body: StreamBuilder(
        stream: ShopService.instance
            .roomCalendarRef(widget.shopId)
            .where('roomId', isEqualTo: widget.roomId)
            .where('date', isGreaterThanOrEqualTo: _monthStartKey)
            .where('date', isLessThan: _nextMonthStartKey)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          final map = Map<String, String>.from(_calendarStatusCache);

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            final dateKey = data['date']?.toString() ?? '';
            final status = data['status']?.toString() ?? 'available';

            if (dateKey.isEmpty) continue;

            final oldStatus = map[dateKey];

            // 維修中優先，但如果新狀態是恢復開放 available，要允許覆蓋
            if (_isBlockedStatus(oldStatus ?? '') && status != 'available') {
              continue;
            }

            map[dateKey] = status;
          }

          _calendarStatusCache
            ..clear()
            ..addAll(map);

          /// 🔥 訂單監聽
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('shopId', isEqualTo: widget.shopId)
                .where('roomId', isEqualTo: widget.roomId)
                .where(
                  'status',
                  whereIn: ['pending', 'confirmed', 'checked_in', 'completed'],
                )
                .snapshots(),
            builder: (context, bookingSnap) {
              final allBookingDocs = bookingSnap.data?.docs ?? [];

              final bookings = allBookingDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final start = (data['startDate'] as Timestamp).toDate();
                final end = (data['endDate'] as Timestamp).toDate();

                return start.isBefore(_nextMonthStart) &&
                    end.isAfter(_monthStart);
              }).toList();

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
                                '單房使用紀錄 / 可關閉單日房間',
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
                          Map<String, dynamic>? dayBooking;
                          String? dayBookingId;

                          /// 🔥 訂單覆蓋（紅色）
                          /// 維修中 / 關閉日優先，不讓訂單狀態蓋掉黑點
                          if (!_isBlockedStatus(status)) {
                            for (var doc in bookings) {
                              final data = doc.data() as Map<String, dynamic>;

                              final start = (data['startDate'] as Timestamp)
                                  .toDate();
                              final end = (data['endDate'] as Timestamp)
                                  .toDate();

                              final dateObj = DateTime.parse(key);

                              if (dateObj.isAfter(
                                    start.subtract(const Duration(days: 1)),
                                  ) &&
                                  dateObj.isBefore(end)) {
                                if (data['status'] == 'checked_in') {
                                  status = 'occupied';
                                } else if (data['status'] == 'completed') {
                                  status = 'completed';
                                } else {
                                  status = 'booked';
                                }

                                dayBooking = data;
                                dayBookingId = doc.id;

                                break;
                              }
                            }
                          }

                          /// 🔥 可操作範圍
                          final isPastDate = date.isBefore(
                            today.subtract(const Duration(days: 1)),
                          );

                          final isFutureOutOfRange = date.isAfter(
                            lastAllowedDate,
                          );

                          final hasBooking = dayBooking != null;
                          final isBlocked = _isBlockedStatus(status);

                          /// 過去日期如果有訂單或維修紀錄，要能顯示出來
                          final isDisabled =
                              isFutureOutOfRange ||
                              (isPastDate && !hasBooking && !isBlocked);

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

                            case 'completed':
                              color = Colors.purple;
                              break;

                            case 'blocked':
                            case 'maintenance':
                            case 'closed':
                            case 'cleaning':
                            case 'unavailable':
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
                                      _selectedBooking = dayBooking;
                                      _selectedBookingId = dayBookingId;
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
                                    : _isBlockedStatus(status)
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
                                      color: isDisabled
                                          ? Colors.grey.shade400
                                          : color,
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
                      status: _selectedBooking != null
                          ? (_selectedBooking!['status'] ?? _selectedStatus)
                          : _selectedStatus,
                    ),

                  SizedBox(height: 260, child: _roomActionLogsPanel()),

                  /// 🔥 圖例
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                        _legend(Colors.purple, '退房/完成'),
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
    final lockedByBooking =
        status == 'booked' ||
        status == 'occupied' ||
        status == 'pending' ||
        status == 'confirmed' ||
        status == 'checked_in' ||
        status == 'completed';

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '選取日期資訊',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate = null;
                    _selectedBooking = null;
                    _selectedBookingId = null;
                    _selectedStatus = 'available';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            '$key　目前狀態：${_selectedBooking != null ? _statusText(_selectedBooking!['status']) : _statusText(status)}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Text(
            '關閉此日後，前台該房間當日將無法被預訂。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (_selectedBooking != null) ...[
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '訂單摘要',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    '客人：${_selectedBooking!['customerName'] ?? '未知'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 4),

                  Text('狀態：${_statusText(_selectedBooking!['status'])}'),

                  const SizedBox(height: 4),

                  Text(
                    '日期：'
                    '${_format((_selectedBooking!['startDate'] as Timestamp).toDate())}'
                    ' ～ '
                    '${_format((_selectedBooking!['endDate'] as Timestamp).toDate())}',
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminBookingDetailPage(
                              bookingId: _selectedBookingId!,
                              canEdit: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('查看訂單'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  /// 🔥 房務操作紀錄
  Widget _roomActionLogsPanel() {
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
            '房務操作紀錄',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('action_logs')
                .where('shopId', isEqualTo: widget.shopId)
                .where('roomId', isEqualTo: widget.roomId)
                .where('type', isEqualTo: 'room_calendar_status_update')
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final logs = snapshot.data!.docs;

              if (logs.isEmpty) {
                return const Text(
                  '目前沒有房務操作紀錄',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                );
              }

              return SizedBox(
                height: 120,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: logs.map((doc) {
                    final log = doc.data() as Map<String, dynamic>;

                    return _roomActionLogItem(log);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roomActionLogItem(Map<String, dynamic> log) {
    final date = log['date'] ?? '-';
    final operatorEmail = log['operatorEmail'] ?? '-';
    final fromStatus = _statusText(log['fromStatus'] ?? '');
    final toStatus = _statusText(log['toStatus'] ?? '');
    final createdAt = (log['createdAt'] as Timestamp?)?.toDate();

    final timeText = createdAt != null
        ? '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$date $timeText：$fromStatus → $toStatus',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '操作者：$operatorEmail',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: enabled
          ? () async {
              await ShopService.instance.setRoomStatus(
                shopId: widget.shopId,
                roomId: widget.roomId,
                roomName: widget.roomName,
                date: dateKey,
                status: status,
              );

              if (!mounted) return;

              setState(() {
                _selectedStatus = status;
              });
            }
          : null,
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  bool _isBlockedStatus(String status) {
    return status == 'blocked' ||
        status == 'maintenance' ||
        status == 'closed' ||
        status == 'cleaning' ||
        status == 'unavailable';
  }

  /// 🔥 狀態文字
  String _statusText(String status) {
    switch (status) {
      /// 日曆狀態
      case 'booked':
        return '已訂';

      case 'occupied':
        return '入住中';

      /// 訂單狀態
      case 'pending':
        return '預訂中';

      case 'confirmed':
        return '已確認';

      case 'checked_in':
        return '入住中';

      case 'completed':
        return '退房/完成';

      case 'blocked':
      case 'maintenance':
      case 'closed':
      case 'cleaning':
      case 'unavailable':
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
