// 檔案名稱：lib/features/admin/widgets/admin_daycare_care_report_section.dart
// 功能說明：安親訂單照護回報入口，共用既有每日照護填寫／查看頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_photo_model.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_session_status.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';
import 'package:petnest_saas/core/services/daily_care_photo_service.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/services/daily_care_report_eligibility.dart';
import 'package:petnest_saas/core/services/daily_care_report_write_access.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daily_care_report_shortcut.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';

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
  final int _streamEpoch = 0;

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
      builder: (BuildContext context, AsyncSnapshot<DailyCareSettingModel> settingSnap) {
        final DailyCareSettingModel setting =
            settingSnap.data ?? const DailyCareSettingModel();
        if (!setting.daycareEnabled) {
          return const SizedBox.shrink();
        }
        if (!DailyCareDaycareAccess.hasStartedCare(widget.booking)) {
          return const SizedBox.shrink();
        }
        final DailyCareEntitlement entitlement =
            DailyCareReportEligibility.resolvedEntitlement(
              booking: widget.booking,
              setting: setting,
              daycare: true,
            );
        if (!DailyCareReportEligibility.isEntitled(entitlement)) {
          return const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '本訂單未包含每日照護回報',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        final int total = entitlement.finalReports;
        return StreamBuilder<List<DailyCareRecordModel>>(
          key: ValueKey<int>(_streamEpoch),
          stream: DailyCareRecordService.instance.streamBookingRecords(
            bookingId: widget.bookingId,
            shopId: widget.shopId,
            careDates: <DateTime>[
              DailyCareDaycareAccess.serviceCalendarDate(widget.booking) ??
                  DateTime.now(),
            ],
            sessionCount: total < 1 ? 1 : total,
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
                final int total = entitlement.finalReports;
                final bool locked = DailyCareReportWriteAccess.isLocked(
                  widget.booking,
                );
                if (widget.compact) {
                  return _compactActions(
                    context,
                    filled: filled,
                    locked: locked,
                  );
                }
                return StreamBuilder<List<DailyCarePhotoModel>>(
                  stream: DailyCarePhotoService.instance.streamBookingPhotos(
                    bookingId: widget.bookingId,
                    shopId: widget.shopId,
                  ),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<DailyCarePhotoModel>> photoSnap,
                      ) {
                        final List<DailyCarePhotoModel> photos =
                            photoSnap.data ?? const <DailyCarePhotoModel>[];
                        final DateTime date =
                            DailyCareDaycareAccess.serviceCalendarDate(
                              widget.booking,
                            ) ??
                            DateTime.now();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '每日基本包含：${entitlement.baseReports} 場',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (entitlement.addonReports > 0) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                '加購增加：${entitlement.addonReports} 場　名稱：${entitlement.addonName}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '每日應回報：${entitlement.finalReports} 場',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              locked
                                  ? DailyCareSessionStatus.bookingLockBanner(
                                      missingCount: total - filled,
                                    )
                                  : '已填 $filled / $total 次',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (int index = 0; index < total; index++)
                              Text(
                                DailyCareSessionStatus.sessionLine(
                                  completed: filledSessions.contains(index),
                                  photoCount:
                                      DailyCareSessionStatus.countPhotos(
                                        photos: photos,
                                        bookingId: widget.bookingId,
                                        recordId:
                                            DailyCareRecordService.recordId(
                                              bookingId: widget.bookingId,
                                              recordDate: date,
                                              sessionIndex: index,
                                            ),
                                        recordDate: date,
                                        sessionIndex: index,
                                        roomId: (widget.booking['roomId'] ?? '')
                                            .toString(),
                                      ),
                                  locked: locked,
                                ),
                                style: const TextStyle(color: Colors.black54),
                              ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  AdminDailyCareReportShortcut.openCenter(
                                    context: context,
                                    shopId: widget.shopId,
                                    bookingId: widget.bookingId,
                                    booking: widget.booking,
                                    recordDate:
                                        DailyCareDaycareAccess.serviceCalendarDate(
                                          widget.booking,
                                        ),
                                    canOperate: !locked,
                                  ),
                              icon: Icon(
                                locked
                                    ? Icons.lock_outline
                                    : Icons.assignment_turned_in_outlined,
                              ),
                              label: Text(locked ? '查看每日回報（唯讀）' : '前往每日回報中心'),
                            ),
                            TextButton(
                              onPressed: () => _openView(context),
                              child: const Text('查看紀錄'),
                            ),
                          ],
                        );
                      },
                );
              },
        );
      },
    );
  }

  Widget _compactActions(
    BuildContext context, {
    required int filled,
    required bool locked,
  }) {
    if (filled == 0 && !DailyCareDaycareAccess.hasStartedCare(widget.booking)) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      children: <Widget>[
        OutlinedButton(
          onPressed: () => AdminDailyCareReportShortcut.openCenter(
            context: context,
            shopId: widget.shopId,
            bookingId: widget.bookingId,
            booking: widget.booking,
            recordDate: DailyCareDaycareAccess.serviceCalendarDate(
              widget.booking,
            ),
            canOperate: !locked,
          ),
          child: Text(locked ? '查看每日回報（唯讀）' : '前往每日回報中心'),
        ),
        if (filled > 0)
          TextButton(
            onPressed: () => _openView(context),
            child: const Text('查看'),
          ),
      ],
    );
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
