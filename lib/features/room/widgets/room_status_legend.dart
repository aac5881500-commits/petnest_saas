import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/room_status_palette.dart';

class RoomStatusLegend extends StatelessWidget {
  const RoomStatusLegend({
    super.key,
    required this.palette,
    this.fontSize = 12,
  });
  final RoomStatusPalette palette;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final entry in RoomStatusPalette.labels.entries)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: ValueKey('room-status-legend-${entry.key}'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: palette.color(entry.key),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: .5),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              entry.value,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
            ),
          ],
        ),
    ],
  );
}
