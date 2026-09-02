// lib/features/shop/widgets/booking/booking_calendar_dialog.dart
// 🔥 前台預約月曆 Dialog：選擇入住日與退房日

import 'package:flutter/material.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';

class BookingCalendarDialog extends StatelessWidget {
  const BookingCalendarDialog({
    super.key,
    required this.payload,
    required this.calendarMonth,
    required this.today,
    required this.maxDays,
    required this.tempStartDate,
    required this.tempEndDate,
    required this.rangeMessage,
    required this.onMonthChanged,
    required this.onDayTap,
    required this.onCancel,
    required this.onConfirm,
    this.singleDay = false,
  });

  final FrontCalendarPayload payload;

  final DateTime calendarMonth;
  final DateTime today;
  final int maxDays;

  final DateTime? tempStartDate;
  final DateTime? tempEndDate;

  final String rangeMessage;

  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTap;

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  /// 臨托只選單日，仍共用同一個月曆視覺。
  final bool singleDay;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          width: MediaQuery.of(context).size.width * 0.94,
          child: SingleChildScrollView(
            child: Column(
              children: [
                BookingCalendar(
                  key: ValueKey('${tempStartDate}_${tempEndDate}'),

                  initialMonth: calendarMonth,

                  firstDate: today,

                  lastDate: today.add(Duration(days: maxDays)),

                  rangeStart: tempStartDate,
                  rangeEnd: tempEndDate,

                  blockedDateKeys: payload.blockedDateKeys,
                  blockedDateReasons: payload.blockedDateReasons,

                  unbookableDateKeys: payload.unbookableDateKeys,
                  specialOpenDateKeys: payload.specialOpenDateKeys,

                  remainingRoomsMap: payload.remainingRoomsMap,

                  onMonthChanged: onMonthChanged,

                  onDayTap: onDayTap,
                ),

                if (rangeMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️ ', style: TextStyle(fontSize: 14)),

                        Expanded(
                          child: Text(
                            rangeMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('取消'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          child: const Text(
                            '確認',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
