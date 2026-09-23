// 檔案名稱：lib/features/admin/widgets/admin_daycare_care_report_section.dart
// 功能說明：安親訂單照護回報入口，共用既有每日照護填寫／查看頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/room/daily_care_record_edit_launcher.dart';

class AdminDaycareCareReportSection extends StatefulWidget {
  const AdminDaycareCareReportSection({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
    this.compact = false,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;
  final bool compact;

  @override
  State<AdminDaycareCareReportSection> createState() =>
      _AdminDaycareCareReportSectionState();
}

class _AdminDaycareCareReportSectionState
    extends State<AdminDaycareCareReportSection> {
  final Set<int> _locallyFilledSessions = <int>{};
  int _streamEpoch = 0;

  List<String> get _petIds {
    final Object? raw = widget.booking['petIds'];
    if (raw is! Iterable) {
      return const <String>[];
    }
    return raw
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  Set<int> _filledSessions(List<DailyCareRecordModel> records) {
    return <int>{
      for (final DailyCareRecordModel record in records) record.sessionIndex,
      ..._locallyFilledSessions,
    };
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
            if (!setting.daycareEnabled) {
              return const SizedBox.shrink();
            }
            if (!DailyCareDaycareAccess.hasStartedCare(widget.booking)) {
              return const SizedBox.shrink();
            }
            final bool canFill = DailyCareDaycareAccess.canOperate(
              setting: setting,
              booking: widget.booking,
            );
            return StreamBuilder<List<DailyCareRecordModel>>(
              key: ValueKey<int>(_streamEpoch),
              stream: DailyCareRecordService.instance.streamBookingRecords(
                bookingId: widget.bookingId,
                shopId: widget.shopId,
                careDates: <DateTime>[
                  DailyCareDaycareAccess.serviceCalendarDate(widget.booking) ??
                      DateTime.now(),
                ],
                sessionCount: setting.daycareSessionCount,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<DailyCareRecordModel>> recordSnap,
                  ) {
                    final List<DailyCareRecordModel> records =
                        recordSnap.data ?? const <DailyCareRecordModel>[];
                    final Set<int> filledSessions = _filledSessions(records);
                    final int filled = filledSessions.length;
                    final int total = setting.daycareSessionCount;
                    if (widget.compact) {
                      return _compactActions(
                        context,
                        setting: setting,
                        canFill: canFill,
                        filled: filled,
                        total: total,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '已填 $filled / $total 次',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (int index = 0; index < total; index++)
                              OutlinedButton(
                                onPressed: canFill
                                    ? () => _openFill(context, setting, index)
                                    : null,
                                child: Text(
                                  filledSessions.contains(index)
                                      ? '編輯${setting.sessionLabelAt(index)}'
                                      : '填寫${setting.sessionLabelAt(index)}',
                                ),
                              ),
                            TextButton(
                              onPressed: () => _openView(context),
                              child: const Text('查看紀錄'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
            );
          },
    );
  }

  Widget _compactActions(
    BuildContext context, {
    required DailyCareSettingModel setting,
    required bool canFill,
    required int filled,
    required int total,
  }) {
    if (!canFill && filled == 0) {
      return const SizedBox.shrink();
    }
    final String label = filled >= total
        ? '照護回報已完成'
        : filled > 0
        ? '繼續填寫照護回報'
        : '填寫照護回報';
    return Wrap(
      spacing: 8,
      children: <Widget>[
        if (canFill)
          OutlinedButton(
            onPressed: () {
              final int next = filled >= total ? 0 : filled;
              _openFill(context, setting, next);
            },
            child: Text(label),
          ),
        if (filled > 0)
          TextButton(
            onPressed: () => _openView(context),
            child: const Text('查看'),
          ),
      ],
    );
  }

  Future<void> _openFill(
    BuildContext context,
    DailyCareSettingModel setting,
    int sessionIndex,
  ) async {
    final bool? saved = await DailyCareRecordEditLauncher.open(
      context: context,
      shopId: widget.shopId,
      bookingId: widget.bookingId,
      recordDate:
          DailyCareDaycareAccess.serviceCalendarDate(widget.booking) ??
          DateTime.now(),
      sessionIndex: sessionIndex,
      roomId: (widget.booking['roomId'] ?? '').toString(),
      roomName: (widget.booking['roomName'] ?? '').toString(),
      serviceType: DailyCareServiceTypes.daycare,
      petIds: _petIds,
      setting: setting,
    );
    if (!mounted) {
      return;
    }
    if (saved == true) {
      setState(() {
        _locallyFilledSessions.add(sessionIndex);
        _streamEpoch += 1;
      });
    }
  }

  Future<void> _openView(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDailyCarePage(
          shopId: widget.shopId,
          bookingId: widget.bookingId,
          roomName: (widget.booking['roomName'] ?? '').toString(),
          previewMode: true,
          journalTitle: '本次安親回報',
        ),
      ),
    );
  }
}
