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
    this.grouped = false,
  });

  final String selectedType;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;
  final List<BookingFilterChipSpec> items;
  final bool countsIncomplete;
  final bool grouped;

  static const List<BookingFilterChipSpec> stayItems = <BookingFilterChipSpec>[
    BookingFilterChipSpec(type: 'active', label: '全部'),
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
    BookingFilterChipSpec(type: 'awaitingClear', label: '待結清', attention: true),
    BookingFilterChipSpec(type: 'settled', label: '結清'),
    BookingFilterChipSpec(type: 'cancelled', label: '已取消'),
  ];

  static const List<BookingFilterChipSpec>
  daycareItems = <BookingFilterChipSpec>[
    BookingFilterChipSpec(type: 'active', label: '全部'),
    BookingFilterChipSpec(type: 'pending', label: '待確認', attention: true),
    BookingFilterChipSpec(
      type: 'depositReview',
      label: '已回傳付款／訂金',
      attention: true,
    ),
    BookingFilterChipSpec(type: 'confirmed', label: '已確認'),
    BookingFilterChipSpec(type: 'awaitingRoom', label: '待分房', attention: true),
    BookingFilterChipSpec(type: 'checked_in', label: '安親中', attention: true),
    BookingFilterChipSpec(type: 'todayDropOff', label: '今日安親', attention: true),
    BookingFilterChipSpec(type: 'todayPickUp', label: '今日結束', attention: true),
    BookingFilterChipSpec(type: 'futureCheckIn', label: '未來安親'),
    BookingFilterChipSpec(type: 'settled', label: '結清'),
    BookingFilterChipSpec(type: 'cancelled', label: '已取消'),
  ];

  @override
  Widget build(BuildContext context) {
    if (grouped) return _dashboard(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final BookingFilterChipSpec item = items[index];
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
                            : (selected ? Colors.white : Colors.brown.shade700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _count(String type) =>
      '${counts[type] ?? (countsIncomplete ? '—' : 0)}';

  Widget _dashboard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = items.where((item) => item.type.startsWith('today')).toList()
      ..addAll(items.where((item) => item.type == 'checked_in'));
    final other = items.where((item) => !today.contains(item)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              for (final (key, label, icon) in const [
                ('pending', '待確認', Icons.fact_check_outlined),
                ('depositReview', '待核對付款', Icons.credit_card_outlined),
                ('awaitingClear', '待結清', Icons.receipt_long_outlined),
              ])
                if (items.any((item) => item.type == key))
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        backgroundColor: selectedType == key
                            ? colors.primaryContainer
                            : colors.surface,
                      ),
                      onPressed: () => onChanged(key),
                      child: Column(
                        spacing: 4,
                        children: [
                          Icon(icon, size: 18),
                          Text(label, textAlign: TextAlign.center),
                          Text(
                            _count(key),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              for (final item in today)
                TextButton(
                  onPressed: () => onChanged(item.type),
                  child: Text('${item.label} ${_count(item.type)}'),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E8F0)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return PopupMenuButton<String>(
                    onSelected: onChanged,
                    itemBuilder: (_) => other
                        .map(
                          (item) => PopupMenuItem(
                            value: item.type,
                            child: Text(
                              '${item.type == 'active' ? '進行中全部' : item.label}  ${_count(item.type)}',
                            ),
                          ),
                        )
                        .toList(),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            items
                                        .firstWhere(
                                          (item) => item.type == selectedType,
                                          orElse: () => items.first,
                                        )
                                        .label ==
                                    '全部'
                                ? '進行中全部'
                                : items
                                      .firstWhere(
                                        (item) => item.type == selectedType,
                                        orElse: () => items.first,
                                      )
                                      .label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          _count(selectedType),
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: other.map((item) {
                    final selected = selectedType == item.type;
                    return TextButton(
                      onPressed: () => onChanged(item.type),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        backgroundColor: selected
                            ? colors.primary
                            : Colors.transparent,
                        foregroundColor: selected
                            ? Colors.white
                            : const Color(0xFF566176),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '${item.type == 'active' ? '進行中全部' : item.label}  ${_count(item.type)}',
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
