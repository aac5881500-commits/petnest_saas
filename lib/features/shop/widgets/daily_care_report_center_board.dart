// 檔案名稱：lib/features/shop/widgets/daily_care_report_center_board.dart
// 功能說明：每日回報中心房間看板：手機單欄、平板單欄、桌機左篩選＋雙欄卡片。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_center_room_group.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../room/daily_care_record_edit_launcher.dart';

class DailyCareReportCenterBoard extends StatelessWidget {
  const DailyCareReportCenterBoard({
    super.key,
    required this.snapshot,
    required this.setting,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  static const double phoneMax = 600;
  static const double desktopMin = 1024;
  static const double twoColumnMin = 1180;
  static const double desktopMaxWidth = 1360;

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final List<DailyCareReportCenterRoomGroup> groups =
        DailyCareReportCenterGrouping.visible(
          items: snapshot.items,
          status: status,
          type: type,
        );
    if (width >= desktopMin) {
      return _DesktopBoard(
        snapshot: snapshot,
        setting: setting,
        groups: groups,
        status: status,
        type: type,
        onStatus: onStatus,
        onType: onType,
      );
    }
    if (width >= phoneMax) {
      return _TabletBoard(
        snapshot: snapshot,
        setting: setting,
        groups: groups,
        status: status,
        type: type,
        onStatus: onStatus,
        onType: onType,
      );
    }
    return _PhoneBoard(
      snapshot: snapshot,
      setting: setting,
      groups: groups,
      status: status,
      type: type,
      onStatus: onStatus,
      onType: onType,
    );
  }
}

class DailyCareReportCenterErrorPane extends StatelessWidget {
  const DailyCareReportCenterErrorPane({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('目前無法取得每日回報，請稍後再試', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重新整理')),
          ],
        ),
      ),
    );
  }
}

