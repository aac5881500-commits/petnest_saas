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

class AdminDaycareCareReportSection extends StatelessWidget {
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

  List<String> get _petIds {
    final Object? raw = booking['petIds'];
    if (raw is! Iterable) {
      return const <String>[];
    }
    return raw
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(shopId),
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
            final bool canFill = DailyCareDaycareAccess.canOperate(
              setting: setting,
              booking: booking,
            );
            return StreamBuilder<List<DailyCareRecordModel>>(
              stream: DailyCareRecordService.instance.streamBookingRecords(
                bookingId: bookingId,
                shopId: shopId,
                careDates: <DateTime>[
                  DailyCareDaycareAccess.serviceCalendarDate(booking) ??
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
                    final int filled = records.length;
                    final int total = setting.daycareSessionCount;
                    if (compact) {
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
                                  records.any(
                                        (DailyCareRecordModel e) =>
                                            e.sessionIndex == index,
                                      )
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
  ) {
    return DailyCareRecordEditLauncher.open(
      context: context,
      shopId: shopId,
      bookingId: bookingId,
      recordDate:
          DailyCareDaycareAccess.serviceCalendarDate(booking) ?? DateTime.now(),
      sessionIndex: sessionIndex,
      roomId: (booking['roomId'] ?? '').toString(),
      roomName: (booking['roomName'] ?? '').toString(),
      serviceType: DailyCareServiceTypes.daycare,
      petIds: _petIds,
      setting: setting,
    );
  }

  Future<void> _openView(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDailyCarePage(
          shopId: shopId,
          bookingId: bookingId,
          roomName: (booking['roomName'] ?? '').toString(),
          previewMode: true,
          journalTitle: '本次安親回報',
        ),
      ),
    );
  }
}
