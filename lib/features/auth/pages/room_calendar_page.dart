// 檔案名稱：lib/features/auth/pages/room_calendar_page.dart
// 功能說明：房間日曆（最終完整版 訂單自動上色）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/services/daily_care_report_eligibility.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/room/daily_care_record_edit_launcher.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';

class RoomCalendarPage extends StatefulWidget {
  const RoomCalendarPage({
    super.key,
    required this.shopId,
    required this.roomId,
    required this.roomName,
    required this.roomTypeName,
    required this.roomImageUrl,
    this.embedded = false,
    this.embeddedHeader,
    this.room = const <String, dynamic>{},
  });

  final String shopId;
  final String roomId;
  final String roomName;
  final String roomTypeName;
  final String roomImageUrl;

  /// 為 true 時只回傳單房紀錄內容，不建立 Scaffold／AppBar。
  /// 既有單獨開啟的頁面維持完整頁面。
  final bool embedded;

  /// 桌機房務總覽右欄月曆區頂端的房間識別。手機完整頁不使用。
  final Widget? embeddedHeader;

  /// 桌機房務總覽帶入的房間文件，讓左右兩側的日期狀態判定完全一致。
  /// 手機完整頁不帶入，維持原本判定。
  final Map<String, dynamic> room;

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

  String? _busyActionKey;

  DailyCareSettingModel _dailyCareSetting = const DailyCareSettingModel();

  bool _dailyCareSettingLoaded = false;
  int _queryEpoch = 0;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _calendarQueryStream;
  String _calendarQueryKey = '';
  Stream<QuerySnapshot<Map<String, dynamic>>>? _bookingQueryStream;
  String _bookingQueryKey = '';

  @override
  void initState() {
    super.initState();
    _loadBookingRangeDays();
    _loadDailyCareSetting();
  }

