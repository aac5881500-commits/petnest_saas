// 檔案名稱 lib/shared/widgets/booking_calendar.dart
//
// 共用預約月曆元件
//
// 用途：
// - 前台 / 後台共用同一套月曆視覺
// - 可顯示：
//   1. 不可預約日期
//   2. 關閉日期
//   3. 單日價格
//   4. 剩餘房數
//   5. 單日選取
//   6. 區間選取
//
// 備註：
// - 目前先做單月切換版
// - 不依賴外部套件
// - 下一步會接到後台預約管理頁
// - 再下一步會接到前台預約頁

import 'package:flutter/material.dart';

class BookingCalendar extends StatefulWidget {
  const BookingCalendar({
    super.key,
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onDayTap,
    this.selectedDate,
    this.rangeStart,
    this.rangeEnd,
    this.blockedDateKeys = const {},
    this.unbookableDateKeys = const {},
    this.priceMap = const {},
    this.remainingRoomsMap = const {},
  });

  final DateTime initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;

  final DateTime? selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  final Set<String> blockedDateKeys;
  final Set<String> unbookableDateKeys;
  final Map<String, int> priceMap;
  final Map<String, int> remainingRoomsMap;

  final ValueChanged<DateTime> onDayTap;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
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
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildWeekHeader(),
            const SizedBox(height: 8),
            GridView.count(
  crossAxisCount: 7,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisSpacing: 6,
  mainAxisSpacing: 6,
  childAspectRatio: 0.68,
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
    final dateKey = _formatDateKey(date);

    final bool isOutOfRange =
        date.isBefore(_dateOnly(widget.firstDate)) ||
        date.isAfter(_dateOnly(widget.lastDate));

    final bool isBlocked = widget.blockedDateKeys.contains(dateKey);
    final bool isUnbookable = widget.unbookableDateKeys.contains(dateKey);

    final bool isSelected = widget.selectedDate != null &&
        _isSameDate(widget.selectedDate!, date);

    final bool isRangeStart = widget.rangeStart != null &&
        _isSameDate(widget.rangeStart!, date);

    final bool isRangeEnd = widget.rangeEnd != null &&
        _isSameDate(widget.rangeEnd!, date);

    final bool isInRange = _isDateInRange(
      date: date,
      start: widget.rangeStart,
      end: widget.rangeEnd,
    );

    
    final int? remainingRooms = widget.remainingRoomsMap[dateKey];

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
    } else if (isRangeStart || isRangeEnd || isSelected) {
      backgroundColor = Colors.blue.shade600;
      borderColor = Colors.blue.shade700;
      dayTextColor = Colors.white;
    } else if (isInRange) {
      backgroundColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      dayTextColor = Colors.blue.shade900;
    }

    String bottomText = '';
    if (isBlocked) {
      bottomText = '關閉';
    } else if (isUnbookable) {
      bottomText = '不可訂';
    } else if (remainingRooms != null) {
      bottomText = '剩 $remainingRooms';
    }

    final bool canTap = !isOutOfRange;

    return InkWell(
  onTap: canTap ? () => widget.onDayTap(date) : null,
  borderRadius: BorderRadius.circular(12),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: dayTextColor,
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                bottomText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isRangeStart || isRangeEnd || isSelected
                      ? Colors.white
                      : (isBlocked || isUnbookable
                          ? Colors.red.shade700
                          : Colors.grey.shade700),
                ),
              ),
            ),
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
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
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

  bool _isDateInRange({
    required DateTime date,
    required DateTime? start,
    required DateTime? end,
  }) {
    if (start == null || end == null) return false;

    final d = _dateOnly(date);
    final s = _dateOnly(start);
    final e = _dateOnly(end);

    return (d.isAfter(s) && d.isBefore(e)) ||
        d.isAtSameMomentAs(s) ||
        d.isAtSameMomentAs(e);
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