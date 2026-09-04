// lib/features/member/widgets/member_filter_chips.dart
// 水平篩選膠囊。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberCountTab extends StatelessWidget {
  const MemberCountTab({super.key, required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = MemberUi.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: theme.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class MemberFilterOption {
  const MemberFilterOption({required this.id, required this.label, this.count});

  final String id;
  final String label;
  final int? count;
}

class MemberFilterChips extends StatelessWidget {
  const MemberFilterChips({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MemberFilterOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((MemberFilterOption option) {
          final bool selected = option.id == selectedId;
          final String label = option.count == null
              ? option.label
              : '${option.label} ${option.count}';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(option.id),
              selectedColor: MemberUi.of(context).primarySoft,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? MemberUi.of(context).primaryColor
                    : MemberUi.of(context).subtitleColor,
              ),
              side: BorderSide(
                color: selected
                    ? MemberUi.of(context).primaryColor.withValues(alpha: 0.35)
                    : MemberUi.of(context).borderColor,
              ),
              backgroundColor: MemberUi.of(context).cardColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}
