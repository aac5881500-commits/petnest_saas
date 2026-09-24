// 檔案名稱：lib/features/shop/widgets/daily_care_report_center_board.dart
// 功能說明：每日回報中心：分類、狀態、搜尋、依日期／訂單展開場次。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_report_center_date_group.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_session_status.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../room/daily_care_record_edit_launcher.dart';

class DailyCareReportCenterBoard extends StatefulWidget {
  const DailyCareReportCenterBoard({
    super.key,
    required this.snapshot,
    required this.setting,
    required this.status,
    required this.onStatus,
    required this.type,
    required this.onType,
    this.query = '',
    this.onQuery,
    this.focusBookingId = '',
    this.focusRecordDate,
    this.focusSessionIndex,
  });

  static const double phoneMax = 600;
  static const double desktopMin = 1024;

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final DailyCareReportCenterStatusFilter status;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;
  final String query;
  final ValueChanged<String>? onQuery;
  final String focusBookingId;
  final DateTime? focusRecordDate;
  final int? focusSessionIndex;

  @override
  State<DailyCareReportCenterBoard> createState() =>
      _DailyCareReportCenterBoardState();
}

class _DailyCareReportCenterBoardState
    extends State<DailyCareReportCenterBoard> {
  final Set<String> _expanded = <String>{};
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = widget.query;
    _expandFocus();
  }

  @override
  void didUpdateWidget(covariant DailyCareReportCenterBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusBookingId != widget.focusBookingId ||
        oldWidget.focusRecordDate != widget.focusRecordDate) {
      _expandFocus();
    }
    if (oldWidget.query != widget.query && _search.text != widget.query) {
      _search.text = widget.query;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _expandFocus() {
    final String bookingId = widget.focusBookingId.trim();
    if (bookingId.isEmpty) {
      return;
    }
    for (final DailyCareReportCenterItem item in widget.snapshot.items) {
      if (item.bookingId != bookingId) {
        continue;
      }
      if (widget.focusRecordDate != null &&
          DailyCareDateHelper.dateKey(item.recordDate) !=
              DailyCareDateHelper.dateKey(widget.focusRecordDate!)) {
        continue;
      }
      _expanded.add(
        '${DailyCareDateHelper.dateKey(item.recordDate)}#$bookingId',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final List<DailyCareReportCenterDateGroup> groups =
        DailyCareReportCenterDateGrouping.visible(
          items: widget.snapshot.items,
          status: widget.status,
          type: widget.type,
          query: widget.query,
        );
    if (width >= DailyCareReportCenterBoard.desktopMin) {
      return _DesktopBoard(
        snapshot: widget.snapshot,
        setting: widget.setting,
        groups: groups,
        status: widget.status,
        onStatus: widget.onStatus,
        type: widget.type,
        onType: widget.onType,
        search: _search,
        onQuery: widget.onQuery,
        expanded: _expanded,
        onToggle: _toggle,
        focusBookingId: widget.focusBookingId,
        focusSessionIndex: widget.focusSessionIndex,
      );
    }
    return _CompactBoard(
      snapshot: widget.snapshot,
      setting: widget.setting,
      groups: groups,
      status: widget.status,
      onStatus: widget.onStatus,
      type: widget.type,
      onType: widget.onType,
      search: _search,
      onQuery: widget.onQuery,
      expanded: _expanded,
      onToggle: _toggle,
      focusBookingId: widget.focusBookingId,
      focusSessionIndex: widget.focusSessionIndex,
      wide: width >= DailyCareReportCenterBoard.phoneMax,
    );
  }

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
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

class _CompactBoard extends StatelessWidget {
  const _CompactBoard({
    required this.snapshot,
    required this.setting,
    required this.groups,
    required this.status,
    required this.onStatus,
    required this.type,
    required this.onType,
    required this.search,
    required this.onQuery,
    required this.expanded,
    required this.onToggle,
    required this.focusBookingId,
    required this.focusSessionIndex,
    required this.wide,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final List<DailyCareReportCenterDateGroup> groups;
  final DailyCareReportCenterStatusFilter status;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;
  final TextEditingController search;
  final ValueChanged<String>? onQuery;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final String focusBookingId;
  final int? focusSessionIndex;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final double pad = wide ? 20 : 16;
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
          child: _SummaryCard(snapshot: snapshot),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
          child: _TypeTabs(snapshot: snapshot, type: type, onType: onType),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
          child: _StatusTabs(
            snapshot: snapshot,
            status: status,
            onStatus: onStatus,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
          child: _SearchField(controller: search, onQuery: onQuery),
        ),
        Expanded(
          child: groups.isEmpty
              ? _EmptyState(snapshot: snapshot, status: status)
              : _DateList(
                  groups: groups,
                  setting: setting,
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
                  expanded: expanded,
                  onToggle: onToggle,
                  focusBookingId: focusBookingId,
                  focusSessionIndex: focusSessionIndex,
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
    required this.onStatus,
    required this.type,
    required this.onType,
    required this.search,
    required this.onQuery,
    required this.expanded,
    required this.onToggle,
    required this.focusBookingId,
    required this.focusSessionIndex,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final List<DailyCareReportCenterDateGroup> groups;
  final DailyCareReportCenterStatusFilter status;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;
  final TextEditingController search;
  final ValueChanged<String>? onQuery;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final String focusBookingId;
  final int? focusSessionIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '每日回報中心',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _SummaryCard(snapshot: snapshot),
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
                    onStatus: onStatus,
                    type: type,
                    onType: onType,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _SearchField(controller: search, onQuery: onQuery),
                      const SizedBox(height: 12),
                      Expanded(
                        child: groups.isEmpty
                            ? _EmptyState(snapshot: snapshot, status: status)
                            : _DateList(
                                groups: groups,
                                setting: setting,
                                padding: const EdgeInsets.only(bottom: 8),
                                expanded: expanded,
                                onToggle: onToggle,
                                focusBookingId: focusBookingId,
                                focusSessionIndex: focusSessionIndex,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateList extends StatelessWidget {
  const _DateList({
    required this.groups,
    required this.setting,
    required this.padding,
    required this.expanded,
    required this.onToggle,
    required this.focusBookingId,
    required this.focusSessionIndex,
  });

  final List<DailyCareReportCenterDateGroup> groups;
  final DailyCareSettingModel setting;
  final EdgeInsets padding;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final String focusBookingId;
  final int? focusSessionIndex;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) {
        final DailyCareReportCenterDateGroup group = groups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final DailyCareReportCenterBookingDayGroup booking
                  in group.bookings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookingCard(
                    group: booking,
                    setting: setting,
                    expanded: expanded.contains(booking.expandKey),
                    onToggle: () => onToggle(booking.expandKey),
                    highlight:
                        booking.bookingId == focusBookingId.trim() &&
                        focusBookingId.trim().isNotEmpty,
                    focusSessionIndex: focusSessionIndex,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final DailyCareReportCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            _stat('待填', snapshot.pendingCount, const Color(0xFFE65100)),
            _stat('已完成', snapshot.completedCount, const Color(0xFF2E7D32)),
            _stat('總計', snapshot.totalCount, const Color(0xFF1565C0)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '$count 場',
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

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.snapshot,
    required this.type,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<DailyCareReportCenterTypeFilter>(
          showSelectedIcon: false,
          segments: <ButtonSegment<DailyCareReportCenterTypeFilter>>[
            ButtonSegment<DailyCareReportCenterTypeFilter>(
              value: DailyCareReportCenterTypeFilter.all,
              label: Text('全部 ${snapshot.totalCount}'),
            ),
            ButtonSegment<DailyCareReportCenterTypeFilter>(
              value: DailyCareReportCenterTypeFilter.stay,
              label: Text('住宿 ${snapshot.stayCount}'),
            ),
            ButtonSegment<DailyCareReportCenterTypeFilter>(
              value: DailyCareReportCenterTypeFilter.daycare,
              label: Text('安親 ${snapshot.daycareCount}'),
            ),
          ],
          selected: <DailyCareReportCenterTypeFilter>{type},
          onSelectionChanged: (Set<DailyCareReportCenterTypeFilter> value) {
            onType(value.first);
          },
        ),
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.snapshot,
    required this.status,
    required this.onStatus,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterStatusFilter status;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<DailyCareReportCenterStatusFilter>(
          showSelectedIcon: false,
          segments: <ButtonSegment<DailyCareReportCenterStatusFilter>>[
            ButtonSegment<DailyCareReportCenterStatusFilter>(
              value: DailyCareReportCenterStatusFilter.pending,
              label: Text('待填 ${snapshot.pendingCount}'),
            ),
            ButtonSegment<DailyCareReportCenterStatusFilter>(
              value: DailyCareReportCenterStatusFilter.completed,
              label: Text('已完成 ${snapshot.completedCount}'),
            ),
            ButtonSegment<DailyCareReportCenterStatusFilter>(
              value: DailyCareReportCenterStatusFilter.all,
              label: Text('全部 ${snapshot.totalCount}'),
            ),
          ],
          selected: <DailyCareReportCenterStatusFilter>{status},
          onSelectionChanged: (Set<DailyCareReportCenterStatusFilter> value) {
            onStatus(value.first);
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onQuery});

  final TextEditingController controller;
  final ValueChanged<String>? onQuery;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onQuery,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '搜尋訂單編號、房間、房型、寵物或飼主',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.snapshot,
    required this.status,
    required this.onStatus,
    required this.type,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterStatusFilter status;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final DailyCareReportCenterTypeFilter type;
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
            child: Text('分類', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          _tile(
            '全部',
            snapshot.totalCount,
            type == DailyCareReportCenterTypeFilter.all,
            () => onType(DailyCareReportCenterTypeFilter.all),
          ),
          _tile(
            '住宿',
            snapshot.stayCount,
            type == DailyCareReportCenterTypeFilter.stay,
            () => onType(DailyCareReportCenterTypeFilter.stay),
          ),
          _tile(
            '安親',
            snapshot.daycareCount,
            type == DailyCareReportCenterTypeFilter.daycare,
            () => onType(DailyCareReportCenterTypeFilter.daycare),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('狀態', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          _tile(
            '待填',
            snapshot.pendingCount,
            status == DailyCareReportCenterStatusFilter.pending,
            () => onStatus(DailyCareReportCenterStatusFilter.pending),
          ),
          _tile(
            '已完成',
            snapshot.completedCount,
            status == DailyCareReportCenterStatusFilter.completed,
            () => onStatus(DailyCareReportCenterStatusFilter.completed),
          ),
          _tile(
            '全部',
            snapshot.totalCount,
            status == DailyCareReportCenterStatusFilter.all,
            () => onStatus(DailyCareReportCenterStatusFilter.all),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, int badge, bool selected, VoidCallback onTap) {
    return ListTile(
      dense: true,
      selected: selected,
      title: Text(label),
      trailing: CircleAvatar(
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
  const _EmptyState({required this.snapshot, required this.status});

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterStatusFilter status;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (snapshot.totalCount == 0) {
      message = '目前沒有需處理的每日回報';
    } else if (status == DailyCareReportCenterStatusFilter.pending) {
      message = '目前沒有待填的每日回報';
    } else if (status == DailyCareReportCenterStatusFilter.completed) {
      message = '目前沒有已完成的每日回報';
    } else {
      message = '目前沒有符合條件的每日回報';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.group,
    required this.setting,
    required this.expanded,
    required this.onToggle,
    required this.highlight,
    required this.focusSessionIndex,
  });

  final DailyCareReportCenterBookingDayGroup group;
  final DailyCareSettingModel setting;
  final bool expanded;
  final VoidCallback onToggle;
  final bool highlight;
  final int? focusSessionIndex;

  @override
  Widget build(BuildContext context) {
    final DailyCareReportCenterItem item = group.primary;
    final Color accent = group.hasPending
        ? const Color(0xFFE65100)
        : const Color(0xFF2E7D32);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: highlight ? const Color(0xFFF3F8FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlight ? const Color(0xFF90CAF9) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            _MiniChip(
                              label: item.typeLabel,
                              color: const Color(0xFF3949AB),
                            ),
                            _MiniChip(
                              label: item.reportsLocked
                                  ? (group.hasPending ? '未完成・已鎖定' : '已完成・唯讀')
                                  : (group.hasPending
                                        ? '未完成 ${group.pendingCount} 場'
                                        : '已完成'),
                              color: item.reportsLocked
                                  ? const Color(0xFF616161)
                                  : accent,
                            ),
                            Text(
                              item.bookingCode.isEmpty
                                  ? item.bookingId
                                  : item.bookingCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          <String>[
                            item.placeLabel,
                            if (item.customerName.isNotEmpty) item.customerName,
                            if (item.petNamesShort.isNotEmpty)
                              item.petNamesShort,
                          ].join('・'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${group.completedCount}/${group.totalCount} 場',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Column(
                children: <Widget>[
                  for (final DailyCareReportCenterItem session
                      in group.sessions)
                    _SessionRow(
                      session: session,
                      setting: setting,
                      highlight:
                          highlight &&
                          focusSessionIndex != null &&
                          session.sessionIndex == focusSessionIndex,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.setting,
    required this.highlight,
  });

  final DailyCareReportCenterItem session;
  final DailyCareSettingModel setting;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bool done = session.isCompleted;
    final bool locked = session.reportsLocked;
    final String status = DailyCareSessionStatus.sessionLine(
      completed: done,
      photoCount: session.photoCount,
      locked: locked,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFE3F2FD) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            locked
                ? Icons.lock_outline
                : (done ? Icons.check_circle : Icons.radio_button_unchecked),
            size: 16,
            color: locked
                ? const Color(0xFF757575)
                : (done ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${session.sessionName}　$status',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (locked)
            TextButton(
              onPressed: done
                  ? () => DailyCareRecordEditLauncher.open(
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
                      entitlement: session.entitlement,
                      readOnly: true,
                    )
                  : null,
              child: Text(done ? '查看' : '已鎖定'),
            )
          else
            TextButton(
              onPressed: session.canOperate
                  ? () => DailyCareRecordEditLauncher.open(
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
                      entitlement: session.entitlement,
                    )
                  : null,
              child: Text(done ? '查看／編輯' : '填寫'),
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
