// 檔案名稱：lib/features/admin/widgets/admin_daily_care_report_shortcut.dart
// 功能說明：從訂單詳細頁帶入既有每日照護填寫／查看頁，不另開權限。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
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
    final DailyCareEntitlement entitlement =
        DailyCareReportEligibility.resolvedEntitlement(
          booking: booking,
          setting: setting,
          daycare: false,
        );
    final int sessionCount = DailyCareReportEligibility.staySessionPerDay(
      booking,
      setting: setting,
    );
    final int todayCount = entitlement.finalReports >= 1
        ? entitlement.finalReports
        : (sessionCount < 1 ? 1 : sessionCount);
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
      entitlement: entitlement,
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
  final Set<String> _locallyFilled = <String>{};

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

  DailyCareEntitlement _resolvedStayEntitlement(DailyCareSettingModel setting) {
    return DailyCareReportEligibility.resolvedEntitlement(
      booking: booking,
      setting: setting,
      daycare: false,
    );
  }

  bool _hasStayReportRights(DailyCareEntitlement entitlement) {
    if (!entitlement.enabled) {
      return false;
    }
    return entitlement.finalReports >= 1 ||
        entitlement.sessionLabels.isNotEmpty;
  }

  int _sessionsPerDay(
    DailyCareEntitlement entitlement,
    DailyCareSettingModel setting,
  ) {
    if (entitlement.finalReports >= 1) {
      return entitlement.finalReports;
    }
    if (entitlement.sessionLabels.isNotEmpty) {
      return entitlement.sessionLabels.length;
    }
    return setting.sessionCount < 1 ? 0 : setting.sessionCount;
  }

  List<String> get _petIds => DailyCareReportEligibility.petIdsOf(booking);

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
            final String status = (booking['status'] ?? '').toString();
            if (daycare) {
              if (!AdminDailyCareReportShortcut.shouldShow(booking)) {
                return const SizedBox.shrink();
              }
              return _daycareButton(context, setting: setting, status: status);
            }
            return _staySummary(setting, status);
          },
    );
  }

  Widget _staySummary(DailyCareSettingModel setting, String status) {
    final DailyCareEntitlement entitlement = _resolvedStayEntitlement(setting);
    if (!_hasStayReportRights(entitlement)) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('本訂單未包含每日照護回報', style: TextStyle(color: Colors.black54)),
      );
    }
    final int perDay = _sessionsPerDay(entitlement, setting);
    final List<DateTime> dates = DailyCareReportEligibility.stayCareDates(
      booking,
    );
    final int total = dates.isEmpty || perDay < 1 ? 0 : dates.length * perDay;
    final bool canFill = status == 'checked_in';
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
          builder: (BuildContext context, AsyncSnapshot<List<DailyCareRecordModel>> snap) {
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
                    '已完成：$safeFilled／$safeTotal 場',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                const SizedBox(height: 8),
                for (final DateTime date in dates) ...<Widget>[
                  Text(
                    '${date.month}/${date.day}　已完成 ${_filledOnDate(date, filledKeys, perDay)}／$perDay 場',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (canFill) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (int index = 0; index < perDay; index++)
                          OutlinedButton(
                            onPressed: () => _openStayFill(
                              context,
                              setting,
                              entitlement,
                              date,
                              index,
                            ),
                            child: Text(
                              filledKeys.contains(_sessionKey(date, index))
                                  ? '編輯${DailyCareReportEligibility.sessionName(entitlement: entitlement, setting: setting, sessionIndex: index)}'
                                  : '填寫${DailyCareReportEligibility.sessionName(entitlement: entitlement, setting: setting, sessionIndex: index)}',
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
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
  }

  int _filledOnDate(DateTime date, Set<String> filledKeys, int perDay) {
    int count = 0;
    for (int index = 0; index < perDay; index++) {
      if (filledKeys.contains(_sessionKey(date, index))) {
        count += 1;
      }
    }
    return count;
  }

  Future<void> _openStayFill(
    BuildContext context,
    DailyCareSettingModel setting,
    DailyCareEntitlement entitlement,
    DateTime recordDate,
    int sessionIndex,
  ) async {
    final bool? saved = await DailyCareRecordEditLauncher.open(
      context: context,
      shopId: shopId,
      bookingId: bookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
      roomId: (booking['roomId'] ?? '').toString().trim(),
      roomName: (booking['roomName'] ?? '').toString().trim(),
      serviceType: DailyCareServiceTypes.accommodation,
      petIds: _petIds,
      setting: setting,
      entitlement: entitlement,
    );
    if (!mounted) {
      return;
    }
    if (saved == true) {
      setState(() {
        _locallyFilled.add(_sessionKey(recordDate, sessionIndex));
        _refreshEpoch += 1;
      });
      AdminDailyCareReportShortcut.summaryEpoch.value += 1;
    }
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
      entitlement: entitlement,
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
