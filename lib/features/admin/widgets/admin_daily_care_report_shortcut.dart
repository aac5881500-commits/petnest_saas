// 檔案名稱：lib/features/admin/widgets/admin_daily_care_report_shortcut.dart
// 功能說明：從訂單詳細頁帶入既有每日照護填寫／查看頁，不另開權限。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
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
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_report_center_page.dart';

class AdminDailyCareReportShortcut extends StatefulWidget {
  const AdminDailyCareReportShortcut({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;

  static final ValueNotifier<int> summaryEpoch = ValueNotifier<int>(0);

  static bool shouldShow(
    Map<String, dynamic> booking, {
    DailyCareSettingModel? setting,
  }) {
    if ((booking['status'] ?? '').toString() == 'cancelled') {
      return false;
    }
    final bool daycare = BookingKind.isDaycare(booking);
    if (!DailyCareReportEligibility.includeInReportCenter(
      booking: booking,
      daycare: daycare,
    )) {
      return false;
    }
    final DailyCareEntitlement entitlement = setting == null
        ? DailyCareReportEligibility.entitlementOf(booking)
        : DailyCareReportEligibility.resolvedEntitlement(
            booking: booking,
            setting: setting,
            daycare: daycare,
          );
    return DailyCareReportEligibility.isEntitled(entitlement);
  }

  static Future<void> openCenter({
    required BuildContext context,
    required String shopId,
    required String bookingId,
    required Map<String, dynamic> booking,
    DateTime? recordDate,
    int? sessionIndex,
    bool canOperate = true,
  }) async {
    final bool daycare = BookingKind.isDaycare(booking);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DailyCareReportCenterPage(
          shopId: shopId,
          canOperate: canOperate,
          focusBookingId: bookingId,
          focusServiceType: daycare
              ? DailyCareServiceTypes.daycare
              : DailyCareServiceTypes.accommodation,
          focusRecordDate: recordDate,
          focusSessionIndex: sessionIndex,
          focusBookingCode: (booking['bookingCode'] ?? '').toString().trim(),
        ),
      ),
    );
    summaryEpoch.value += 1;
  }

  static Future<bool?> openStayEntry({
    required BuildContext context,
    required String shopId,
    required String bookingId,
    required Map<String, dynamic> booking,
  }) async {
    await openCenter(
      context: context,
      shopId: shopId,
      bookingId: bookingId,
      booking: booking,
    );
    return true;
  }

  @override
  State<AdminDailyCareReportShortcut> createState() =>
      _AdminDailyCareReportShortcutState();
}

