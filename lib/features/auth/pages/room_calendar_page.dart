// lib/features/auth/pages/room_calendar_page.dart
// 🗓 房間日曆（最終完整版🔥 訂單自動上色）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/room/pages/daily_care_record_edit_page.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';

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

  DailyCareSettingModel _dailyCareSetting = const DailyCareSettingModel();

  bool _dailyCareSettingLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBookingRangeDays();
    _loadDailyCareSetting();
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
      appBar: AppBar(
        title: Text('單房紀錄 - ${widget.roomName}'),
        actions: <Widget>[
          ShopTaskCenterButton(shopId: widget.shopId),
        ],
      ),

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

            // Firestore 狀態有改變時，一律使用最新狀態。
            // 避免 cleaning → closed、closed → available 時被舊快取擋住。
            if (oldStatus != status) {
              map[dateKey] = status;
            }
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
              return ListView(
                padding: EdgeInsets.zero,
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
                  Container(
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
                    child: SizedBox(
                      height: 500,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 0.68,
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

                            case 'cleaning':
                              color = Colors.orange;
                              break;

                            case 'closed':
                              color = const Color(0xFF6D4C41);
                              break;

                            case 'blocked':
                            case 'maintenance':
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
                              margin: const EdgeInsets.all(4),
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

                  if (_selectedDate != null &&
                      _dailyCareSettingLoaded &&
                      _dailyCareSetting.enabled &&
                      _selectedBooking != null &&
                      _selectedBooking!['status'] == 'checked_in' &&
                      _isSelectedDateACareDate())
                    _dailyCarePanel(),

                  _roomActionLogsPanel(),

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
                        _legend(Colors.orange, '清潔中'),
                        _legend(const Color(0xFF6D4C41), '今日關閉'),
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

  Future<void> _loadDailyCareSetting() async {
    try {
      final DailyCareSettingModel setting = await DailyCareSettingService
          .instance
          .getSetting(widget.shopId);

      if (!mounted) return;

      setState(() {
        _dailyCareSetting = setting;
        _dailyCareSettingLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _dailyCareSettingLoaded = true;
      });

      debugPrint('讀取每日照護紀錄設定失敗：$e');
    }
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

          if (status == 'cleaning') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _showCleaningCompleteDialog(dateKey: key);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  '清潔完成',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (status == 'closed')
            Row(
              children: [
                Expanded(
                  child: _smallActionButton(
                    label: '恢復開放',
                    color: Colors.green,
                    status: 'available',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '轉為維修中',
                    color: Colors.black,
                    status: 'maintenance',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
              ],
            ),

          if (status == 'blocked' ||
              status == 'maintenance' ||
              status == 'unavailable')
            Row(
              children: [
                Expanded(
                  child: _smallActionButton(
                    label: '維修完成並開放',
                    color: Colors.green,
                    status: 'available',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '維修完成但今日關閉',
                    color: const Color(0xFF6D4C41),
                    status: 'closed',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
              ],
            ),

          if (status != 'cleaning' &&
              status != 'closed' &&
              status != 'blocked' &&
              status != 'maintenance' &&
              status != 'unavailable')
            Row(
              children: [
                Expanded(
                  child: _smallActionButton(
                    label: '關閉此日',
                    color: const Color(0xFF6D4C41),
                    status: 'closed',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '設為維修中',
                    color: Colors.black,
                    status: 'maintenance',
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

  bool _isSelectedDateACareDate() {
    final Map<String, dynamic>? booking = _selectedBooking;
    final DateTime? date = _selectedDate;
    if (booking == null || date == null) {
      return false;
    }

    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(booking);
    return stay.includesCareDate(date);
  }

  /// 🐾 每日照護紀錄
  /// 店家已啟用功能，而且房間目前正在入住時才會顯示。
  /// 退房日不產生、也不顯示填寫入口。
  Widget _dailyCarePanel() {
    final int sessionCount = _dailyCareSetting.sessionCount;

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
              const Icon(
                Icons.pets_outlined,
                size: 20,
                color: Color(0xFF3D6F9F),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '每日照護紀錄',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _openCustomerDailyCarePreview,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('客戶預覽'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3D6F9F),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            '此房今日需填寫 $sessionCount 次照護紀錄',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 14),

          ...List.generate(sessionCount, (index) {
            final String sessionName = _dailyCareSetting.sessionLabel(index);

            final String? bookingId = _selectedBookingId;
            final DateTime? selectedDate = _selectedDate;

            if (bookingId == null ||
                bookingId.isEmpty ||
                selectedDate == null) {
              return const SizedBox.shrink();
            }
            return StreamBuilder<DailyCareRecordModel?>(
              stream: DailyCareRecordService.instance.streamRecord(
                shopId: widget.shopId,
                bookingId: bookingId,
                recordDate: selectedDate,
                sessionIndex: index,
              ),
              builder: (context, recordSnapshot) {
                final DailyCareRecordModel? record = recordSnapshot.data;

                final bool completed = record != null;

                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == sessionCount - 1 ? 0 : 10,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: completed
                        ? Colors.green.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: completed
                          ? Colors.green.withValues(alpha: 0.20)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: completed
                              ? Colors.green.withValues(alpha: 0.12)
                              : const Color(0xFF3D6F9F).withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          completed
                              ? Icons.check_circle_outline
                              : _dailyCareSessionIcon(
                                  index: index,
                                  sessionCount: sessionCount,
                                ),
                          size: 20,
                          color: completed
                              ? Colors.green
                              : const Color(0xFF3D6F9F),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              completed ? '已填寫' : '尚未填寫',
                              style: TextStyle(
                                fontSize: 12,
                                color: completed ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            if (completed && record.updatedAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '最後更新 ${_dailyCareTimeText(record.updatedAt!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (completed)
                            IconButton(
                              tooltip: '客戶預覽',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _openCustomerDailyCarePreview(
                                  sessionIndex: index,
                                );
                              },
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyCareRecordEditPage(
                                    shopId: widget.shopId,
                                    bookingId: bookingId,
                                    roomId: widget.roomId,
                                    roomName: widget.roomName,
                                    recordDate: selectedDate,
                                    sessionIndex: index,
                                    sessionName: sessionName,
                                    enabledFields:
                                        _dailyCareSetting.enabledFields,
                                    customFields:
                                        _dailyCareSetting.customFields,
                                    photoEnabled:
                                        _dailyCareSetting.photoEnabled,
                                  ),
                                ),
                              );
                            },
                            child: Text(completed ? '修改' : '填寫'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openCustomerDailyCarePreview({int? sessionIndex}) async {
    final String? bookingId = _selectedBookingId;
    if (bookingId == null || bookingId.isEmpty) {
      return;
    }

    final bool allowed = await CustomerDailyCarePage.canShopPreview(
      widget.shopId,
    );
    if (!mounted) {
      return;
    }
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有預覽客戶照護日誌的權限')),
      );
      return;
    }

    final DateTime? initialDate = sessionIndex != null
        ? _selectedDate
        : _resolveCustomerPreviewDate();

    debugPrint(
      '[DailyCarePreview] open\n'
      'shopId=${widget.shopId}\n'
      'bookingId=$bookingId\n'
      'bookingCode=${(_selectedBooking?['bookingCode'] ?? '').toString()}\n'
      'roomId=${widget.roomId}\n'
      'previewMode=true\n'
      'initialDate=$initialDate\n'
      'sessionIndex=$sessionIndex\n'
      'currentUser.uid=${FirebaseAuth.instance.currentUser?.uid ?? ''}',
    );

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomerDailyCarePage(
          shopId: widget.shopId,
          bookingId: bookingId,
          roomName: widget.roomName,
          previewMode: true,
          initialDate: initialDate,
          initialSessionIndex: sessionIndex,
        ),
      ),
    );
  }

  DateTime? _resolveCustomerPreviewDate() {
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(
      _selectedBooking ?? <String, dynamic>{},
      fallbackRoomName: widget.roomName,
    );
    final DateTime today = DailyCareDateHelper.todayInTaipei();
    if (stay.includesCareDate(today)) {
      return today;
    }
    if (_selectedDate != null && stay.includesCareDate(_selectedDate!)) {
      return DailyCareDateHelper.dateOnly(_selectedDate!);
    }
    final List<String> careDateKeys = stay.careDateKeys();
    if (careDateKeys.isNotEmpty) {
      return DailyCareDateHelper.parseDateKey(careDateKeys.first);
    }
    return _selectedDate;
  }

  String _dailyCareTimeText(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  IconData _dailyCareSessionIcon({
    required int index,
    required int sessionCount,
  }) {
    if (sessionCount == 1) {
      return Icons.edit_note_outlined;
    }

    if (sessionCount == 2) {
      return index == 0 ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
    }

    switch (index) {
      case 0:
        return Icons.wb_sunny_outlined;
      case 1:
        return Icons.light_mode_outlined;
      default:
        return Icons.nightlight_outlined;
    }
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
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final logs =
                  snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type']?.toString() ?? '';

                    return type == 'room_cleaning_started' ||
                        type == 'room_cleaning_completed' ||
                        type == 'room_maintenance_started' ||
                        type == 'room_maintenance_completed' ||
                        type == 'room_maintenance_completed_closed' ||
                        type == 'room_calendar_status_update';
                  }).toList()..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aTime = aData['createdAt'] as Timestamp?;
                    final bTime = bData['createdAt'] as Timestamp?;

                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;

                    return bTime.compareTo(aTime);
                  });

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
    final String type = log['type']?.toString() ?? '';
    final String date = log['date']?.toString() ?? '-';

    final String operatorName = log['operatorName']?.toString().trim() ?? '';
    final String operatorEmail = log['operatorEmail']?.toString().trim() ?? '';

    final String operatorText = operatorName.isNotEmpty
        ? operatorName
        : operatorEmail.isNotEmpty
        ? operatorEmail
        : '未知人員';

    final String fromStatus = _statusText(log['fromStatus']?.toString() ?? '');

    final String toStatus = _statusText(log['toStatus']?.toString() ?? '');

    final bool reopened = log['reopened'] == true;
    final DateTime? createdAt = (log['createdAt'] as Timestamp?)?.toDate();

    final String timeText = createdAt != null
        ? '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}'
        : '--:--';

    IconData icon;
    Color iconColor;
    String title;
    String detail;

    switch (type) {
      case 'room_cleaning_started':
        icon = Icons.cleaning_services_outlined;
        iconColor = Colors.orange;
        title = '開始清潔';
        detail = '房間已進入清潔中';
        break;

      case 'room_cleaning_completed':
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        title = '清潔完成';
        detail = reopened ? '完成後已立即開放' : '完成後今日維持關閉';
        break;

      case 'room_maintenance_started':
        icon = Icons.build_outlined;
        iconColor = Colors.black;
        title = '開始維修';
        detail = '$fromStatus → 維修中';
        break;

      case 'room_maintenance_completed':
        icon = Icons.handyman_outlined;
        iconColor = Colors.green;
        title = '維修完成';
        detail = '維修完成並恢復開放';
        break;

      case 'room_maintenance_completed_closed':
        icon = Icons.handyman_outlined;
        iconColor = const Color(0xFF6D4C41);
        title = '維修完成';
        detail = '維修完成，但今日維持關閉';
        break;

      default:
        icon = Icons.edit_calendar_outlined;
        iconColor = Colors.blueGrey;
        title = '房間狀態調整';
        detail = '$fromStatus → $toStatus';
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  '操作者：$operatorText',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '時間：$date $timeText',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🧹 完成清潔操作
  Future<void> _showCleaningCompleteDialog({required String dateKey}) async {
    String selectedResult = 'available';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('清潔完成'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'available',
                    groupValue: selectedResult,
                    activeColor: Colors.green,
                    title: const Text(
                      '完成並立即開放',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('此日期恢復為空房，可再次接受預約'),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedResult = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    value: 'closed',
                    groupValue: selectedResult,
                    activeColor: Colors.grey,
                    title: const Text(
                      '完成但今日維持關閉',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('完成清潔，但此日期仍不開放預約'),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedResult = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('確認'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await ShopService.instance.setRoomStatus(
      shopId: widget.shopId,
      roomId: widget.roomId,
      roomName: widget.roomName,
      date: dateKey,
      status: selectedResult,

      cleaningCompleted: true,
      reopened: selectedResult == 'available',
    );

    if (!mounted) return;

    setState(() {
      _selectedStatus = selectedResult;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedResult == 'available' ? '清潔完成，房間已恢復開放' : '清潔完成，今日繼續維持關閉',
        ),
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

      case 'cleaning':
        return '清潔中';

      case 'closed':
        return '今日關閉';

      case 'blocked':
      case 'maintenance':
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
