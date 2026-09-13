// 檔案名稱：lib/features/booking/widgets/booking_current_room_panel.dart
// 功能說明：住宿／安親共用目前房型與店家安排房間資訊列

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';

class BookingCurrentRoomPanel extends StatelessWidget {
  const BookingCurrentRoomPanel({
    super.key,
    required this.data,
    required this.audience,
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final BookingCurrentRoomAudience audience;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BookingCurrentRoom room = BookingCurrentRoom.fromBooking(data);
    final bool staff = audience == BookingCurrentRoomAudience.staff;
    final String typeLabel = staff ? '房型' : '目前房型';
    final String physicalLabel = staff ? '實際房間' : '店家安排房間';
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: 0.62);
    final Color fill = staff
        ? theme.colorScheme.primary.withValues(alpha: 0.10)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final Color border = theme.colorScheme.primary.withValues(alpha: 0.28);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            staff ? '目前房間' : '目前安排',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _badge(
                label: typeLabel,
                value: room.typeDisplay(),
                ink: ink,
                muted: muted,
              ),
              _badge(
                label: physicalLabel,
                value: room.physicalDisplay(audience),
                ink: ink,
                muted: muted,
                emphasize: room.hasPhysicalRoom,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required String label,
    required String value,
    required Color ink,
    required Color muted,
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label  ',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ink,
                decoration: emphasize ? null : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