class _PhoneBoard extends StatelessWidget {
  const _PhoneBoard({
    required this.snapshot,
    required this.setting,
    required this.groups,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final List<DailyCareReportCenterRoomGroup> groups;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _CompactSummary(snapshot: snapshot),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: _FilterRows(
            snapshot: snapshot,
            status: status,
            type: type,
            onStatus: onStatus,
            onType: onType,
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? _EmptyState(status: status)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: groups.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RoomCard(
                        group: groups[index],
                        setting: setting,
                        compact: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TabletBoard extends StatelessWidget {
  const _TabletBoard({
    required this.snapshot,
    required this.setting,
    required this.groups,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final List<DailyCareReportCenterRoomGroup> groups;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _WideSummary(snapshot: snapshot),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: _FilterRows(
            snapshot: snapshot,
            status: status,
            type: type,
            onStatus: onStatus,
            onType: onType,
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? _EmptyState(status: status)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: groups.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RoomCard(
                        group: groups[index],
                        setting: setting,
                        compact: false,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DesktopBoard extends StatelessWidget {
  const _DesktopBoard({
    required this.snapshot,
    required this.setting,
    required this.groups,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final List<DailyCareReportCenterRoomGroup> groups;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DailyCareReportCenterBoard.desktopMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '每日回報中心',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              _WideSummary(snapshot: snapshot),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 240,
                      child: _FilterRail(
                        snapshot: snapshot,
                        status: status,
                        type: type,
                        onStatus: onStatus,
                        onType: onType,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: groups.isEmpty
                          ? _EmptyState(status: status)
                          : _DesktopCardGrid(groups: groups, setting: setting),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopCardGrid extends StatelessWidget {
  const _DesktopCardGrid({required this.groups, required this.setting});

  final List<DailyCareReportCenterRoomGroup> groups;
  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns =
            MediaQuery.sizeOf(context).width <
                DailyCareReportCenterBoard.twoColumnMin
            ? 1
            : 2;
        return ListView.builder(
          itemCount: (groups.length / columns).ceil(),
          itemBuilder: (BuildContext context, int row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int col = 0; col < columns; col++) ...<Widget>[
                      if (col > 0) const SizedBox(width: 12),
                      Expanded(
                        child: row * columns + col < groups.length
                            ? _RoomCard(
                                group: groups[row * columns + col],
                                setting: setting,
                                compact: false,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({required this.snapshot});

  final DailyCareReportCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final bool done = snapshot.totalCount > 0 && snapshot.pendingCount == 0;
    final double progress = snapshot.totalCount == 0
        ? 0
        : snapshot.completedCount / snapshot.totalCount;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress,
                backgroundColor: const Color(0xFFE8EDF2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Text(
                  '今天回報',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                if (done)
                  const Text(
                    '今日回報已完成',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Text(
                    '待填 ${snapshot.pendingCount} 場／完成 ${snapshot.completedCount} 場',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WideSummary extends StatelessWidget {
  const _WideSummary({required this.snapshot});

  final DailyCareReportCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final double progress = snapshot.totalCount == 0
        ? 0
        : snapshot.completedCount / snapshot.totalCount;
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress,
                backgroundColor: const Color(0xFFE8EDF2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _stat(
                  '待填',
                  '${snapshot.pendingCount} 場',
                  const Color(0xFFE65100),
                ),
                _stat(
                  '已完成',
                  '${snapshot.completedCount} 場',
                  const Color(0xFF2E7D32),
                ),
                _stat(
                  '共計',
                  '${snapshot.totalCount} 場',
                  const Color(0xFF1565C0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _FilterRows extends StatelessWidget {
  const _FilterRows({
    required this.snapshot,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DailyCareReportCenterStatusFilter>(
              showSelectedIcon: false,
              segments: <ButtonSegment<DailyCareReportCenterStatusFilter>>[
                ButtonSegment<DailyCareReportCenterStatusFilter>(
                  value: DailyCareReportCenterStatusFilter.all,
                  label: Text('全部 ${snapshot.totalCount}'),
                ),
                ButtonSegment<DailyCareReportCenterStatusFilter>(
                  value: DailyCareReportCenterStatusFilter.pending,
                  label: Text('待填 ${snapshot.pendingCount}'),
                ),
                ButtonSegment<DailyCareReportCenterStatusFilter>(
                  value: DailyCareReportCenterStatusFilter.completed,
                  label: Text('已完成 ${snapshot.completedCount}'),
                ),
              ],
              selected: <DailyCareReportCenterStatusFilter>{status},
              onSelectionChanged:
                  (Set<DailyCareReportCenterStatusFilter> value) {
                    onStatus(value.first);
                  },
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DailyCareReportCenterTypeFilter>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<DailyCareReportCenterTypeFilter>>[
                ButtonSegment<DailyCareReportCenterTypeFilter>(
                  value: DailyCareReportCenterTypeFilter.all,
                  label: Text('全部'),
                ),
                ButtonSegment<DailyCareReportCenterTypeFilter>(
                  value: DailyCareReportCenterTypeFilter.accommodation,
                  label: Text('住宿'),
                ),
                ButtonSegment<DailyCareReportCenterTypeFilter>(
                  value: DailyCareReportCenterTypeFilter.daycare,
                  label: Text('安親'),
                ),
              ],
              selected: <DailyCareReportCenterTypeFilter>{type},
              onSelectionChanged: (Set<DailyCareReportCenterTypeFilter> value) {
                onType(value.first);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.snapshot,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('狀態', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          _railTile(
            label: '全部',
            badge: snapshot.totalCount,
            selected: status == DailyCareReportCenterStatusFilter.all,
            onTap: () => onStatus(DailyCareReportCenterStatusFilter.all),
          ),
          _railTile(
            label: '待填',
            badge: snapshot.pendingCount,
            selected: status == DailyCareReportCenterStatusFilter.pending,
            onTap: () => onStatus(DailyCareReportCenterStatusFilter.pending),
          ),
          _railTile(
            label: '已完成',
            badge: snapshot.completedCount,
            selected: status == DailyCareReportCenterStatusFilter.completed,
            onTap: () => onStatus(DailyCareReportCenterStatusFilter.completed),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('類型', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          _railTile(
            label: '全部',
            selected: type == DailyCareReportCenterTypeFilter.all,
            onTap: () => onType(DailyCareReportCenterTypeFilter.all),
          ),
          _railTile(
            label: '住宿',
            selected: type == DailyCareReportCenterTypeFilter.accommodation,
            onTap: () => onType(DailyCareReportCenterTypeFilter.accommodation),
          ),
          _railTile(
            label: '安親',
            selected: type == DailyCareReportCenterTypeFilter.daycare,
            onTap: () => onType(DailyCareReportCenterTypeFilter.daycare),
          ),
        ],
      ),
    );
  }

  Widget _railTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? badge,
  }) {
    return ListTile(
      dense: true,
      selected: selected,
      title: Text(label),
      trailing: badge == null
          ? null
          : CircleAvatar(
              radius: 11,
              backgroundColor: selected
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFE5E7EB),
              child: Text(
                '$badge',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});

  final DailyCareReportCenterStatusFilter status;

  @override
  Widget build(BuildContext context) {
    final bool pending = status == DailyCareReportCenterStatusFilter.pending;
    final bool completed =
        status == DailyCareReportCenterStatusFilter.completed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              pending ? Icons.check_circle_outline : Icons.inbox_outlined,
              size: 48,
              color: pending
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              pending
                  ? '今天沒有待填的照護回報'
                  : completed
                  ? '今天尚無已完成回報'
                  : '今天沒有照護回報',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (pending) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                '可切換到「已完成」查看今天的回報',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.group,
    required this.setting,
    required this.compact,
  });

  final DailyCareReportCenterRoomGroup group;
  final DailyCareSettingModel setting;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final DailyCareReportCenterItem item = group.primary;
    final Color accent = group.hasPending
        ? const Color(0xFFE65100)
        : const Color(0xFF2E7D32);
    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 6, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.placeLabel,
                            style: TextStyle(
                              fontSize: compact ? 22 : 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _TypeTag(label: item.typeLabel),
                        const SizedBox(width: 6),
                        Text(
                          group.hasPending
                              ? '待填 ${group.pendingCount} 場'
                              : '已完成',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        _PetAvatar(photoUrl: item.petPhotoUrl),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.petNamesShort.isEmpty
                                ? '尚未指定寵物'
                                : item.petNamesShort,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (item.customerName.isNotEmpty ||
                        item.scheduleText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        <String>[
                          if (item.customerName.isNotEmpty) item.customerName,
                          if (item.scheduleText.isNotEmpty) item.scheduleText,
                        ].join('・'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    if (!compact) ...<Widget>[
                      if (item.bookingCode.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '訂單 ${item.bookingCode}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      if (item.roomTypeName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          '房型 ${item.roomTypeName}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      if (group.allCompleted &&
                          group.lastCompletedAt != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          '最後更新 ${_formatTime(group.lastCompletedAt!)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    if (compact)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final DailyCareReportCenterItem session
                              in group.sessions)
                            _SessionChip(
                              session: session,
                              onTap: () => _open(context, session),
                            ),
                        ],
                      )
                    else
                      Column(
                        children: <Widget>[
                          for (final DailyCareReportCenterItem session
                              in group.sessions)
                            _SessionRow(
                              session: session,
                              onTap: () => _open(context, session),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 48 : 44,
                      child: FilledButton(
                        onPressed: item.canOperate
                            ? () => _open(context, group.primaryActionSession)
                            : null,
                        child: Text(group.primaryActionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, DailyCareReportCenterItem session) {
    return DailyCareRecordEditLauncher.open(
      context: context,
      shopId: session.shopId,
      bookingId: session.bookingId,
      recordDate: session.recordDate,
      sessionIndex: session.sessionIndex,
      roomId: session.roomId,
      roomName: session.roomName,
      serviceType: session.serviceType,
      petIds: session.petIds,
      setting: setting,
    );
  }

  String _formatTime(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day} $h:$m';
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFFFE0B2),
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? const Icon(Icons.pets, color: Color(0xFFBF360C), size: 18)
          : null,
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.session, required this.onTap});

  final DailyCareReportCenterItem session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool done = session.isCompleted;
    return ActionChip(
      onPressed: session.canOperate ? onTap : null,
      avatar: Icon(
        done ? Icons.check_circle : Icons.error_outline,
        size: 16,
        color: done ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
      ),
      label: Text('${session.sessionName} ${done ? '已完成' : '待填'}'),
      backgroundColor: done ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final DailyCareReportCenterItem session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool done = session.isCompleted;
    return InkWell(
      onTap: session.canOperate ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: done ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.sessionName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              done ? '已完成' : '待填',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: done ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              ),
            ),
            if (done && session.updatedAt != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                _formatTime(session.updatedAt!),
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
