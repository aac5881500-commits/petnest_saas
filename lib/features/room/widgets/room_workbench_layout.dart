import 'package:flutter/material.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';

enum RoomOverviewFilter {
  all,
  needs,
  checkedIn,
  vacant,
  inUse,
  cleaning,
  closed,
  maintenance,
  disabled,
}

bool roomOverviewMatches({
  required RoomOverviewFilter filter,
  required RoomStatusPresentation status,
  required bool needsAction,
  String query = '',
  String name = '',
  String type = '',
  String pets = '',
}) {
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final haystack = '$name $type $pets'.toLowerCase();
  if (!words.every(haystack.contains)) return false;
  return switch (filter) {
    RoomOverviewFilter.all => true,
    RoomOverviewFilter.needs => needsAction,
    RoomOverviewFilter.checkedIn =>
      status.label == RoomStatusPresentation.stayCheckedIn().label,
    RoomOverviewFilter.vacant =>
      status.label == RoomStatusPresentation.available().label,
    RoomOverviewFilter.inUse => RoomStatusPresentation.isInUseLabel(
      status.label,
    ),
    RoomOverviewFilter.cleaning =>
      status.label == RoomStatusPresentation.cleaning().label,
    RoomOverviewFilter.closed =>
      status.label == RoomStatusPresentation.closed().label,
    RoomOverviewFilter.maintenance =>
      status.label == RoomStatusPresentation.maintenance().label,
    RoomOverviewFilter.disabled =>
      status.label == RoomStatusPresentation.disabled().label,
  };
}

/// Keep the room rail readable without consuming the calendar's working space.
class RoomWorkbenchSplit extends StatelessWidget {
  const RoomWorkbenchSplit({
    super.key,
    required this.rooms,
    required this.detail,
  });
  final Widget rooms;
  final Widget detail;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rail = constraints.maxWidth >= 1200 ? 360.0 : 300.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: rail, child: rooms),
          const SizedBox(width: 16),
          Expanded(child: detail),
        ],
      );
    },
  );
}

class RoomWorkbenchRoomCard extends StatelessWidget {
  const RoomWorkbenchRoomCard({
    super.key,
    required this.name,
    required this.type,
    required this.status,
    required this.selected,
    required this.days,
    required this.colors,
    required this.labels,
    required this.selectedDate,
    required this.onTap,
    required this.onDayTap,
    this.pets = '',
    this.pending = 0,
  });
  final String name, type, pets;
  final RoomStatusPresentation status;
  final bool selected;
  final List<DateTime> days;
  final List<Color> colors;
  final List<String> labels;
  final DateTime selectedDate;
  final VoidCallback onTap;
  final ValueChanged<int> onDayTap;
  final int pending;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFEDF3FC) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? accent : const Color(0xFFE4E7EC),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    RoomStatusChip(presentation: status, compact: true),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pets.isEmpty ? type : '$type · $pets',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                    height: 1.5,
                  ),
                ),
                if (pending > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '待填回報 $pending 項',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 0; index < days.length; index++)
                      Expanded(
                        child: Tooltip(
                          message:
                              '${days[index].month}/${days[index].day} · ${labels[index]}',
                          child: Semantics(
                            button: true,
                            selected: DateUtils.isSameDay(
                              days[index],
                              selectedDate,
                            ),
                            label:
                                '${days[index].month}/${days[index].day} ${labels[index]}',
                            child: InkWell(
                              onTap: () => onDayTap(index),
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  color:
                                      DateUtils.isSameDay(
                                        days[index],
                                        selectedDate,
                                      )
                                      ? accent.withValues(alpha: 0.09)
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${days[index].day}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            DateUtils.isSameDay(
                                              days[index],
                                              selectedDate,
                                            )
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: const Color(0xFF667085),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colors[index],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoomRecordWorkspaceLayout extends StatelessWidget {
  const RoomRecordWorkspaceLayout({
    super.key,
    required this.calendar,
    required this.detail,
  });
  final Widget calendar;
  final Widget detail;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 420) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 55, child: calendar),
            const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
            Expanded(flex: 45, child: detail),
          ],
        );
      }
      if (constraints.maxHeight < 480) {
        return ListView(
          children: [
            SizedBox(height: 360, child: calendar),
            const Divider(height: 1),
            SizedBox(height: 420, child: detail),
          ],
        );
      }
      final calendarHeight = (constraints.maxHeight * 0.5).clamp(300.0, 420.0);
      return Column(
        children: [
          SizedBox(height: calendarHeight, child: calendar),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(child: detail),
        ],
      );
    },
  );
}
