// 檔案名稱：lib/features/shop/widgets/booking/booking_calendar_dialog.dart
// 功能說明：前台預約月曆 Dialog：選擇入住日與退房日

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
    this.visualStyle = 'classic',
    this.presentation = 'dialog',
    this.density = 'auto',
    this.accentColor,
    this.backgroundColor,
    this.singleDay = false,
    this.compactCells = false,
  });

  static const double desktopMaxWidth = 680;
  static const double compactWidthBreakpoint = 600;

  final String visualStyle, presentation, density;
  final Color? accentColor, backgroundColor;
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
  final VoidCallback? onConfirm;

  /// 安親只選單日，仍共用同一個月曆視覺。
  final bool singleDay;
  final bool compactCells;

  @override
  Widget build(BuildContext context) {
    final double viewHeight = MediaQuery.sizeOf(context).height;

    final panel = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: desktopMaxWidth,
        maxHeight: viewHeight * 0.9,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool compact = density == 'compact'
              ? true
              : density == 'comfortable'
              ? false
              : compactCells || singleDay || width < compactWidthBreakpoint;
          return SafeArea(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (presentation != 'dialog')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (presentation == 'sheet')
                                    Center(
                                      child: Container(
                                        width: 36,
                                        height: 4,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const Text(
                                    '選擇住宿日期',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 24,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        '入住  ${tempStartDate == null ? '尚未選擇' : '${tempStartDate!.month}/${tempStartDate!.day}'}',
                                      ),
                                      Text(
                                        '退房  ${tempEndDate == null ? '尚未選擇' : '${tempEndDate!.month}/${tempEndDate!.day}'}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          BookingCalendar(
                            visualStyle: visualStyle,
                            accentColor: accentColor,
                            backgroundColor: backgroundColor,
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
                            compactCells: compact,
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
                                children: <Widget>[
                                  const Text(
                                    '⚠️ ',
                                    style: TextStyle(fontSize: 14),
                                  ),
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
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Row(
                      children: <Widget>[
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
          );
        },
      ),
    );
    if (presentation == 'sheet') {
      return Material(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: panel,
      );
    }
    return Dialog(
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: panel,
    );
  }
}

Future<T?> showBookingCalendarSurface<T>({
  required BuildContext context,
  required String presentation,
  required WidgetBuilder builder,
}) {
  if (presentation == 'sheet') {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: false,
    builder: builder,
  );
}
