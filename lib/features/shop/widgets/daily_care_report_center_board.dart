// 檔案名稱：lib/features/shop/widgets/daily_care_report_center_board.dart
// 功能說明：每日回報中心：分類、狀態、搜尋、依日期／訂單展開場次。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_report_center_date_group.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_report_data.dart';
import '../../../core/models/daily_care_report_mode.dart';
import '../../../core/models/daily_care_session_status.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/daily_care_stay_info.dart';
import '../../../core/services/daily_care_photo_service.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/services/daily_care_report_export_service.dart';
import '../../room/daily_care_record_edit_launcher.dart';
import '../../room/widgets/daily_care_record_editor.dart';

/// 歷史未完成專用色：中性灰紅，不能和橘色「待填」混用。
const Color historyIncompleteColor = Color(0xFF8D6E63);

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
    this.embedded = false,
  });

  static const double phoneMax = 600;
  static const double desktopMin = 1024;

  /// 桌機全畫面：左側工作清單＋右側快速處理面板。
  static const double masterDetailMin = 1280;

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
  final bool embedded;

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
        oldWidget.focusRecordDate != widget.focusRecordDate ||
        oldWidget.embedded != widget.embedded) {
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
      if (!widget.embedded &&
          widget.focusRecordDate != null &&
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
    if (widget.embedded) {
      return _EmbeddedBoard(
        snapshot: widget.snapshot,
        setting: widget.setting,
        bookingId: widget.focusBookingId.trim(),
        focusSessionIndex: widget.focusSessionIndex,
      );
    }
    final double width = MediaQuery.sizeOf(context).width;
    final List<DailyCareReportCenterDateGroup> groups =
        DailyCareReportCenterDateGrouping.visible(
          items: widget.snapshot.items,
          status: widget.status,
          type: widget.type,
          query: widget.query,
        );
    if (width >= DailyCareReportCenterBoard.masterDetailMin) {
      return _MasterDetailBoard(
        snapshot: widget.snapshot,
        setting: widget.setting,
        groups: groups,
        status: widget.status,
        onStatus: widget.onStatus,
        type: widget.type,
        onType: widget.onType,
        search: _search,
        onQuery: widget.onQuery,
        focusBookingId: widget.focusBookingId,
        focusRecordDate: widget.focusRecordDate,
        focusSessionIndex: widget.focusSessionIndex,
      );
    }
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

class _EmbeddedBoard extends StatelessWidget {
  const _EmbeddedBoard({
    required this.snapshot,
    required this.setting,
    required this.bookingId,
    required this.focusSessionIndex,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final String bookingId;
  final int? focusSessionIndex;

  @override
  Widget build(BuildContext context) {
    if (bookingId.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<DailyCareReportCenterItem> sessions =
        snapshot.items
            .where(
              (DailyCareReportCenterItem item) => item.bookingId == bookingId,
            )
            .toList()
          ..sort((DailyCareReportCenterItem a, DailyCareReportCenterItem b) {
            final int date = a.recordDate.compareTo(b.recordDate);
            if (date != 0) {
              return date;
            }
            return a.sessionIndex.compareTo(b.sessionIndex);
          });
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '這筆訂單目前沒有每日回報場次',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    final DailyCareReportCenterItem primary = sessions.first;
    final int pending = sessions
        .where((DailyCareReportCenterItem item) => !item.isCompleted)
        .length;
    final int completed = sessions.length - pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              _MiniChip(
                label: primary.typeLabel,
                color: const Color(0xFF3949AB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  <String>[
                    primary.placeLabel,
                    if (primary.customerName.isNotEmpty) primary.customerName,
                    if (primary.petNamesShort.isNotEmpty) primary.petNamesShort,
                  ].join('・'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '已完成 $completed/${sessions.length} 場',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (pending > 0) ...<Widget>[
                const SizedBox(width: 8),
                _MiniChip(
                  label: '待填 $pending 場',
                  color: const Color(0xFFE65100),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            itemCount: sessions.length,
            itemBuilder: (BuildContext context, int index) {
              final DailyCareReportCenterItem session = sessions[index];
              return _SessionRow(
                session: session,
                setting: setting,
                highlight:
                    focusSessionIndex != null &&
                    session.sessionIndex == focusSessionIndex,
                showDate: true,
                compact: true,
              );
            },
          ),
        ),
      ],
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
                  compactSessions: true,
                  sessionCards: true,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryCard(snapshot: snapshot),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 200,
                  child: _FilterRail(
                    snapshot: snapshot,
                    status: status,
                    onStatus: onStatus,
                    type: type,
                    onType: onType,
                  ),
                ),
                const SizedBox(width: 16),
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
                                compactSessions: true,
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
    required this.compactSessions,
    this.sessionCards = false,
  });

  final List<DailyCareReportCenterDateGroup> groups;
  final DailyCareSettingModel setting;
  final EdgeInsets padding;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final String focusBookingId;
  final int? focusSessionIndex;
  final bool compactSessions;
  final bool sessionCards;

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
                    compactSessions: compactSessions,
                    sessionCards: sessionCards,
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
  const _SummaryCard({
    required this.snapshot,
    this.showHistoryIncomplete = false,
  });

  final DailyCareReportCenterSnapshot snapshot;

  /// 桌機才加上「歷史未完成」，手機版統計維持原本三項。
  final bool showHistoryIncomplete;

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
            if (showHistoryIncomplete)
              _stat(
                '歷史未完成',
                snapshot.historyIncompleteCount,
                historyIncompleteColor,
              ),
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
    this.shrink = false,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareReportCenterStatusFilter status;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  /// 高度只隨內容，不把面板撐到整頁底部。
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('分類', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      _typeTiles(),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('狀態', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      _statusTiles(),
    ];
    return Card(
      elevation: 0,
      color: Colors.white,
      child: shrink
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: children,
            ),
    );
  }

  Widget _typeTiles() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
      ],
    );
  }

  Widget _statusTiles() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _tile(
          '待填',
          snapshot.pendingCount,
          status == DailyCareReportCenterStatusFilter.pending,
          () => onStatus(DailyCareReportCenterStatusFilter.pending),
        ),
        _tile(
          '歷史未完成',
          snapshot.historyIncompleteCount,
          status == DailyCareReportCenterStatusFilter.historyIncomplete,
          () => onStatus(DailyCareReportCenterStatusFilter.historyIncomplete),
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
    } else if (status == DailyCareReportCenterStatusFilter.historyIncomplete) {
      message = '目前沒有歷史未完成的每日回報';
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
    required this.compactSessions,
    this.sessionCards = false,
  });

  final DailyCareReportCenterBookingDayGroup group;
  final DailyCareSettingModel setting;
  final bool expanded;
  final VoidCallback onToggle;
  final bool highlight;
  final int? focusSessionIndex;
  final bool compactSessions;
  final bool sessionCards;

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
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                            Text(
                              item.bookingCode.isEmpty
                                  ? item.bookingId
                                  : item.bookingCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            if (item.reportsLocked)
                              const Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: Color(0xFF616161),
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
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: <Widget>[
                            Text(
                              '${group.completedCount} / ${group.totalCount} 場',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            if (group.hasPending)
                              _MiniChip(
                                label: '待填 ${group.pendingCount} 場',
                                color: const Color(0xFFE65100),
                              ),
                          ],
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
              child: sessionCards
                  ? _SessionMiniCards(
                      sessions: group.sessions,
                      setting: setting,
                      highlight: highlight,
                      focusSessionIndex: focusSessionIndex,
                    )
                  : Column(
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
                            showDate: false,
                            compact: compactSessions,
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
    required this.showDate,
    required this.compact,
  });

  final DailyCareReportCenterItem session;
  final DailyCareSettingModel setting;
  final bool highlight;
  final bool showDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool done = session.isCompleted;
    final bool locked = session.reportsLocked;
    final Color statusColor = done
        ? const Color(0xFF2E7D32)
        : (locked ? historyIncompleteColor : const Color(0xFFE65100));
    final String statusLabel = session.statusLabel;
    final String photo = DailyCareSessionStatus.photoLabel(session.photoCount);
    final String actionLabel;
    if (locked) {
      actionLabel = done ? '唯讀查看' : '已鎖定';
    } else {
      actionLabel = done ? '查看／編輯' : '填寫';
    }
    final bool actionEnabled = locked ? done : session.canOperate;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      constraints: BoxConstraints(minHeight: compact ? 44 : 40),
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
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  session.sessionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (showDate)
                  Text(
                    DailyCareReportCenterItem.dateHeadingOf(session.recordDate),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
          _MiniChip(label: statusLabel, color: statusColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              done ? '已完成・$photo' : photo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: actionEnabled
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
                    readOnly: locked,
                  )
                : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 40),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// 窄版展開後的場次小卡。寬度夠時兩欄，極窄才改單欄。
class _SessionMiniCards extends StatelessWidget {
  const _SessionMiniCards({
    required this.sessions,
    required this.setting,
    required this.highlight,
    required this.focusSessionIndex,
  });

  static const double twoColumnMin = 280;
  static const double gap = 8;

  final List<DailyCareReportCenterItem> sessions;
  final DailyCareSettingModel setting;
  final bool highlight;
  final int? focusSessionIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final bool twoColumns = maxWidth >= twoColumnMin;
        final double cardWidth = twoColumns ? (maxWidth - gap) / 2 : maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final DailyCareReportCenterItem session in sessions)
              SizedBox(
                width: cardWidth,
                child: _SessionMiniCard(
                  session: session,
                  setting: setting,
                  highlight:
                      highlight &&
                      focusSessionIndex != null &&
                      session.sessionIndex == focusSessionIndex,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SessionMiniCard extends StatelessWidget {
  const _SessionMiniCard({
    required this.session,
    required this.setting,
    required this.highlight,
  });

  final DailyCareReportCenterItem session;
  final DailyCareSettingModel setting;
  final bool highlight;

  int get _photoQuota {
    final int entitled = session.entitlement.photosPerSession;
    if (entitled > 0) {
      return entitled;
    }
    return DailyCareReportMode.photosPerSession;
  }

  String get _statusText {
    return switch (session.status) {
      DailyCareReportCenterItemStatus.pending => '待填',
      DailyCareReportCenterItemStatus.completed => '已完成',
      DailyCareReportCenterItemStatus.historyIncomplete => '已鎖定',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool done = session.isCompleted;
    final bool locked = session.reportsLocked;
    final Color statusColor = done
        ? const Color(0xFF2E7D32)
        : (locked ? historyIncompleteColor : const Color(0xFFE65100));
    final bool actionEnabled = locked ? done : session.canOperate;
    final IconData actionIcon = !actionEnabled
        ? Icons.lock_outline
        : (done ? Icons.chevron_right : Icons.edit_outlined);
    return Material(
      color: highlight ? const Color(0xFFE3F2FD) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey<String>(
          'daily-care-session-${session.bookingId}-${session.sessionIndex}',
        ),
        borderRadius: BorderRadius.circular(10),
        onTap: actionEnabled
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
                readOnly: locked,
              )
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          session.sessionName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '已上傳 ${session.photoCount}/$_photoQuota',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(actionIcon, size: 18, color: statusColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// 桌機 >= 1280：左側篩選＋中間工作清單＋右側快速處理面板。
class _MasterDetailBoard extends StatefulWidget {
  const _MasterDetailBoard({
    required this.snapshot,
    required this.setting,
    required this.groups,
    required this.status,
    required this.onStatus,
    required this.type,
    required this.onType,
    required this.search,
    required this.onQuery,
    required this.focusBookingId,
    required this.focusRecordDate,
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
  final String focusBookingId;
  final DateTime? focusRecordDate;
  final int? focusSessionIndex;

  @override
  State<_MasterDetailBoard> createState() => _MasterDetailBoardState();
}

class _MasterDetailBoardState extends State<_MasterDetailBoard> {
  String _selectedKey = '';
  int? _selectedSession;
  bool _preview = false;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    final String bookingId = widget.focusBookingId.trim();
    final DateTime? date = widget.focusRecordDate;
    if (bookingId.isNotEmpty && date != null) {
      _selectedKey = '${DailyCareDateHelper.dateKey(date)}#$bookingId';
      _selectedSession = widget.focusSessionIndex;
    }
  }

  void _select(DailyCareReportCenterBookingDayGroup group) {
    setState(() {
      _selectedKey = group.expandKey;
      _selectedSession = null;
      _preview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<DailyCareReportCenterBookingDayGroup> rows =
        <DailyCareReportCenterBookingDayGroup>[
          for (final DailyCareReportCenterDateGroup group in widget.groups)
            ...group.bookings,
        ];

    // 選取結果只存在前端；清單變動時自動改選第一筆待填。
    DailyCareReportCenterBookingDayGroup? selected;
    for (final DailyCareReportCenterBookingDayGroup row in rows) {
      if (row.expandKey == _selectedKey) {
        selected = row;
        break;
      }
    }
    if (selected == null && rows.isNotEmpty) {
      for (final DailyCareReportCenterBookingDayGroup row in rows) {
        if (row.hasPending) {
          selected = row;
          break;
        }
      }
      selected ??= rows.first;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: <Widget>[
          _SummaryCard(snapshot: widget.snapshot, showHistoryIncomplete: true),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 200,
                  child: SingleChildScrollView(
                    child: _FilterRail(
                      snapshot: widget.snapshot,
                      status: widget.status,
                      onStatus: widget.onStatus,
                      type: widget.type,
                      onType: widget.onType,
                      shrink: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 410,
                  child: Column(
                    children: <Widget>[
                      _SearchField(
                        controller: widget.search,
                        onQuery: widget.onQuery,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: rows.isEmpty
                            ? _EmptyState(
                                snapshot: widget.snapshot,
                                status: widget.status,
                              )
                            : ListView(
                                padding: const EdgeInsets.only(bottom: 24),
                                children: <Widget>[
                                  for (final DailyCareReportCenterDateGroup
                                      group
                                      in widget.groups) ...<Widget>[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        2,
                                        4,
                                        2,
                                        8,
                                      ),
                                      child: Text(
                                        group.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    for (final DailyCareReportCenterBookingDayGroup
                                        booking
                                        in group.bookings)
                                      _MasterListCard(
                                        group: booking,
                                        selected:
                                            selected != null &&
                                            booking.expandKey ==
                                                selected.expandKey,
                                        onTap: () => _select(booking),
                                      ),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: selected == null
                      ? const _QuickPanelPlaceholder()
                      : _buildQuickPanel(selected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPanel(DailyCareReportCenterBookingDayGroup group) {
    final List<DailyCareReportCenterItem> sessions = group.sessions;
    final bool sameSelection = group.expandKey == _selectedKey;
    DailyCareReportCenterItem? session;
    if (sameSelection && _selectedSession != null) {
      for (final DailyCareReportCenterItem item in sessions) {
        if (item.sessionIndex == _selectedSession) {
          session = item;
          break;
        }
      }
    }
    if (session == null) {
      for (final DailyCareReportCenterItem item in sessions) {
        if (item.isPendingFill) {
          session = item;
          break;
        }
      }
      session ??= sessions.first;
    }

    return _QuickPanel(
      key: ValueKey<String>('${group.expandKey}#${session.sessionIndex}'),
      group: group,
      session: session,
      setting: widget.setting,
      preview: sameSelection ? _preview : false,
      refreshToken: _refreshToken,
      onSession: (int index) {
        setState(() {
          _selectedKey = group.expandKey;
          _selectedSession = index;
        });
      },
      onTab: (bool preview) {
        setState(() {
          _selectedKey = group.expandKey;
          _preview = preview;
        });
      },
      onSaved: () {
        setState(() {
          _refreshToken++;
          _selectedKey = group.expandKey;
          _preview = true;
        });
      },
    );
  }
}

class _QuickPanelPlaceholder extends StatelessWidget {
  const _QuickPanelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '請從左側工作清單選擇一筆訂單',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// 中間工作清單的精簡卡片，只負責切換右側面板。
class _MasterListCard extends StatelessWidget {
  const _MasterListCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final DailyCareReportCenterBookingDayGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DailyCareReportCenterItem item = group.primary;
    final Color statusColor = switch (group.status) {
      DailyCareReportCenterItemStatus.pending => const Color(0xFFE65100),
      DailyCareReportCenterItemStatus.historyIncomplete =>
        historyIncompleteColor,
      DailyCareReportCenterItemStatus.completed => const Color(0xFF2E7D32),
    };
    final String statusLabel = switch (group.status) {
      DailyCareReportCenterItemStatus.pending => '待填 ${group.pendingCount} 場',
      DailyCareReportCenterItemStatus.historyIncomplete => '歷史未完成・已鎖定',
      DailyCareReportCenterItemStatus.completed => '已完成',
    };
    final bool expiringSoon = group.sessions.any(
      (DailyCareReportCenterItem session) => session.photoExpiringSoon(),
    );
    final String photoLabel = group.photoCount <= 0
        ? '尚未上傳照片'
        : (expiringSoon
              ? '照片 ${group.photoCount} 張・即將清除'
              : '照片 ${group.photoCount} 張');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFEFF5FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFF64A0F0)
                    : const Color(0xFFE5E7EB),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _MiniChip(
                      label: item.typeLabel,
                      color: const Color(0xFF3949AB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.bookingCode.isEmpty
                            ? item.bookingId
                            : item.bookingCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[
                    item.placeLabel,
                    if (item.customerName.isNotEmpty) item.customerName,
                    if (item.petNamesShort.isNotEmpty) item.petNamesShort,
                  ].join('・'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (item.scheduleText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    item.scheduleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      group.progressLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      group.missingLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: group.hasPending
                            ? const Color(0xFFE65100)
                            : Colors.black54,
                      ),
                    ),
                    Text(
                      photoLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: expiringSoon
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: expiringSoon
                            ? const Color(0xFFE65100)
                            : Colors.black54,
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

/// 右側夠寬才並排。以右側容器的實際寬度判斷，約對應整頁 1720px。
class _QuickSplitLayout {
  const _QuickSplitLayout._();

  static const double minPanelWidth = 980;
  static const double gap = 16;
  static const double formMinWidth = 500;
  static const double formMaxWidth = 560;
  static const double previewMinWidth = 400;

  static bool enabled(double panelWidth) => panelWidth >= minPanelWidth;

  /// 表單優先維持可操作寬度，最多 560，其餘留給預覽。
  static double formWidthFor(double panelWidth) {
    final double room = panelWidth - gap - previewMinWidth;
    if (room <= formMinWidth) {
      return formMinWidth;
    }
    if (room >= formMaxWidth) {
      return formMaxWidth;
    }
    return room;
  }
}

/// 右側快速處理面板：場次切換＋快速填寫／回報預覽。
class _QuickPanel extends StatelessWidget {
  const _QuickPanel({
    super.key,
    required this.group,
    required this.session,
    required this.setting,
    required this.preview,
    required this.refreshToken,
    required this.onSession,
    required this.onTab,
    required this.onSaved,
  });

  final DailyCareReportCenterBookingDayGroup group;
  final DailyCareReportCenterItem session;
  final DailyCareSettingModel setting;
  final bool preview;
  final int refreshToken;
  final ValueChanged<int> onSession;
  final ValueChanged<bool> onTab;
  final VoidCallback onSaved;

  String _sessionLabel(DailyCareReportCenterItem item) {
    final String fromEntitlement = item.entitlement
        .sessionLabelAt(item.sessionIndex)
        .trim();
    if (fromEntitlement.isNotEmpty) {
      return fromEntitlement;
    }
    if (item.sessionName.trim().isNotEmpty) {
      return item.sessionName.trim();
    }
    return item.isDaycare
        ? setting.daycareSessionLabelAt(item.sessionIndex)
        : setting.sessionLabelAt(item.sessionIndex);
  }

  @override
  Widget build(BuildContext context) {
    final DailyCareReportCenterItem head = group.primary;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _MiniChip(
                      label: head.typeLabel,
                      color: const Color(0xFF3949AB),
                    ),
                    Text(
                      head.bookingCode.isEmpty
                          ? head.bookingId
                          : head.bookingCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      head.recordDateHeading,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    if (head.reportsLocked)
                      const Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: Color(0xFF616161),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  <String>[
                    head.placeLabel,
                    if (head.customerName.isNotEmpty) head.customerName,
                    if (head.petNamesText.isNotEmpty) head.petNamesText,
                  ].join('・'),
                  style: const TextStyle(fontSize: 13.5),
                ),
                if (head.scheduleText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    head.scheduleText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${group.progressLabel}・${group.missingLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                for (final DailyCareReportCenterItem item in group.sessions)
                  ChoiceChip(
                    label: Text('第 ${item.sessionIndex + 1} 場'),
                    tooltip: _sessionLabel(item),
                    selected: item.sessionIndex == session.sessionIndex,
                    avatar: Icon(
                      item.isCompleted
                          ? Icons.check_circle
                          : (item.isHistoryIncomplete
                                ? Icons.lock_outline
                                : Icons.edit_note),
                      size: 16,
                      color: item.isCompleted
                          ? const Color(0xFF2E7D32)
                          : (item.isHistoryIncomplete
                                ? historyIncompleteColor
                                : const Color(0xFFE65100)),
                    ),
                    onSelected: (_) => onSession(item.sessionIndex),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (_QuickSplitLayout.enabled(constraints.maxWidth)) {
                  return _buildSplit(context, constraints.maxWidth);
                }
                return _buildPaged(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaged(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('快速填寫'),
                selected: !preview,
                onSelected: (_) => onTab(false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('回報預覽'),
                selected: preview,
                onSelected: (_) => onTab(true),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: preview
              ? _QuickPreview(
                  session: session,
                  setting: setting,
                  refreshToken: refreshToken,
                )
              : _buildEditor(context, embedPreview: true),
        ),
      ],
    );
  }

  Widget _buildSplit(BuildContext context, double panelWidth) {
    final double formWidth = _QuickSplitLayout.formWidthFor(panelWidth);
    return Row(
      key: const ValueKey<String>('daily-care-quick-split'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          key: const ValueKey<String>('daily-care-quick-form'),
          width: formWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _QuickColumnTitle('快速填寫'),
              const Divider(height: 1),
              Expanded(child: _buildEditor(context, embedPreview: false)),
            ],
          ),
        ),
        const VerticalDivider(
          width: 16,
          thickness: 1,
          color: Color(0xFFE5E7EB),
        ),
        Expanded(
          child: Column(
            key: const ValueKey<String>('daily-care-quick-preview'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _QuickColumnTitle('回報預覽'),
              const Divider(height: 1),
              Expanded(
                child: _QuickPreview(
                  key: ValueKey<String>(
                    'daily-care-quick-preview-${session.id}',
                  ),
                  session: session,
                  setting: setting,
                  refreshToken: refreshToken,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context, {required bool embedPreview}) {
    if (session.isHistoryIncomplete) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: historyIncompleteColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '此場未完成，訂單已結束，無法再補填',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (embedPreview) ...<Widget>[
            const SizedBox(height: 12),
            _QuickPreview(
              session: session,
              setting: setting,
              refreshToken: refreshToken,
              embedded: true,
            ),
          ],
        ],
      );
    }
    return DailyCareRecordEditor(
      key: ValueKey<String>('${session.id}#$refreshToken'),
      shopId: session.shopId,
      bookingId: session.bookingId,
      roomId: session.roomId,
      roomName: session.roomName,
      recordDate: session.recordDate,
      sessionIndex: session.sessionIndex,
      sessionName: _sessionLabel(session),
      customFields: setting.customFields,
      enabledFields: setting.enabledFields,
      photoEnabled: setting.photoEnabled,
      serviceType: session.serviceType,
      petIds: session.petIds,
      entitlement: session.entitlement,
      readOnly: session.reportsLocked || !session.canOperate,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      showHeaderCard: false,
      onSaved: onSaved,
    );
  }
}

class _QuickColumnTitle extends StatelessWidget {
  const _QuickColumnTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 照片保存期限提示文字。
class DailyCarePhotoNotice {
  const DailyCarePhotoNotice({required this.text, required this.warn});

  final String text;
  final bool warn;
}

String _taipeiText(DateTime value) {
  final DateTime t = value.toUtc().add(const Duration(hours: 8));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

DateTime? _earliestExpiry(List<DailyCarePhotoModel> photos) {
  DateTime? earliest;
  for (final DailyCarePhotoModel photo in photos) {
    final DateTime? value = photo.expiresAt;
    if (value == null) {
      continue;
    }
    if (earliest == null || value.isBefore(earliest)) {
      earliest = value;
    }
  }
  return earliest;
}

/// 只顯示既有 expiresAt 與 24 小時規則，不自行推算刪除時間。
DailyCarePhotoNotice buildPhotoNotice({
  required DailyCareReportCenterItem item,
  required List<DailyCarePhotoModel> photos,
  DateTime? now,
}) {
  final DateTime current = now ?? DateTime.now();
  const DailyCarePhotoNotice ended = DailyCarePhotoNotice(
    text: '照護照片保存期限已結束（文字照護紀錄仍會保留）。',
    warn: false,
  );
  final DateTime? expiresAt = _earliestExpiry(photos);
  if (expiresAt != null) {
    if (!expiresAt.isAfter(current)) {
      return ended;
    }
    final bool soon =
        expiresAt.difference(current) <= const Duration(hours: 24);
    return DailyCarePhotoNotice(
      text:
          '照片保存至 ${_taipeiText(expiresAt)}（台灣時間）\n'
          '到期後將由系統排程永久清除照片檔案，且無法復原。',
      warn: soon,
    );
  }
  final DateTime? deadline = item.photoRetentionDeadline;
  final bool past = deadline != null && !deadline.isAfter(current);
  if (photos.isEmpty && (past || item.reportsLocked)) {
    return ended;
  }
  return const DailyCarePhotoNotice(
    text: '照片將於服務結束後保留 24 小時，期限前請下載保存。',
    warn: false,
  );
}

/// 分享圖底部小字，只在接近保存期限時出現。
String buildPhotoExpiryFootnote({DateTime? expiresAt, DateTime? now}) {
  if (expiresAt == null) {
    return '';
  }
  final DateTime current = now ?? DateTime.now();
  if (!expiresAt.isAfter(current)) {
    return '';
  }
  if (expiresAt.difference(current) > const Duration(hours: 24)) {
    return '';
  }
  return '照護照片保存至 ${_taipeiText(expiresAt)}，請於期限前保存';
}

class _PreviewBundle {
  const _PreviewBundle({
    required this.booking,
    required this.shop,
    required this.stay,
    required this.records,
    required this.data,
  });

  final Map<String, dynamic> booking;
  final Map<String, dynamic> shop;
  final DailyCareStayInfo stay;
  final List<DailyCareRecordModel> records;
  final DailyCareReportData data;
}

/// 回報預覽：顧客看得到的內容、照片縮圖與分享圖入口。
class _QuickPreview extends StatefulWidget {
  const _QuickPreview({
    super.key,
    required this.session,
    required this.setting,
    required this.refreshToken,
    this.embedded = false,
  });

  final DailyCareReportCenterItem session;
  final DailyCareSettingModel setting;
  final int refreshToken;

  /// 放在其他捲動容器內時不再自己捲動。
  final bool embedded;

  @override
  State<_QuickPreview> createState() => _QuickPreviewState();
}

class _QuickPreviewState extends State<_QuickPreview> {
  Future<_PreviewBundle>? _future;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _QuickPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.refreshToken != widget.refreshToken) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<_PreviewBundle> _load() async {
    final DailyCareReportCenterItem item = widget.session;
    final String collection = item.sourceCollection.trim().isEmpty
        ? 'bookings'
        : item.sourceCollection.trim();
    final DocumentSnapshot<Map<String, dynamic>> bookingSnap =
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(item.bookingId)
            .get();
    final DocumentSnapshot<Map<String, dynamic>> shopSnap =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(item.shopId)
            .get();
    final Map<String, dynamic> booking =
        bookingSnap.data() ?? <String, dynamic>{};
    final Map<String, dynamic> shop = shopSnap.data() ?? <String, dynamic>{};
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(
      booking,
      fallbackRoomName: item.roomName,
      shopLogoUrl: (shop['logoUrl'] ?? '').toString().trim(),
    );
    final int sessionCount = item.entitlement.finalReports > 0
        ? item.entitlement.finalReports
        : widget.setting.sessionCount;
    final List<DailyCareRecordModel> records = await DailyCareRecordService
        .instance
        .streamBookingRecords(
          bookingId: item.bookingId,
          shopId: item.shopId,
          sessionCount: sessionCount < 1 ? 1 : sessionCount,
        )
        .first;
    final DailyCareReportData data = DailyCareReportExportService.instance
        .buildReport(
          booking: booking,
          shop: shop,
          stay: stay,
          setting: widget.setting,
          records: records,
          kind: DailyCareReportExportKind.fullStay,
        );
    return _PreviewBundle(
      booking: booking,
      shop: shop,
      stay: stay,
      records: records,
      data: data,
    );
  }

  Stream<List<DailyCarePhotoModel>> _photoStream() {
    final DailyCareReportCenterItem item = widget.session;
    try {
      return DailyCarePhotoService.instance.streamRecordPhotos(
        bookingId: item.bookingId,
        dailyCareRecordId: DailyCareRecordService.instance.buildRecordId(
          bookingId: item.bookingId,
          recordDate: item.recordDate,
          sessionIndex: item.sessionIndex,
        ),
        recordDate: item.recordDate,
        sessionIndex: item.sessionIndex,
        roomId: item.isDaycare ? '' : item.roomId,
        shopId: item.shopId,
      );
    } catch (_) {
      return Stream<List<DailyCarePhotoModel>>.value(
        const <DailyCarePhotoModel>[],
      );
    }
  }

  DailyCareReportSession? _sessionOf(_PreviewBundle bundle) {
    final String dateKey = DailyCareDateHelper.dateKey(
      widget.session.recordDate,
    );
    for (final DailyCareReportDay day in bundle.data.days) {
      if (day.dateKey != dateKey) {
        continue;
      }
      for (final DailyCareReportSession session in day.sessions) {
        if (session.sessionName.trim() == widget.session.sessionName.trim()) {
          return session;
        }
      }
      if (widget.session.sessionIndex < day.sessions.length) {
        return day.sessions[widget.session.sessionIndex];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailyCarePhotoModel>>(
      stream: _photoStream(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DailyCarePhotoModel>> photoSnapshot,
          ) {
            final List<DailyCarePhotoModel> photos =
                photoSnapshot.data ?? const <DailyCarePhotoModel>[];
            return FutureBuilder<_PreviewBundle>(
              future: _future,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<_PreviewBundle> snapshot,
                  ) {
                    final List<Widget> children = _buildBody(
                      context,
                      snapshot,
                      photos,
                    );
                    if (widget.embedded) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: children,
                    );
                  },
            );
          },
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    AsyncSnapshot<_PreviewBundle> snapshot,
    List<DailyCarePhotoModel> photos,
  ) {
    final DailyCareReportCenterItem item = widget.session;
    final DailyCarePhotoNotice notice = buildPhotoNotice(
      item: item,
      photos: photos,
    );
    final List<Widget> children = <Widget>[];

    if (item.isHistoryIncomplete && !widget.embedded) {
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: historyIncompleteColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '此場未完成，訂單已結束，無法再補填',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
      return children;
    }

    final _PreviewBundle? bundle = snapshot.data;
    if (snapshot.hasError || bundle == null) {
      children.add(
        const Text('讀取回報內容失敗，請稍後再試。', style: TextStyle(color: Colors.black54)),
      );
      return children;
    }

    final DailyCareReportSession? session = _sessionOf(bundle);
    children.add(
      Text(
        '顧客看到的內容',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: bundle.data.brandColor,
        ),
      ),
    );
    children.add(const SizedBox(height: 8));

    if (session == null) {
      children.add(
        Text(
          item.isHistoryIncomplete ? '這場沒有留下照護內容。' : '這場還沒有填寫內容。',
          style: const TextStyle(color: Colors.black54),
        ),
      );
    } else {
      for (final DailyCareReportGroup group in session.groups) {
        if (group.fields.isEmpty) {
          continue;
        }
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              group.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              for (final DailyCareReportField field in group.fields)
                _MiniChip(
                  label: '${field.label}：${field.value}',
                  color: const Color(0xFF455A64),
                ),
            ],
          ),
        );
      }
      if (session.generalNote.trim().isNotEmpty) {
        children.add(const SizedBox(height: 10));
        children.add(
          const Text('今日概況', style: TextStyle(fontWeight: FontWeight.w800)),
        );
        children.add(const SizedBox(height: 4));
        children.add(Text(session.generalNote.trim()));
      }
      if (session.updatedAtText.trim().isNotEmpty) {
        children.add(const SizedBox(height: 8));
        children.add(
          Text(
            '更新時間：${session.updatedAtText}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        );
      }
    }

    children.add(const SizedBox(height: 14));
    children.add(
      const Text('本場照片', style: TextStyle(fontWeight: FontWeight.w800)),
    );
    children.add(const SizedBox(height: 6));
    if (photos.isEmpty) {
      children.add(
        const Text('尚未上傳照片', style: TextStyle(color: Colors.black54)),
      );
    } else {
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final DailyCarePhotoModel photo in photos)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _photoThumb(photo),
              ),
          ],
        ),
      );
    }

    children.add(const SizedBox(height: 10));
    children.add(
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: notice.warn
              ? const Color(0xFFFFF3E0)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              notice.warn ? Icons.schedule : Icons.info_outline,
              size: 16,
              color: notice.warn ? const Color(0xFFE65100) : Colors.black54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notice.text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: notice.warn ? FontWeight.w800 : FontWeight.w600,
                  color: notice.warn ? const Color(0xFFE65100) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    children.add(const SizedBox(height: 14));
    children.addAll(_buildShareActions(bundle, photos));
    return children;
  }

  Widget _photoThumb(DailyCarePhotoModel photo) {
    if (photo.previewUrl.trim().isEmpty) {
      return Container(width: 88, height: 88, color: const Color(0xFFEEEEEE));
    }
    return Image.network(
      photo.previewUrl,
      width: 88,
      height: 88,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Container(width: 88, height: 88, color: const Color(0xFFEEEEEE));
      },
    );
  }

  List<Widget> _buildShareActions(
    _PreviewBundle bundle,
    List<DailyCarePhotoModel> photos,
  ) {
    final DailyCareReportCenterItem item = widget.session;
    final List<DateTime> dates = DailyCareReportExportService.instance
        .recordCareDates(stay: bundle.stay, records: bundle.records);
    final bool multiDay = dates.length > 1;
    final bool stayOrder = !item.isDaycare;
    final DailyCareReportStats? stats = bundle.data.stats;
    final bool summaryReady =
        stats != null &&
        stats.completedSessions > 0 &&
        stats.missingSessions == 0;

    return <Widget>[
      const Text('分享圖', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.tonal(
            onPressed: _generating
                ? null
                : () => _generate(
                    bundle: bundle,
                    photos: photos,
                    onlyDate: item.recordDate,
                    kind: DailyCareReportExportKind.singleDay,
                  ),
            child: const Text('產生本場分享圖'),
          ),
          if (stayOrder)
            OutlinedButton(
              onPressed: _generating
                  ? null
                  : () => _generate(
                      bundle: bundle,
                      photos: photos,
                      kind: DailyCareReportExportKind.fullStay,
                    ),
              child: const Text('產生本次住宿完整分享圖'),
            ),
          if (multiDay)
            OutlinedButton(
              onPressed: _generating
                  ? null
                  : () =>
                        _pickDate(bundle: bundle, photos: photos, dates: dates),
              child: const Text('選擇單日詳細圖'),
            ),
          if (summaryReady)
            OutlinedButton(
              onPressed: _generating
                  ? null
                  : () => _generate(
                      bundle: bundle,
                      photos: photos,
                      kind: DailyCareReportExportKind.summary,
                    ),
              child: const Text('產生照護摘要圖'),
            ),
        ],
      ),
      if (!summaryReady) ...<Widget>[
        const SizedBox(height: 6),
        const Text(
          '照護摘要圖需要整次紀錄都完成才會開放。',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
      if (_generating) ...<Widget>[
        const SizedBox(height: 10),
        const LinearProgressIndicator(minHeight: 3),
      ],
    ];
  }

  Future<void> _pickDate({
    required _PreviewBundle bundle,
    required List<DailyCarePhotoModel> photos,
    required List<DateTime> dates,
  }) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: const Text('選擇單日詳細圖'),
          children: <Widget>[
            for (final DateTime date in dates)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(date),
                child: Text('${date.month}/${date.day}'),
              ),
          ],
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    await _generate(
      bundle: bundle,
      photos: photos,
      onlyDate: picked,
      kind: DailyCareReportExportKind.singleDay,
    );
  }

  Future<void> _generate({
    required _PreviewBundle bundle,
    required List<DailyCarePhotoModel> photos,
    DateTime? onlyDate,
    DailyCareReportExportKind kind = DailyCareReportExportKind.fullStay,
  }) async {
    if (_generating) {
      return;
    }
    setState(() {
      _generating = true;
    });
    final DailyCareReportExportService export =
        DailyCareReportExportService.instance;
    try {
      final DailyCareReportData data = export.buildReport(
        booking: bundle.booking,
        shop: bundle.shop,
        stay: bundle.stay,
        setting: widget.setting,
        records: bundle.records,
        onlyDate: onlyDate,
        kind: kind,
      );
      if (kind != DailyCareReportExportKind.summary && data.days.isEmpty) {
        throw StateError('沒有可產出的照護日期');
      }
      if (kind == DailyCareReportExportKind.summary && bundle.records.isEmpty) {
        throw StateError('沒有可產出的照護紀錄');
      }
      final ImageProvider? logo = await export.preloadLogo(
        context,
        data.shopLogoUrl,
      );
      if (!mounted) {
        return;
      }
      List<ImageProvider> photoProviders = const <ImageProvider>[];
      if (kind != DailyCareReportExportKind.summary) {
        photoProviders = await export.preloadPhotos(
          context,
          photos.map((DailyCarePhotoModel photo) => photo.previewUrl).toList(),
        );
      }
      if (!mounted) {
        return;
      }
      await export.exportPng(
        context: context,
        data: data,
        logoProvider: logo,
        fileName: export.fileName(data: data),
        photoProviders: photoProviders,
        expiryNote: buildPhotoExpiryFootnote(
          expiresAt: _earliestExpiry(photos),
        ),
      );
      if (!mounted) {
        return;
      }
      final String done = kIsWeb ? '分享圖已產生，開始下載。' : '分享圖已產生，請選擇儲存或分享位置。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('產生分享圖失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
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
