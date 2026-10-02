// 檔案名稱：lib/features/room/widgets/room_status_chip.dart
// 功能說明：房務狀態 chip、清潔完成確認與有訂單時的開啟規則。
// 顏色與圖示只來自 RoomStatusPresentation。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';

enum RoomOverviewGesture { roomCard, weekDot, calendarDay, viewOrderButton }

class RoomOverviewGestureResult {
  const RoomOverviewGestureResult({
    required this.navigatesToOrder,
    this.roomId,
    this.date,
    this.bookingId,
  });

  final bool navigatesToOrder;
  final String? roomId;
  final DateTime? date;
  final String? bookingId;
}

/// 房間卡、日期圓點、月曆日期格都只選取。只有「查看訂單」才帶訂單。
RoomOverviewGestureResult resolveRoomOverviewGesture({
  required RoomOverviewGesture gesture,
  required String roomId,
  required DateTime date,
  String? bookingId,
}) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  if (gesture == RoomOverviewGesture.viewOrderButton) {
    final String id = (bookingId ?? '').trim();
    return RoomOverviewGestureResult(
      navigatesToOrder: id.isNotEmpty,
      roomId: roomId,
      date: day,
      bookingId: id.isEmpty ? null : id,
    );
  }
  return RoomOverviewGestureResult(
    navigatesToOrder: false,
    roomId: roomId,
    date: day,
  );
}

