// 檔案名稱：lib/features/admin/widgets/admin_daily_care_report_shortcut.dart
// 功能說明：從訂單詳細頁帶入既有每日照護填寫／查看頁，不另開權限。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/services/daily_care_report_eligibility.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/room/daily_care_record_edit_launcher.dart';

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

  static bool shouldShow(Map<String, dynamic> booking) {
    if ((booking['status'] ?? '').toString() == 'cancelled') {
      return false;
    }
    if (BookingKind.isDaycare(booking)) {
      if (!DailyCareDaycareAccess.hasStartedCare(booking)) {
        return false;
      }
    } else if ((booking['status'] ?? '').toString() != 'checked_in') {
      return false;
    }
    final Object? raw = booking['dailyCareEntitlement'];
    if (raw is! Map) {
      return false;
    }
    final DailyCareEntitlement entitlement = DailyCareEntitlement.fromMap(
      Map<String, dynamic>.from(raw),
    );
    if (entitlement.finalReports >= 1) {
      return true;
    }
    return entitlement.enabled && entitlement.sessionLabels.isNotEmpty;
  }

  static Future<bool?> openStayEntry({
    required BuildContext context,
    required String shopId,
    required String bookingId,
    required Map<String, dynamic> booking,
  }) async {
    final DailyCareSettingModel setting = await DailyCareSettingService.instance
        .getSetting(shopId);
    if (!context.mounted) {
      return null;
    }
    final int sessionCount = DailyCareReportEligibility.staySessionPerDay(
      booking,
      setting: setting,
    );
    final int todayCount = sessionCount < 1 ? 1 : sessionCount;
    final DateTime recordDate = DailyCareReportEligibility.stayFillDate(
      booking,
    );
    final Set<int> completed = <int>{};
    for (int index = 0; index < todayCount; index++) {
      final DailyCareRecordModel? record = await DailyCareRecordService.instance
          .getRecord(
            bookingId: bookingId,
            shopId: shopId,
            recordDate: recordDate,
            sessionIndex: index,
          );
      if (record != null) {
        completed.add(index);
      }
    }
    if (!context.mounted) {
      return null;
    }
    final int sessionIndex =
        DailyCareReportEligibility.firstIncompleteSessionIndex(
          sessionCount: todayCount,
          completedIndexes: completed,
        );
    final bool? saved = await DailyCareRecordEditLauncher.open(
      context: context,
      shopId: shopId,
      bookingId: bookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
      roomId: (booking['roomId'] ?? '').toString().trim(),
      roomName: (booking['roomName'] ?? '').toString().trim(),
      serviceType: DailyCareServiceTypes.accommodation,
      petIds: DailyCareReportEligibility.petIdsOf(booking),
      setting: setting,
    );
    if (saved == true) {
      summaryEpoch.value += 1;
    }
    return saved;
  }

  @override
  State<AdminDailyCareReportShortcut> createState() =>
      _AdminDailyCareReportShortcutState();
}

class _AdminDailyCareReportShortcutState
    extends State<AdminDailyCareReportShortcut> {
  int _refreshEpoch = 0;

  String get shopId => widget.shopId;
  String get bookingId => widget.bookingId;
  Map<String, dynamic> get booking => widget.booking;

  DailyCareEntitlement get _entitlement {
    final Object? raw = booking['dailyCareEntitlement'];
    if (raw is! Map) {
      return const DailyCareEntitlement();
    }
    return DailyCareEntitlement.fromMap(Map<String, dynamic>.from(raw));
  }

  List<String> get _petIds => DailyCareReportEligibility.petIdsOf(booking);

  @override
  Widget build(BuildContext context) {
    if (shopId.isEmpty ||
        bookingId.isEmpty ||
        !AdminDailyCareReportShortcut.shouldShow(booking)) {
      return const SizedBox.shrink();
    }
    final bool daycare = BookingKind.isDaycare(booking);
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(shopId),
      builder:
          (BuildContext context, AsyncSnapshot<DailyCareSettingModel> snap) {
            final DailyCareSettingModel setting =
                snap.data ?? const DailyCareSettingModel();
            final String status = (booking['status'] ?? '').toString();
            if (status == 'cancelled') {
              return const SizedBox.shrink();
            }
            if (daycare) {
              return _daycareButton(context, setting: setting, status: status);
            }
            return _staySummary(setting);
          },
    );
  }

  Widget _staySummary(DailyCareSettingModel setting) {
    final int total = DailyCareReportEligibility.stayScheduledSessionTotal(
      booking,
      setting: setting,
    );
    final int perDay = DailyCareReportEligibility.staySessionPerDay(
      booking,
      setting: setting,
    );
    final List<DateTime> dates = DailyCareReportEligibility.stayCareDates(
      booking,
    );
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
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
                final int filled =
                    DailyCareReportEligibility.completedSessionCount(
                      snap.data ?? const <DailyCareRecordModel>[],
                    );
                final int safeTotal = total < 1 ? 0 : total;
                final int safeFilled = filled > safeTotal ? safeTotal : filled;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '本次住宿共 $safeTotal 場',
                        style: TextStyle(fontSize: 13, color: theme.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已完成 $safeFilled／$safeTotal 場',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: theme.titleColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
        );
      },
    );
  }

  Widget _daycareButton(
    BuildContext context, {
    required DailyCareSettingModel setting,
    required String status,
  }) {
    final bool completed = status == 'completed' || status == 'checked_out';
    final bool canFill =
        !completed &&
        DailyCareDaycareAccess.canOperate(setting: setting, booking: booking);
    final String label = canFill ? '前往填寫照護回報' : '查看照護回報';
    return Padding(
      key: ValueKey<int>(_refreshEpoch),
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () => canFill
              ? _openFill(context, setting, _entitlement, true)
              : _openView(context),
          icon: Icon(canFill ? Icons.edit_note : Icons.photo_library_outlined),
          label: Text(label),
        ),
      ),
    );
  }

  Future<void> _openFill(
    BuildContext context,
    DailyCareSettingModel setting,
    DailyCareEntitlement entitlement,
    bool daycare,
  ) async {
    DateTime date = DailyCareDateHelper.todayInTaipei();
    if (entitlement.serviceDates.isNotEmpty) {
      final DateTime? parsed = DailyCareDateHelper.parseDateKey(
        entitlement.serviceDates.first.replaceAll('-', '/'),
      );
      if (parsed != null) {
        date = parsed;
      }
    } else if (daycare) {
      date =
          DailyCareDaycareAccess.serviceCalendarDate(booking) ??
          DailyCareDateHelper.todayInTaipei();
    }
    final bool? saved = await DailyCareRecordEditLauncher.open(
      context: context,
      shopId: shopId,
      bookingId: bookingId,
      recordDate: date,
      sessionIndex: 0,
      roomId: (booking['roomId'] ?? '').toString(),
      roomName: (booking['roomName'] ?? '').toString(),
      serviceType: daycare
          ? DailyCareServiceTypes.daycare
          : DailyCareServiceTypes.accommodation,
      petIds: _petIds,
      setting: setting,
    );
    if (!mounted) {
      return;
    }
    if (saved == true) {
      setState(() {
        _refreshEpoch += 1;
      });
    }
  }

  Future<void> _openView(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDailyCarePage(
          shopId: shopId,
          bookingId: bookingId,
          roomName: (booking['roomName'] ?? '').toString(),
          previewMode: true,
          journalTitle: '照護回報',
        ),
      ),
    );
  }
}
