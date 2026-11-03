import 'package:flutter/material.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'front_calendar_payload.dart';

/// 月曆直選版使用正式月份可預約資料，跨月逐月檢查，載入失敗時不允許套用。
class BookingInlineCalendar extends StatefulWidget {
  const BookingInlineCalendar({
    super.key,
    required this.today,
    required this.maxDays,
    required this.loadMonth,
    required this.onApply,
    this.startDate,
    this.endDate,
    this.enabled = true,
  });
  final DateTime today;
  final int maxDays;
  final bool enabled;
  final DateTime? startDate, endDate;
  final Future<FrontCalendarPayload> Function(DateTime) loadMonth;
  final void Function(DateTime, DateTime) onApply;
  @override
  State<BookingInlineCalendar> createState() => _BookingInlineCalendarState();
}

class _BookingInlineCalendarState extends State<BookingInlineCalendar> {
  late DateTime _month;
  DateTime? _start, _end;
  bool _busy = false;
  String _message = '';
  final _months = <String, Future<FrontCalendarPayload>>{};
  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.today.year, widget.today.month);
    _start = widget.startDate;
    _end = widget.endDate;
  }

  String _key(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  Future<FrontCalendarPayload> _load(DateTime month) => _months.putIfAbsent(
    '${month.year}-${month.month}',
    () => widget.loadMonth(month),
  );
  Future<void> _tap(DateTime day) async {
    if (_busy || !widget.enabled) return;
    if (_start == null || _end != null || !day.isAfter(_start!)) {
      setState(() {
        _start = day;
        _end = null;
        _message = '請再選擇退房日';
      });
      return;
    }
    setState(() {
      _busy = true;
      _end = null;
      _message = '';
    });
    try {
      for (
        var d = _start!;
        d.isBefore(day);
        d = d.add(const Duration(days: 1))
      ) {
        final payload = await _load(DateTime(d.year, d.month));
        if (!mounted) return;
        if (payload.blockedDateKeys.contains(_key(d)) ||
            payload.unbookableDateKeys.contains(_key(d))) {
          setState(() => _message = '這段住宿包含休息日或已滿日期，請重新選擇');
          return;
        }
      }
      if (mounted) {
        setState(() {
          _end = day;
          _message = '共 ${day.difference(_start!).inDays} 晚，請套用住宿日期';
        });
      }
    } catch (_) {
      _months.clear();
      if (mounted) setState(() => _message = '無法確認這段日期，請重新選擇退房日再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('目前店家暫停開放預約'),
      );
    }
    return FutureBuilder<FrontCalendarPayload>(
      future: _load(_month),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('無法載入可預約日期'),
              TextButton(
                onPressed: () => setState(() => _months.clear()),
                child: const Text('重新載入'),
              ),
            ],
          );
        }
        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IgnorePointer(
              ignoring: _busy,
              child: BookingCalendar(
                key: ValueKey('${_month.year}-${_month.month}'),
                initialMonth: _month,
                firstDate: widget.today,
                lastDate: widget.today.add(Duration(days: widget.maxDays)),
                rangeStart: _start,
                rangeEnd: _end,
                blockedDateKeys: data.blockedDateKeys,
                blockedDateReasons: data.blockedDateReasons,
                unbookableDateKeys: data.unbookableDateKeys,
                remainingRoomsMap: data.remainingRoomsMap,
                specialOpenDateKeys: data.specialOpenDateKeys,
                compactCells: true,
                onDayTap: _tap,
                onMonthChanged: (month) => setState(() => _month = month),
              ),
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(_message, style: const TextStyle(fontSize: 12)),
              ),
            FilledButton(
              onPressed: !_busy && _start != null && _end != null
                  ? () => widget.onApply(_start!, _end!)
                  : null,
              child: Text(_busy ? '確認日期中…' : '套用住宿日期'),
            ),
          ],
        );
      },
    );
  }
}