class RoomDayBookingChoice {
  const RoomDayBookingChoice({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

enum RoomOverviewOpenKind { orderDetail, bookingPicker, roomRecord }

class RoomOverviewOpenPlan {
  const RoomOverviewOpenPlan({required this.kind, this.booking});

  final RoomOverviewOpenKind kind;
  final RoomDayBookingChoice? booking;
}

/// 有有效訂單才進訂單；多筆不可代選；沒有訂單才開房間紀錄。
RoomOverviewOpenPlan planRoomOverviewOpen(List<RoomDayBookingChoice> matches) {
  if (matches.isEmpty) {
    return const RoomOverviewOpenPlan(kind: RoomOverviewOpenKind.roomRecord);
  }
  if (matches.length == 1) {
    return RoomOverviewOpenPlan(
      kind: RoomOverviewOpenKind.orderDetail,
      booking: matches.single,
    );
  }
  return const RoomOverviewOpenPlan(kind: RoomOverviewOpenKind.bookingPicker);
}

List<RoomDayBookingChoice> activeBookingsOnRoomDay({
  required Iterable<RoomDayBookingChoice> bookings,
  required String roomId,
  required DateTime day,
  Iterable<Map<String, dynamic>> occupancies = const <Map<String, dynamic>>[],
}) {
  if (roomId.isEmpty) {
    return const <RoomDayBookingChoice>[];
  }
  return bookings.where((RoomDayBookingChoice choice) {
    if ((choice.data['roomId'] ?? '').toString() != roomId) {
      return false;
    }
    if (BookingKind.isDaycare(choice.data)) {
      final String status = (choice.data['status'] ?? '').toString();
      if (status != 'pending' &&
          status != 'confirmed' &&
          status != 'checked_in') {
        return false;
      }
      if (!roomDayBookingCovers(booking: choice.data, date: day)) {
        return false;
      }
      return occupancies.any(
        (Map<String, dynamic> occupancy) => daycareOccupancyCoversRoomDay(
          occupancy: occupancy,
          roomId: roomId,
          bookingId: choice.id,
          day: day,
        ),
      );
    }
    if (!isActiveRoomDayBooking(choice.data)) {
      return false;
    }
    return roomDayBookingCovers(booking: choice.data, date: day);
  }).toList();
}

/// 只供狀態 chip 顯示一筆代表訂單，不可拿來決定要開啟哪一筆。
RoomDayBookingChoice? preferredRoomDayBooking(
  List<RoomDayBookingChoice> matches,
) {
  RoomDayBookingChoice? best;
  int bestPriority = -1;
  for (final RoomDayBookingChoice choice in matches) {
    final int priority = roomDayBookingPriority(choice.data);
    if (priority > bestPriority) {
      bestPriority = priority;
      best = choice;
    }
  }
  return best;
}

/// 回傳 available、closed，或取消時的 null。取消不可寫入。
Future<String?> showRoomCleaningCompleteDialog(BuildContext context) async {
  String selectedResult = 'available';
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: const Row(
              children: <Widget>[
                Icon(
                  Icons.cleaning_services_outlined,
                  color: RoomStatusPresentation.cleaningColor,
                ),
                SizedBox(width: 8),
                Text('清潔完成'),
              ],
            ),
            content: RadioGroup<String>(
              groupValue: selectedResult,
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setDialogState(() {
                  selectedResult = value;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  RadioListTile<String>(
                    value: 'available',
                    activeColor: RoomStatusPresentation.availableColor,
                    title: const Text(
                      '完成並立即開放',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('此日期恢復為空房，可再次接受預約'),
                  ),
                  RadioListTile<String>(
                    value: 'closed',
                    activeColor: RoomStatusPresentation.closedColor,
                    title: const Text(
                      '完成但今日維持關閉',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('完成清潔，但此日期仍不開放預約'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('確認'),
              ),
            ],
          );
        },
      );
    },
  );
  if (confirmed != true) {
    return null;
  }
  return selectedResult;
}

Future<RoomDayBookingChoice?> showRoomDayBookingPicker(
  BuildContext context,
  List<RoomDayBookingChoice> choices,
) {
  return showDialog<RoomDayBookingChoice>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('選擇訂單'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((RoomDayBookingChoice choice) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(roomDayBookingMenuTitle(choice.data)),
                subtitle: Text(roomDayBookingMenuSubtitle(choice.data)),
                onTap: () => Navigator.of(dialogContext).pop(choice),
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

String roomDayTaipeiDateText(Object? raw) {
  DateTime? date;
  if (raw is Timestamp) {
    date = raw.toDate();
  } else if (raw is DateTime) {
    date = raw;
  }
  if (date == null) {
    return '—';
  }
  final DateTime day = DailyCareDateHelper.calendarDateInTaipei(date);
  final String month = day.month.toString().padLeft(2, '0');
  final String dayText = day.day.toString().padLeft(2, '0');
  return '${day.year}/$month/$dayText';
}

String roomDayBookingMenuTitle(Map<String, dynamic> data) {
  final String code = (data['bookingCode'] ?? '').toString().trim();
  final String customer = (data['customerName'] ?? '').toString().trim();
  if (code.isNotEmpty && customer.isNotEmpty) {
    return '$code・$customer';
  }
  if (customer.isNotEmpty) {
    return customer;
  }
  if (code.isNotEmpty) {
    return code;
  }
  return '訂單';
}

String roomDayBookingMenuSubtitle(Map<String, dynamic> data) {
  final String label = RoomStatusPresentation.of(
    roomStatus: 'available',
    booking: data,
  ).label;
  final String range = _bookingRange(data);
  if (range.isEmpty) {
    return label;
  }
  return '$label・$range';
}

String _bookingRange(Map<String, dynamic> data) {
  final DateTime? start = _readDate(data['startDate']);
  final DateTime? end = _readDate(data['endDate']);
  if (start == null || end == null) {
    return '';
  }
  String text(DateTime date) {
    return '${date.month}/${date.day}';
  }

  return '${text(start)}-${text(end)}';
}

DateTime? _readDate(Object? raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  return null;
}

class RoomStatusChip extends StatelessWidget {
  const RoomStatusChip({
    super.key,
    required this.presentation,
    this.compact = false,
  });

  final RoomStatusPresentation presentation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: presentation.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            presentation.icon,
            size: compact ? 13 : 14,
            color: presentation.color,
          ),
          const SizedBox(width: 4),
          Text(
            presentation.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: presentation.color,
            ),
          ),
        ],
      ),
    );
  }
}

class RoomDayOrderSummaries extends StatelessWidget {
  const RoomDayOrderSummaries({
    super.key,
    required this.orders,
    required this.onViewOrder,
    this.heading = '訂單摘要',
    this.sourceStay = false,
  });

