// 檔案名稱：lib/features/room/widgets/room_status_chip.dart
// 功能說明：房務狀態 chip，顏色與圖示只來自 RoomStatusPresentation。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';

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

class RoomWeekDots extends StatelessWidget {
  const RoomWeekDots({super.key, required this.colors});

  final List<Color> colors;

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
            for (final Color color in colors)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
