// 功能：首頁橫滑內容的末端入口樣式示意。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'environment_end_entry.dart';

class HomeEndEntryStylePicker extends StatelessWidget {
  const HomeEndEntryStylePicker({
    super.key,
    required this.value,
    required this.color,
    required this.label,
    required this.onChanged,
  });
  final String value, label;
  final Color color;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('末端入口樣式', style: TextStyle(fontWeight: FontWeight.bold)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final style in HomeEnvironmentEndEntryStyles.all)
            ChoiceChip(
              selected: HomeEnvironmentEndEntryStyles.migrate(value) == style,
              onSelected: (_) => onChanged(style),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: EnvironmentEndEntry(
                        style: style,
                        color: color,
                        label: label,
                        onPressed: () {},
                      ),
                    ),
                  ),
                  Text(HomeEnvironmentEndEntryStyles.label(style)),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}