  @override
  void didUpdateWidget(covariant RoomCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.shopId != widget.shopId) {
      _selectedDate = null;
      _selectedBooking = null;
      _selectedBookingId = null;
      _selectedStatus = 'available';
      _calendarStatusCache.clear();
      _currentMonth = DateTime.now();
      _loadBookingRangeDays();
      if (oldWidget.shopId != widget.shopId) {
        _dailyCareSettingLoaded = false;
        _loadDailyCareSetting();
      }
    }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _calendarSnapshots() {
    final String key =
        '${widget.shopId}|${widget.roomId}|$_monthStartKey|$_nextMonthStartKey|$_queryEpoch';
    final Stream<QuerySnapshot<Map<String, dynamic>>>? current =
        _calendarQueryStream;
    if (current != null && _calendarQueryKey == key) {
      return current;
    }
    _calendarQueryKey = key;
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream = ShopService
        .instance
        .roomCalendarRef(widget.shopId)
        .where('roomId', isEqualTo: widget.roomId)
        .where('date', isGreaterThanOrEqualTo: _monthStartKey)
        .where('date', isLessThan: _nextMonthStartKey)
        .snapshots();
    _calendarQueryStream = stream;
    return stream;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingSnapshots() {
    final String key = '${widget.shopId}|${widget.roomId}';
    final Stream<QuerySnapshot<Map<String, dynamic>>>? current =
        _bookingQueryStream;
    if (current != null && _bookingQueryKey == key) {
      return current;
    }
    _bookingQueryKey = key;
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream = FirebaseFirestore
        .instance
        .collection('bookings')
        .where('shopId', isEqualTo: widget.shopId)
        .where('roomId', isEqualTo: widget.roomId)
        .where(
          'status',
          whereIn: <String>['pending', 'confirmed', 'checked_in', 'completed'],
        )
        .snapshots();
    _bookingQueryStream = stream;
    return stream;
  }

  bool _isMissingIndexError(Object error) {
    String code = '';
    String message = '';
    if (error is FirebaseException) {
      code = error.code.toLowerCase();
      message = (error.message ?? '').toLowerCase();
    }
    final String text = error.toString().toLowerCase();
    final String haystack = '$code $message $text';
    return haystack.contains('requires an index') ||
        haystack.contains('index is currently building') ||
        haystack.contains('indexes are currently building') ||
        ((haystack.contains('failed-precondition') ||
                haystack.contains('failed_precondition')) &&
            haystack.contains('index'));
  }

  Widget _calendarErrorCard(Object error) {
    final bool indexError = _isMissingIndexError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    indexError ? '房間日曆索引建立中' : '房間日曆暫時無法載入',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    indexError ? '首次建立索引約需幾分鐘，完成後請重新整理。' : '請檢查網路後再試。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _queryEpoch++),
                    child: const Text('重新載入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lastAllowedDate = today.add(Duration(days: bookingRangeDays));

    final Widget body = StreamBuilder(
      key: ValueKey<int>(_queryEpoch),
      stream: _calendarSnapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('房間日曆載入失敗：${snapshot.error}');
          return _calendarErrorCard(snapshot.error!);
        }
        final docs = snapshot.data?.docs ?? [];

        final Map<String, String> map = <String, String>{};

        for (var doc in docs) {
          final data = doc.data();

          final dateKey = data['date']?.toString() ?? '';
          final status = data['status']?.toString() ?? 'available';

          if (dateKey.isEmpty) continue;

          map[dateKey] = status;
        }

        _calendarStatusCache
          ..clear()
          ..addAll(map);

        /// 🔥 訂單監聽
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _bookingSnapshots(),
          builder: (context, bookingSnap) {
            final allBookingDocs = bookingSnap.data?.docs ?? [];

            final bookings = allBookingDocs.where((doc) {
              final data = doc.data();

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
            final List<Widget> topChrome = <Widget>[
              if (!widget.embedded)
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
                          color: Colors.orange.withValues(alpha: 0.12),
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
            ];
            Widget buildMonthCard() {
              return Container(
                margin: EdgeInsets.fromLTRB(
                  widget.embedded ? 4 : 12,
                  0,
                  widget.embedded ? 4 : 12,
                  widget.embedded ? 0 : 12,
                ),
                padding: EdgeInsets.only(top: widget.embedded ? 0 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool embeddedGrid = widget.embedded;
                    final int rowCount = (totalGridCount / 7).ceil().clamp(
                      1,
                      6,
                    );
                    final double availableHeight = constraints.maxHeight;
                    final double embeddedCellHeight = availableHeight.isFinite
                        ? ((availableHeight - (rowCount - 1) * 2) / rowCount)
                              .clamp(1.0, 60.0)
                        : 56.0;
                    final Widget grid = GridView.builder(
                      shrinkWrap: false,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        embeddedGrid ? 4 : 14,
                        embeddedGrid ? 0 : 10,
                        embeddedGrid ? 4 : 14,
                        embeddedGrid ? 0 : 18,
                      ),
                      gridDelegate: embeddedGrid
                          ? SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisExtent: embeddedCellHeight,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            )
                          : const SliverGridDelegateWithFixedCrossAxisCount(
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
                        final String calendarStatus = map[key] ?? '';
                        String status = map[key] ?? 'available';
                        Map<String, dynamic>? dayBooking;
                        String? dayBookingId;

                        /// 🔥 訂單覆蓋（紅色）
                        /// 維修中 / 關閉日優先，不讓訂單狀態蓋掉黑點
                        if (!_isBlockedStatus(status)) {
                          if (widget.embedded) {
                            /// 桌機房務總覽：與左側 7 天點用同一套訂單挑選規則
                            QueryDocumentSnapshot<Map<String, dynamic>>? best;
                            int bestPriority = -1;
                            for (final doc in bookings) {
                              final data = doc.data();
                              if (!isActiveRoomDayBooking(data) ||
                                  !roomDayBookingCovers(
                                    booking: data,
                                    date: date,
                                  )) {
                                continue;
                              }
                              final int priority = roomDayBookingPriority(data);
                              if (priority > bestPriority) {
                                bestPriority = priority;
                                best = doc;
                              }
                            }
                            if (best != null) {
                              dayBooking = best.data();
                              dayBookingId = best.id;
                              status = _calendarStatusOfBooking(dayBooking);
                            }
                          } else {
                            for (var doc in bookings) {
                              final data = doc.data();

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

                        final RoomDayStatus dayStatus = resolveRoomDayStatus(
                          date: date,
                          today: today,
                          room: widget.room,
                          calendarStatus: calendarStatus,
                          booking: dayBooking,
                        );

                        /// 桌機房務總覽：過去日期一律灰色，但仍可點開查紀錄。
                        final bool historyDay =
                            widget.embedded && dayStatus.isHistory;

                        /// 過去日期如果有訂單或維修紀錄，要能顯示出來
                        final isDisabled = widget.embedded
                            ? isFutureOutOfRange
                            : isFutureOutOfRange ||
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
                            color = RoomStatusPresentation.calendarDot(
                              (dayBooking?['bookingKind'] ?? '') == 'daycare'
                                  ? 'booked_daycare'
                                  : 'booked',
                            ).color;
                            break;
                          case 'occupied':
                            color = RoomStatusPresentation.calendarDot(
                              (dayBooking?['bookingKind'] ?? '') == 'daycare'
                                  ? 'occupied_daycare'
                                  : 'occupied',
                            ).color;
                            break;
                          case 'completed':
                            color = RoomStatusPresentation.calendarDot(
                              'completed',
                            ).color;
                            break;
                          case 'cleaning':
                            color = RoomStatusPresentation.calendarDot(
                              'cleaning',
                            ).color;
                            break;
                          case 'closed':
                            color = RoomStatusPresentation.calendarDot(
                              'closed',
                            ).color;
                            break;

                          case 'blocked':
                          case 'maintenance':
                          case 'unavailable':
                            color = RoomStatusPresentation.calendarDot(
                              'maintenance',
                            ).color;
                            break;
                          default:
                            color = RoomStatusPresentation.calendarDot(
                              'available',
                            ).color;
                        }

                        if (widget.embedded) {
                          /// 與左側 7 天點共用同一支 helper 的顏色
                          color = dayStatus.color;
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
                            margin: EdgeInsets.all(widget.embedded ? 1 : 4),
                            padding: EdgeInsets.symmetric(
                              vertical: widget.embedded ? 1 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDisabled
                                  ? Colors.grey.shade100
                                  : historyDay
                                  ? Colors.grey.shade50
                                  : status == 'booked'
                                  ? Colors.deepOrange.withValues(alpha: 0.05)
                                  : status == 'occupied'
                                  ? Colors.blue.withValues(alpha: 0.06)
                                  : _isBlockedStatus(status)
                                  ? Colors.black.withValues(alpha: 0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : isDisabled
                                    ? Colors.grey.shade300
                                    : color.withValues(alpha: 0.35),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isDisabled || widget.embedded
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
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
                                        : historyDay
                                        ? Colors.grey.shade600
                                        : const Color(0xFF333333),
                                    fontWeight: FontWeight.w800,
                                    fontSize: widget.embedded ? 13 : 16,
                                  ),
                                ),

                                SizedBox(height: widget.embedded ? 2 : 4),

                                Container(
                                  width: widget.embedded ? 8 : 10,
                                  height: widget.embedded ? 8 : 10,
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
                    );
                    if (!embeddedGrid) {
                      return SizedBox(height: 500, child: grid);
                    }
                    return grid;
                  },
                ),
              );
            }

            if (widget.embedded) {
              return _embeddedWorkspace(monthCard: buildMonthCard());
            }
            return ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                ...topChrome,
                buildMonthCard(),
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
                    _isSelectedDateACareDate() &&
                    DailyCareReportEligibility.isEntitled(
                      DailyCareReportEligibility.resolvedEntitlement(
                        booking: _selectedBooking!,
                        setting: _dailyCareSetting,
                        daycare: false,
                      ),
                    ))
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
                    children: RoomStatusPresentation.legendItems()
                        .map(
                          (RoomStatusPresentation item) =>
                              _legend(item.color, item.label),
                        )
                        .toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('單房紀錄 - ${widget.roomName}'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
      ),
      body: body,
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

  Widget _embeddedWorkspace({required Widget monthCard}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxH = constraints.maxHeight;
        double zone = 400;
        if (maxH.isFinite && maxH > 0) {
          zone = (maxH * 0.52).clamp(360.0, 430.0);
          if (maxH - zone < 150) {
            zone = (maxH - 150).clamp(240.0, 430.0);
          }
        }
        return Column(
          children: <Widget>[
            SizedBox(
              height: zone,
              child: Column(
                children: <Widget>[
                  if (widget.embeddedHeader != null) widget.embeddedHeader!,
                  _embeddedMonthSwitcher(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: <Widget>[
                        _WeekdayText('日', fontSize: 11),
                        _WeekdayText('一', fontSize: 11),
                        _WeekdayText('二', fontSize: 11),
                        _WeekdayText('三', fontSize: 11),
                        _WeekdayText('四', fontSize: 11),
                        _WeekdayText('五', fontSize: 11),
                        _WeekdayText('六', fontSize: 11),
                      ],
                    ),
                  ),
                  Expanded(child: monthCard),
                  _embeddedLegend(),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            Expanded(child: _embeddedDetailScroll()),
          ],
        );
      },
    );
  }

  Widget _embeddedMonthSwitcher() {
    return SizedBox(
      height: 32,
      child: Row(
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            },
          ),
          Expanded(
            child: Text(
              '${_currentMonth.year} 年 ${_currentMonth.month} 月',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.chevron_right, size: 20),
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
    );
  }

  Widget _embeddedLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: <Widget>[
          ...RoomStatusPresentation.legendItems().map(
            (RoomStatusPresentation item) =>
                _embeddedLegendItem(item.color, item.label),
          ),
          _embeddedLegendItem(roomDayHistoryColor, roomDayHistoryLabel),
        ],
      ),
    );
  }

  Widget _embeddedLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _embeddedDetailScroll() {
    final DateTime? date = _selectedDate;
    final String title = date == null
        ? '日期詳細資訊'
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} 日期詳細資訊';
    final bool showCare =
        date != null &&
        _dailyCareSettingLoaded &&
        _dailyCareSetting.enabled &&
        _selectedBooking != null &&
        _selectedBooking!['status'] == 'checked_in' &&
        _isSelectedDateACareDate() &&
        DailyCareReportEligibility.isEntitled(
          DailyCareReportEligibility.resolvedEntitlement(
            booking: _selectedBooking!,
            setting: _dailyCareSetting,
            daycare: false,
          ),
        );
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (date == null)
          const Text(
            '請點選上方月曆日期',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          )
        else ...<Widget>[
          _embeddedStatusCard(date),
          const SizedBox(height: 8),
          _embeddedBookingCard(),
          if (showCare) ...<Widget>[
            const SizedBox(height: 8),
            _dailyCarePanel(dense: true),
          ],
          const SizedBox(height: 8),
          _roomActionLogsPanel(dense: true, onlyDate: _format(date)),
        ],
      ],
    );
  }

  Widget _embeddedStatusCard(DateTime date) {
    final String key = _format(date);
    final String status = _selectedBooking != null
        ? (_selectedBooking!['status'] ?? _selectedStatus).toString()
        : _selectedStatus;
    final bool lockedByBooking =
        status == 'booked' ||
        status == 'occupied' ||
        status == 'pending' ||
        status == 'confirmed' ||
        status == 'checked_in' ||
        status == 'completed';

    /// 過去日期只能查，不能再變更房間狀態。
    final bool pastDate = roomDayOnly(
      date,
    ).isBefore(roomDayOnly(DateTime.now()));
    if (pastDate) {
      return _embeddedInfoCard(
        title: '日期狀態',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '當日狀態：${_statusText(status)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '歷史日期僅供查詢，不可再變更房間狀態。',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }
    return _embeddedInfoCard(
      title: '日期狀態',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '目前狀態：${_statusText(status)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            '關閉此日後，前台當日無法預訂。',
            style: TextStyle(fontSize: 12, color: Colors.red, height: 1.3),
          ),
          if (lockedByBooking) ...<Widget>[
            const SizedBox(height: 4),
            const Text(
              '此日已有訂單，不能改成維修或恢復空房。',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (status == 'cleaning')
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: RoomStatusPresentation.cleaningColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: _busyActionKey == 'clean:$key'
                    ? null
                    : () {
                        _showCleaningCompleteDialog(dateKey: key);
                      },
                icon: _busyActionKey == 'clean:$key'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('清潔完成'),
              ),
            )
          else if (status == 'closed')
            Row(
              children: <Widget>[
                Expanded(
                  child: _smallActionButton(
                    label: '恢復開放',
                    color: RoomStatusPresentation.availableColor,
                    status: 'available',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '轉為維修中',
                    color: RoomStatusPresentation.maintenanceColor,
                    status: 'maintenance',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
              ],
            )
          else if (status == 'blocked' ||
              status == 'maintenance' ||
              status == 'unavailable')
            Row(
              children: <Widget>[
                Expanded(
                  child: _smallActionButton(
                    label: '維修完成並開放',
                    color: RoomStatusPresentation.availableColor,
                    status: 'available',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '維修完成但今日關閉',
                    color: RoomStatusPresentation.closedColor,
                    status: 'closed',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: _smallActionButton(
                    label: '關閉此日',
                    color: RoomStatusPresentation.closedColor,
                    status: 'closed',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '設為維修中',
                    color: RoomStatusPresentation.maintenanceColor,
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

  Widget _embeddedBookingCard() {
    final Map<String, dynamic>? booking = _selectedBooking;
    if (booking == null) {
      return _embeddedInfoCard(
        title: '訂單摘要',
        child: const Text(
          '此日期無入住訂單',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }
    final String pets = _bookingPetNames(booking);
    final DateTime? start = (booking['startDate'] as Timestamp?)?.toDate();
    final DateTime? end = (booking['endDate'] as Timestamp?)?.toDate();
    final String range = start != null && end != null
        ? '${_format(start)} ～ ${_format(end)}'
        : '';
    return _embeddedInfoCard(
      title: '訂單摘要',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '客人：${booking['customerName'] ?? '未知'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '寵物：${pets.isEmpty ? '未填' : pets}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            '訂單狀態：${_statusText((booking['status'] ?? '').toString())}',
            style: const TextStyle(fontSize: 13),
          ),
          if (range.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text('入住／退房：$range', style: const TextStyle(fontSize: 13)),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _selectedBookingId == null
                  ? null
                  : () {
                      AdminBookingRoute.open(
                        context,
                        bookingId: _selectedBookingId!,
                        data: booking,
                        canEdit: true,
                      );
                    },
              child: const Text('查看訂單'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _embeddedInfoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  String _bookingPetNames(Map<String, dynamic> booking) {
    final Object? names = booking['petNames'] ?? booking['petName'];
    if (names is List) {
      return names
          .map((Object? value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .join('、');
    }
    if (names is String && names.trim().isNotEmpty) {
      return names.trim();
    }
    final Object? pets = booking['pets'];
    if (pets is List) {
      return pets
          .map((Object? value) {
            if (value is Map) {
              return (value['name'] ?? '').toString().trim();
            }
            return value.toString().trim();
          })
          .where((String value) => value.isNotEmpty)
          .join('、');
    }
    return '';
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
                        AdminBookingRoute.open(
                          context,
                          bookingId: _selectedBookingId!,
                          data: _selectedBooking,
                          canEdit: true,
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
                  backgroundColor: RoomStatusPresentation.cleaningColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _busyActionKey == 'clean:$key'
                    ? null
                    : () {
                        _showCleaningCompleteDialog(dateKey: key);
                      },
                icon: _busyActionKey == 'clean:$key'
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
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
                    color: RoomStatusPresentation.availableColor,
                    status: 'available',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '轉為維修中',
                    color: RoomStatusPresentation.maintenanceColor,
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
                    color: RoomStatusPresentation.availableColor,
                    status: 'available',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '維修完成但今日關閉',
                    color: RoomStatusPresentation.closedColor,
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
                    color: RoomStatusPresentation.closedColor,
                    status: 'closed',
                    dateKey: key,
                    enabled: !lockedByBooking,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: '設為維修中',
                    color: RoomStatusPresentation.maintenanceColor,
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
  Widget _dailyCarePanel({bool dense = false}) {
    final Map<String, dynamic> booking =
        _selectedBooking ?? const <String, dynamic>{};
    final DailyCareEntitlement entitlement =
        DailyCareReportEligibility.resolvedEntitlement(
          booking: booking,
          setting: _dailyCareSetting,
          daycare: false,
        );
    final int sessionCount = entitlement.finalReports >= 1
        ? entitlement.finalReports
        : _dailyCareSetting.sessionCount;

    return Container(
      width: double.infinity,
      margin: dense ? EdgeInsets.zero : const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: EdgeInsets.all(dense ? 10 : 14),
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
            final String sessionName = DailyCareReportEligibility.sessionName(
              entitlement: entitlement,
              setting: _dailyCareSetting,
              sessionIndex: index,
            );

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
                    bottom: index == sessionCount - 1 ? 0 : (dense ? 6 : 10),
                  ),
                  padding: EdgeInsets.all(dense ? 8 : 12),
                  decoration: BoxDecoration(
                    color: completed
                        ? RoomStatusPresentation.availableColor.withValues(
                            alpha: 0.04,
                          )
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: completed
                          ? RoomStatusPresentation.availableColor.withValues(
                              alpha: 0.20,
                            )
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: dense ? 28 : 38,
                        height: dense ? 28 : 38,
                        decoration: BoxDecoration(
                          color: completed
                              ? RoomStatusPresentation.availableColor
                                    .withValues(alpha: 0.12)
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
                              ? RoomStatusPresentation.availableColor
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
                                color: completed
                                    ? RoomStatusPresentation.availableColor
                                    : RoomStatusPresentation.cleaningColor,
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
                              await DailyCareRecordEditLauncher.open(
                                context: context,
                                shopId: widget.shopId,
                                bookingId: bookingId,
                                recordDate: selectedDate,
                                sessionIndex: index,
                                roomId: widget.roomId,
                                roomName: widget.roomName,
                                setting: _dailyCareSetting,
                                entitlement: entitlement,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('沒有預覽客戶照護日誌的權限')));
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
  Widget _roomActionLogsPanel({bool dense = false, String? onlyDate}) {
    return Container(
      width: double.infinity,
      margin: dense ? EdgeInsets.zero : const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: EdgeInsets.all(dense ? 10 : 14),
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

              final List<QueryDocumentSnapshot<Object?>> visible =
                  onlyDate == null
                  ? logs
                  : logs.where((QueryDocumentSnapshot<Object?> doc) {
                      final Object? raw = doc.data();
                      if (raw is! Map) {
                        return false;
                      }
                      return (raw['date'] ?? '').toString() == onlyDate;
                    }).toList();

              if (visible.isEmpty) {
                return Text(
                  onlyDate == null ? '目前沒有房務操作紀錄' : '此日期沒有房務操作紀錄',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                );
              }

              if (dense) {
                return Column(
                  children: visible.map((QueryDocumentSnapshot<Object?> doc) {
                    final Object? raw = doc.data();
                    final Map<String, dynamic> log = raw is Map
                        ? Map<String, dynamic>.from(raw)
                        : <String, dynamic>{};
                    return _roomActionLogItem(log, dense: true);
                  }).toList(),
                );
              }

              return SizedBox(
                height: 120,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: visible.map((QueryDocumentSnapshot<Object?> doc) {
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

  Widget _roomActionLogItem(Map<String, dynamic> log, {bool dense = false}) {
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
        iconColor = RoomStatusPresentation.cleaningColor;
        title = '開始清潔';
        detail = '房間已進入清潔中';
        break;

      case 'room_cleaning_completed':
        icon = Icons.check_circle_outline;
        iconColor = RoomStatusPresentation.availableColor;
        title = '清潔完成';
        detail = reopened ? '完成後已立即開放' : '完成後今日維持關閉';
        break;

      case 'room_maintenance_started':
        icon = Icons.build_outlined;
        iconColor = RoomStatusPresentation.maintenanceColor;
        title = '開始維修';
        detail = '$fromStatus → 維修中';
        break;

      case 'room_maintenance_completed':
        icon = Icons.handyman_outlined;
        iconColor = RoomStatusPresentation.availableColor;
        title = '維修完成';
        detail = '維修完成並恢復開放';
        break;

      case 'room_maintenance_completed_closed':
        icon = Icons.handyman_outlined;
        iconColor = RoomStatusPresentation.closedColor;
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

    if (dense) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$date $timeText  $title  $detail  操作者：$operatorText',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, height: 1.3),
        ),
      );
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
                  Icon(
                    Icons.cleaning_services_outlined,
                    color: RoomStatusPresentation.cleaningColor,
                  ),
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
                    activeColor: RoomStatusPresentation.availableColor,
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

    final String actionKey = 'clean:$dateKey';
    setState(() {
      _busyActionKey = actionKey;
    });
    try {
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('操作失敗：$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyActionKey = null;
        });
      }
    }
  }

  /// 🔥 下方小操作按鈕
  Widget _smallActionButton({
    required String label,
    required Color color,
    required String status,
    required String dateKey,
    bool enabled = true,
  }) {
    final String actionKey = '$status:$dateKey';
    final bool busy = _busyActionKey == actionKey;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: enabled && !busy && _busyActionKey == null
          ? () => _runCalendarAction(
              actionKey: actionKey,
              dateKey: dateKey,
              status: status,
              successMessage: _statusActionMessage(status),
            )
          : null,
      child: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
    );
  }

  String _statusActionMessage(String status) {
    switch (status) {
      case 'available':
        return '已恢復開放';
      case 'closed':
        return '已關閉此日';
      case 'maintenance':
      case 'blocked':
      case 'unavailable':
        return '已設為維修中';
      default:
        return '房間狀態已更新';
    }
  }

  Future<void> _runCalendarAction({
    required String actionKey,
    required String dateKey,
    required String status,
    required String successMessage,
  }) async {
    if (_busyActionKey != null) {
      return;
    }
    setState(() {
      _busyActionKey = actionKey;
    });
    try {
      await ShopService.instance.setRoomStatus(
        shopId: widget.shopId,
        roomId: widget.roomId,
        roomName: widget.roomName,
        date: dateKey,
        status: status,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedStatus = status;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('操作失敗：$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyActionKey = null;
        });
      }
    }
  }

  /// 有效訂單對應的日曆顯示狀態。
  String _calendarStatusOfBooking(Map<String, dynamic> booking) {
    switch ((booking['status'] ?? '').toString()) {
      case 'checked_in':
        return 'occupied';
      case 'completed':
        return 'completed';
      default:
        return 'booked';
    }
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
  const _WeekdayText(this.text, {this.fontSize = 12});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
