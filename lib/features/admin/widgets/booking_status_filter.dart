// 檔案名稱：lib/features/admin/widgets/booking_status_filter.dart
// 功能說明：後台訂單狀態篩選膠囊；待處理數量 > 0 時顯示紅色數字

import 'package:flutter/material.dart';

class BookingFilterChipSpec {
  const BookingFilterChipSpec({
    required this.type,
    required this.label,
    this.attention = false,
  });

  final String type;
  final String label;
  final bool attention;
}

class BookingStatusFilter extends StatelessWidget {
  const BookingStatusFilter({
    super.key,
    required this.selectedType,
    required this.counts,
    required this.onChanged,
    required this.items,
    this.countsIncomplete = false,
  });

  final String selectedType;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;
  final List<BookingFilterChipSpec> items;
  final bool countsIncomplete;

  static const List<BookingFilterChipSpec> stayItems = <BookingFilterChipSpec>[
    BookingFilterChipSpec(type: 'pending', label: '待確認', attention: true),
    BookingFilterChipSpec(
      type: 'depositReview',
      label: '已回傳付款／訂金',
      attention: true,
    ),
    BookingFilterChipSpec(type: 'confirmed', label: '已確認'),
    BookingFilterChipSpec(type: 'awaitingRoom', label: '待分房', attention: true),
    BookingFilterChipSpec(type: 'checked_in', label: '入住中', attention: true),
    BookingFilterChipSpec(type: 'todayCheckIn', label: '今日入住', attention: true),
    BookingFilterChipSpec(
      type: 'todayCheckOut',
      label: '今日退房',
      attention: true,
    ),
    BookingFilterChipSpec(type: 'futureCheckIn', label: '未來入住'),
    BookingFilterChipSpec(type: 'history', label: '歷史訂單'),
  ];

  static const List<BookingFilterChipSpec>
  daycareItems = <BookingFilterChipSpec>[
    BookingFilterChipSpec(type: 'pending', label: '待確認', attention: true),
    BookingFilterChipSpec(
      type: 'depositReview',
      label: '已回傳付款／訂金',
      attention: true,
    ),
    BookingFilterChipSpec(type: 'confirmed', label: '已確認'),
    BookingFilterChipSpec(type: 'awaitingRoom', label: '待分房', attention: true),
    BookingFilterChipSpec(type: 'checked_in', label: '安親中', attention: true),
    BookingFilterChipSpec(type: 'todayDropOff', label: '今日送達', attention: true),
    BookingFilterChipSpec(type: 'todayPickUp', label: '今日接回', attention: true),
    BookingFilterChipSpec(type: 'history', label: '歷史訂單'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((BookingFilterChipSpec item) {
          final bool selected = selectedType == item.type;
          final bool hasCount = counts.containsKey(item.type);
          final int count = hasCount ? counts[item.type]! : 0;
          final String countText = hasCount
              ? count.toString()
              : (countsIncomplete ? '—' : '0');
          final bool showRed =
              item.attention && hasCount && count > 0 && !selected;
          final Color chipColor = selected
              ? Theme.of(context).colorScheme.primary
              : Colors.brown.shade100;
          return GestureDetector(
            onTap: () => onChanged(item.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.brown.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.type != 'history' ||
                      count > 0 ||
                      !hasCount) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: showRed
                            ? Colors.red
                            : (selected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.85)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        countText,
                        style: TextStyle(
                          color: showRed
                              ? Colors.white
                              : (selected
                                    ? Colors.white
                                    : Colors.brown.shade700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