class _AdminDailyCareReportShortcutState
    extends State<AdminDailyCareReportShortcut> {
  final int _refreshEpoch = 0;
  final Set<String> _locallyFilled = <String>{};

  String get shopId => widget.shopId;
  String get bookingId => widget.bookingId;
  Map<String, dynamic> get booking => widget.booking;

  DailyCareEntitlement _resolvedEntitlement(DailyCareSettingModel setting) {
    return DailyCareReportEligibility.resolvedEntitlement(
      booking: booking,
      setting: setting,
      daycare: BookingKind.isDaycare(booking),
    );
  }

  String _sessionKey(DateTime date, int sessionIndex) {
    return '${DailyCareDateHelper.dateKey(date)}#$sessionIndex';
  }

  @override
  Widget build(BuildContext context) {
    if (shopId.isEmpty || bookingId.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool daycare = BookingKind.isDaycare(booking);
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(shopId),
      builder:
          (BuildContext context, AsyncSnapshot<DailyCareSettingModel> snap) {
            final DailyCareSettingModel setting =
                snap.data ?? const DailyCareSettingModel();
            if (daycare) {
              if (!AdminDailyCareReportShortcut.shouldShow(
                booking,
                setting: setting,
              )) {
                return const SizedBox.shrink();
              }
              return _daycareButton(context, setting: setting);
            }
            return _staySummary(setting);
          },
    );
  }

  Widget _staySummary(DailyCareSettingModel setting) {
    final DailyCareEntitlement entitlement = _resolvedEntitlement(setting);
    if (!DailyCareReportEligibility.isEntitled(entitlement)) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('本訂單未包含每日照護回報', style: TextStyle(color: Colors.black54)),
      );
    }
    final int perDay = DailyCareReportEligibility.staySessionPerDay(
      booking,
      setting: setting,
    );
    final List<DateTime> dates = DailyCareReportEligibility.stayCareDates(
      booking,
      setting: setting,
    );
    final int total = dates.isEmpty || perDay < 1 ? 0 : dates.length * perDay;
    return ValueListenableBuilder<int>(
      valueListenable: AdminDailyCareReportShortcut.summaryEpoch,
      builder: (BuildContext context, int epoch, Widget? child) {
        return StreamBuilder<List<DailyCareRecordModel>>(
          key: ValueKey<String>('$epoch-$_refreshEpoch'),
          stream: DailyCareRecordService.instance.streamBookingRecords(
            bookingId: bookingId,
            shopId: shopId,
            careDates: dates,
            sessionCount: perDay < 1 ? 1 : perDay,
          ),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<DailyCareRecordModel>> snap,
              ) {
                final List<DailyCareRecordModel> records =
                    snap.data ?? const <DailyCareRecordModel>[];
                final Set<String> filledKeys = <String>{
                  for (final DailyCareRecordModel record in records)
                    _sessionKey(record.recordDate, record.sessionIndex),
                  ..._locallyFilled,
                };
                final int filled = filledKeys.length;
                final int safeTotal = total < 1 ? 0 : total;
                final int safeFilled = filled > safeTotal ? safeTotal : filled;
                final String dateLine = dates
                    .map(DailyCareDateHelper.dateKey)
                    .join('、');
                return StreamBuilder<List<DailyCarePhotoModel>>(
                  stream: DailyCarePhotoService.instance.streamBookingPhotos(
                    bookingId: bookingId,
                    shopId: shopId,
                  ),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<DailyCarePhotoModel>> photoSnap,
                      ) {
                        final List<DailyCarePhotoModel> photos =
                            photoSnap.data ?? const <DailyCarePhotoModel>[];
                        final bool locked = DailyCareReportWriteAccess.isLocked(
                          booking,
                        );
                        final int missing = safeTotal - safeFilled;
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
                            if (dateLine.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                '住宿回報日：$dateLine（共 ${dates.length} 天）',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '本次合計：${entitlement.finalReports} × ${dates.length} = $safeTotal 場',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            if (snap.hasError)
                              const Text(
                                '回報完成數暫時無法載入，請重新整理後再試',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              )
                            else
                              Text(
                                locked
                                    ? DailyCareSessionStatus.bookingLockBanner(
                                        missingCount: missing,
                                      )
                                    : '已完成：$safeFilled／$safeTotal 場',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            const SizedBox(height: 8),
                            for (final DateTime date in dates) ...<Widget>[
                              Text(
                                '${date.month}/${date.day}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              for (int index = 0; index < perDay; index++)
                                Text(
                                  DailyCareSessionStatus.sessionLine(
                                    completed: filledKeys.contains(
                                      _sessionKey(date, index),
                                    ),
                                    photoCount:
                                        DailyCareSessionStatus.countPhotos(
                                          photos: photos,
                                          bookingId: bookingId,
                                          recordId:
                                              DailyCareRecordService.recordId(
                                                bookingId: bookingId,
                                                recordDate: date,
                                                sessionIndex: index,
                                              ),
                                          recordDate: date,
                                          sessionIndex: index,
                                          roomId: (booking['roomId'] ?? '')
                                              .toString(),
                                        ),
                                    locked: locked,
                                  ),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              const SizedBox(height: 6),
                            ],
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  AdminDailyCareReportShortcut.openCenter(
                                    context: context,
                                    shopId: shopId,
                                    bookingId: bookingId,
                                    booking: booking,
                                    canOperate: !locked,
                                  ),
                              icon: Icon(
                                locked
                                    ? Icons.lock_outline
                                    : Icons.assignment_turned_in_outlined,
                              ),
                              label: Text(locked ? '查看每日回報（唯讀）' : '前往每日回報中心'),
                            ),
                            if (safeFilled > 0)
                              TextButton(
                                onPressed: () => _openStayView(context),
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

  Future<void> _openStayView(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDailyCarePage(
          shopId: shopId,
          bookingId: bookingId,
          roomName: (booking['roomName'] ?? '').toString(),
          previewMode: true,
          journalTitle: '住宿照護紀錄',
        ),
      ),
    );
  }

  Widget _daycareButton(
    BuildContext context, {
    required DailyCareSettingModel setting,
  }) {
    final bool locked = DailyCareReportWriteAccess.isLocked(booking);
    final bool canFill =
        !locked &&
        DailyCareDaycareAccess.canOperate(setting: setting, booking: booking);
    final String label = locked ? '查看每日回報（唯讀）' : '前往每日回報中心';
    return Padding(
      key: ValueKey<int>(_refreshEpoch),
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () => AdminDailyCareReportShortcut.openCenter(
            context: context,
            shopId: shopId,
            bookingId: bookingId,
            booking: booking,
            recordDate: DailyCareDaycareAccess.serviceCalendarDate(booking),
            canOperate: !locked,
          ),
          icon: Icon(canFill ? Icons.edit_note : Icons.photo_library_outlined),
          label: Text(label),
        ),
      ),
    );
  }
}