  final List<RoomDayBookingChoice> orders;
  final ValueChanged<RoomDayBookingChoice> onViewOrder;
  final String heading;
  final bool sourceStay;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Text(
        '此日期沒有有效訂單或安親訂單',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final RoomDayBookingChoice order in orders)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  heading,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                if (!sourceStay)
                  Text(
                    '服務類型：${BookingKind.isDaycare(order.data) ? '安親' : '住宿'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if (BookingKind.isDaycare(order.data))
                  ..._daycareTimeLines(order.data)
                else
                  ..._stayDateLines(order.data),
                if (_customerName(order.data).isNotEmpty)
                  Text(
                    '客戶：${_customerName(order.data)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (_orderPetNames(order.data).isNotEmpty)
                  Text(
                    '寵物：${_orderPetNames(order.data)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                if (!sourceStay)
                  Text(
                    '訂單狀態：${RoomStatusPresentation.of(roomStatus: 'available', booking: order.data).label}',
                    style: const TextStyle(fontSize: 13),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => onViewOrder(order),
                    child: const Text('查看訂單'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _customerName(Map<String, dynamic> booking) {
  final String name = (booking['customerName'] ?? '').toString().trim();
  if (name.isEmpty || name == 'null') {
    return '';
  }
  return name;
}

List<Widget> _daycareTimeLines(Map<String, dynamic> booking) {
  final String span = daycareServiceTimeLabel(booking);
  if (span.isEmpty) {
    return const <Widget>[];
  }
  return <Widget>[
    Text('服務時間：$span', style: const TextStyle(fontSize: 13)),
  ];
}

List<Widget> _stayDateLines(Map<String, dynamic> booking) {
  final String checkIn = roomDayTaipeiDateText(booking['startDate']);
  final String checkOut = roomDayTaipeiDateText(booking['endDate']);
  return <Widget>[
    if (checkIn != '—')
      Text('入住日期：$checkIn', style: const TextStyle(fontSize: 13)),
    if (checkOut != '—')
      Text('退房日期：$checkOut', style: const TextStyle(fontSize: 13)),
  ];
}

String _orderPetNames(Map<String, dynamic> booking) {
  final Object? names = booking['petNames'] ?? booking['petName'];
  if (names is List) {
    final String text = names
        .map((Object? value) => value.toString().trim())
        .where((String value) => value.isNotEmpty)
        .join('、');
    if (text.isNotEmpty) {
      return text;
    }
  } else if (names is String && names.trim().isNotEmpty) {
    return names.trim();
  }
  final Object? pets = booking['pets'];
  if (pets is List) {
    final String text = pets
        .map((Object? value) {
          if (value is Map) {
            return (value['name'] ?? '').toString().trim();
          }
          return value.toString().trim();
        })
        .where((String value) => value.isNotEmpty)
        .join('、');
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

class RoomSelectedDateSummary extends StatelessWidget {
  const RoomSelectedDateSummary({
    super.key,
    required this.date,
    required this.status,
  });

  final DateTime date;
  final RoomDayStatus status;

  @override
  Widget build(BuildContext context) {
    final String dateText =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final RoomStatusPresentation chip = status.isHistory
        ? RoomStatusPresentation(
            value: 'history',
            label: status.label,
            color: status.color,
            background: status.color.withValues(alpha: 0.12),
            border: status.color.withValues(alpha: 0.35),
            icon: Icons.history,
          )
        : status.presentation;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '所選日期 $dateText',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        RoomStatusChip(presentation: chip, compact: true),
      ],
    );
  }
}

class RoomWeekDots extends StatelessWidget {
  const RoomWeekDots({super.key, required this.colors, this.onDotTap});

  final List<Color> colors;
  final ValueChanged<int>? onDotTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
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
          children: <Widget>[
            for (int index = 0; index < colors.length; index++)
              GestureDetector(
                onTap: onDotTap == null ? null : () => onDotTap!(index),
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekText extends StatelessWidget {
  const _WeekText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
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
