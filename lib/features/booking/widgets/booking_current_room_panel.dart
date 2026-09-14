// 檔案名稱：lib/features/booking/widgets/booking_current_room_panel.dart
// 功能說明：住宿／安親共用目前房型與店家安排房間資訊列

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';
import 'package:petnest_saas/core/services/shop_room_name_lookup.dart';

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
    if (!room.needsRoomNameLookup) {
      return _panel(context, room, room.physicalDisplay(audience));
    }
    return FutureBuilder<Map<String, String>>(
      future: ShopRoomNameLookup.resolve(
        shopId: room.shopId,
        roomIds: <String>[room.roomId],
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, String>> snapshot,
          ) {
            final String resolved = (snapshot.data?[room.roomId] ?? '').trim();
            final String physical = snapshot.connectionState ==
                    ConnectionState.waiting
                ? '讀取房號中'
                : room.physicalDisplay(audience, resolvedRoomName: resolved);
            return _panel(context, room, physical);
          },
    );
  }

  Widget _panel(
    BuildContext context,
    BookingCurrentRoom room,
    String physical,
  ) {
    final bool staff = audience == BookingCurrentRoomAudience.staff;
    return staff
        ? _staffPanel(context, room, physical)
        : _customerBar(context, room, physical);
  }

  Widget _staffPanel(
    BuildContext context,
    BookingCurrentRoom room,
    String physical,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color ink = scheme.onSurface;
    final Color muted = ink.withValues(alpha: 0.62);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              room.hasPhysicalRoom ? Icons.vpn_key_outlined : Icons.meeting_room_outlined,
              color: scheme.primary,
              size: compact ? 20 : 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '目前安排',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '房型',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                Text(
                  room.typeDisplay(),
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '實際房間',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: room.hasPhysicalRoom
                          ? scheme.primary
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                      border: room.hasPhysicalRoom
                          ? null
                          : Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      physical,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: room.hasPhysicalRoom
                            ? scheme.onPrimary
                            : muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerBar(
    BuildContext context,
    BookingCurrentRoom room,
    String physical,
  ) {
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: 0.58);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: <Widget>[
          _customerRow(
            label: '目前房型',
            value: room.typeDisplay(),
            ink: ink,
            muted: muted,
          ),
          const SizedBox(height: 6),
          _customerRow(
            label: '店家安排房間',
            value: physical,
            ink: ink,
            muted: muted,
            emphasize: room.hasPhysicalRoom,
          ),
        ],
      ),
    );
  }

  Widget _customerRow({
    required String label,
    required String value,
    required Color ink,
    required Color muted,
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: muted, height: 1.3),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              color: ink,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
