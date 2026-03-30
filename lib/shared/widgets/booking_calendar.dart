// 檔案名稱 lib/shared/widgets/booking_calendar.dart
//
// 共用預約月曆元件
//
// 用途：
// - 前台 / 後台共用同一套月曆視覺
// - 可顯示：
//   1. 不可預約日期
//   2. 關閉日期
//   6. 區間選取
//
// 備註：
// - 目前先做單月切換版
// - 不依賴外部套件
// - 下一步會接到後台預約管理頁
// - 再下一步會接到前台預約頁

import 'package:flutter/material.dart';

class BookingCalendar extends StatefulWidget {
  final bool allowBlockedTap;
  const BookingCalendar({
    this.allowBlockedTap = false,
    super.key,
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onDayTap,
    this.rangeStart,
    this.rangeEnd,
    this.blockedDateKeys = const {},
    this.unbookableDateKeys = const {},
    this.blockedDateReasons = const {},
    this.remainingRoomsMap = const {},
    this.onMonthChanged,
  });

  final DateTime initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;

  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  final Set<String> blockedDateKeys;
  final Set<String> unbookableDateKeys;

  final Map<String, String> blockedDateReasons;
  final Map<String, int> remainingRoomsMap;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime>? onMonthChanged;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {

  @override
void didUpdateWidget(covariant BookingCalendar oldWidget) {
  super.didUpdateWidget(oldWidget);

  // 🔥 當 range 改變時強制刷新
  if (oldWidget.rangeStart != widget.rangeStart ||
      oldWidget.rangeEnd != widget.rangeEnd) {
    setState(() {});
  }
}
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lastDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);

    final int leadingEmpty = firstDayOfMonth.weekday % 7;
    final int totalDays = lastDayOfMonth.day;

    final List<Widget> dayCells = [];

    for (int i = 0; i < leadingEmpty; i++) {
      dayCells.add(const SizedBox());
    }

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      dayCells.add(_buildDayCell(context, date));
    }

    return Card(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), 
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 4),
            _buildWeekHeader(),
            const SizedBox(height: 8),
            GridView.count(
  crossAxisCount: 7,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
  childAspectRatio: 0.55, 
  children: dayCells,
),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canGoPrev = !_isSameMonthOrBefore(_visibleMonth, widget.firstDate);
    final canGoNext = !_isSameMonthOrAfter(_visibleMonth, widget.lastDate);

    return Row(
      children: [
        IconButton(
          onPressed: canGoPrev ? _goPrevMonth : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_visibleMonth.year} / ${_visibleMonth.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: canGoNext ? _goNextMonth : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return Row(
      children: labels.map((label) {
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

 Widget _buildDayCell(BuildContext context, DateTime date) {

  final bool isOutOfRange =
      date.isBefore(_dateOnly(widget.firstDate)) ||
      date.isAfter(_dateOnly(widget.lastDate));

  final dateKey = _formatDateKey(date);
  final remaining = widget.remainingRoomsMap[dateKey];

final bool isBlocked = widget.blockedDateKeys.contains(dateKey);
final bool isUnbookable = widget.unbookableDateKeys.contains(dateKey);

final String? reason = widget.blockedDateReasons[dateKey];
final bool isRangeStart =
    widget.rangeStart != null &&
    _isSameDate(widget.rangeStart!, date);

final bool isRangeEnd =
    widget.rangeEnd != null &&
    _isSameDate(widget.rangeEnd!, date);

final bool isInRange =
    widget.rangeStart != null &&
    widget.rangeEnd != null &&
    !date.isBefore(_dateOnly(widget.rangeStart!)) &&
    !date.isAfter(_dateOnly(widget.rangeEnd!));

  Color borderColor = Colors.grey.shade300;
  Color backgroundColor = Colors.white;
  Color dayTextColor = Colors.black87;

  if (isOutOfRange) {
    backgroundColor = Colors.grey.shade100;
    dayTextColor = Colors.grey.shade400;
  } else if (isBlocked || isUnbookable) {
    backgroundColor = Colors.red.shade50;
    borderColor = Colors.red.shade200;
    dayTextColor = Colors.red.shade700;
  } if (isRangeStart || isRangeEnd) {
  backgroundColor = Colors.blue;
  borderColor = Colors.blue.shade900;
  dayTextColor = Colors.white;
} else if (isInRange) {
  backgroundColor = Colors.blue.shade100;
  borderColor = Colors.blue.shade300;
  dayTextColor = Colors.black;
}

  final bool canTap = !isOutOfRange;

  return InkWell(
  onTap: () {

  /// 🔥 超出範圍
  if (isOutOfRange) return;

  /// 🔥 房滿（前後台都擋）
  if (isUnbookable && !widget.allowBlockedTap) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('此日期已滿')),
  );
  return;
}

  /// 🔥 關閉日期
if (isBlocked && !widget.allowBlockedTap) {
  return;
}

  /// ✅ 正常
  widget.onDayTap(date);
},
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
  /// 日期
  Text(
    '${date.day}',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: dayTextColor,
    ),
  ),

  /// 🔥 剩餘房數（這是你缺的）
  if (remaining != null)
    Text(
      '剩 $remaining',
      style: TextStyle(
        fontSize: 10,
        color: remaining <= 1 ? Colors.red : Colors.grey,
      ),
    ),

  /// 🔥 關閉原因
  if (isBlocked && reason != null && reason.isNotEmpty)
    Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        reason,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
],
),
    ),
  );
}

  void _goPrevMonth() {
  setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
  });

  widget.onMonthChanged?.call(_visibleMonth); // 🔥 新增
}

  void _goNextMonth() {
  setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
  });

  widget.onMonthChanged?.call(_visibleMonth); // 🔥 新增
}

  bool _isSameMonthOrBefore(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, 1);
    final bb = DateTime(b.year, b.month, 1);
    return aa.isAtSameMomentAs(bb) || aa.isBefore(bb);
  }

  bool _isSameMonthOrAfter(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, 1);
    final bb = DateTime(b.year, b.month, 1);
    return aa.isAtSameMomentAs(bb) || aa.isAfter(bb);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    final aa = _dateOnly(a);
    final bb = _dateOnly(b);
    return aa.isAtSameMomentAs(bb);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDateKey(DateTime date) {
    final d = _dateOnly(date);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}