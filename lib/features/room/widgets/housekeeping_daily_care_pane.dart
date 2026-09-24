// 檔案名稱：lib/features/room/widgets/housekeeping_daily_care_pane.dart
// 功能說明：房務分割工作台右側，重用每日回報中心資料與規則。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_session_status.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_report_center_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../shop/widgets/daily_care_report_center_board.dart';

class HousekeepingDailyCarePane extends StatefulWidget {
  const HousekeepingDailyCarePane({
    super.key,
    required this.shopId,
    this.focusBookingId = '',
    this.canOperate = true,
  });

  final String shopId;
  final String focusBookingId;
  final bool canOperate;

  @override
  State<HousekeepingDailyCarePane> createState() =>
      _HousekeepingDailyCarePaneState();
}

class _HousekeepingDailyCarePaneState extends State<HousekeepingDailyCarePane> {
  DailyCareReportCenterStatusFilter _status =
      DailyCareReportCenterStatusFilter.all;
  DailyCareReportCenterTypeFilter _type = DailyCareReportCenterTypeFilter.all;
  String _query = '';

  @override
  void didUpdateWidget(covariant HousekeepingDailyCarePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusBookingId != widget.focusBookingId &&
        widget.focusBookingId.trim().isNotEmpty) {
      _status = DailyCareReportCenterStatusFilter.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DailyCareSettingModel> settingSnap,
          ) {
            final DailyCareSettingModel setting =
                settingSnap.data ?? const DailyCareSettingModel();
            if (!setting.enabled && !setting.daycareEnabled) {
              return const Center(child: Text('每日回報功能目前未啟用'));
            }
            return StreamBuilder<DailyCareReportCenterSnapshot>(
              stream: DailyCareReportCenterService.instance.streamToday(
                shopId: widget.shopId,
                canOperate: widget.canOperate,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DailyCareReportCenterSnapshot> snap,
                  ) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final DailyCareReportCenterSnapshot data = snap.data!;
                    final List<DailyCareReportCenterItem> focused = data.items
                        .where(
                          (DailyCareReportCenterItem item) =>
                              item.bookingId == widget.focusBookingId.trim(),
                        )
                        .toList();
                    return Column(
                      children: <Widget>[
                        _header(focused),
                        Expanded(
                          child: DailyCareReportCenterBoard(
                            snapshot: data,
                            setting: setting,
                            status: _status,
                            onStatus:
                                (DailyCareReportCenterStatusFilter value) {
                                  setState(() => _status = value);
                                },
                            type: _type,
                            onType: (DailyCareReportCenterTypeFilter value) {
                              setState(() => _type = value);
                            },
                            query: _query,
                            onQuery: (String value) {
                              setState(() => _query = value);
                            },
                            focusBookingId: widget.focusBookingId,
                          ),
                        ),
                      ],
                    );
                  },
            );
          },
    );
  }

  Widget _header(List<DailyCareReportCenterItem> focused) {
    if (widget.focusBookingId.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Text(
          '點選左側入住中房間，即可查看該訂單回報',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    if (focused.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Text('此訂單目前沒有回報場次', style: TextStyle(color: Colors.black54)),
      );
    }
    final DailyCareReportCenterItem item = focused.first;
    final int pending = focused
        .where((DailyCareReportCenterItem row) => !row.isCompleted)
        .length;
    final int completed = focused.length - pending;
    final bool locked = item.reportsLocked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              if (item.placeLabel.isNotEmpty) item.placeLabel,
              if (item.bookingCode.isNotEmpty) item.bookingCode,
            ].join('・'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '待填 $pending 場　已完成 $completed 場',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (locked)
            Text(
              DailyCareSessionStatus.bookingLockBanner(missingCount: pending),
              style: const TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }
}
