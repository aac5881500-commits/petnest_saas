// 檔案名稱：lib/features/admin/widgets/admin_daily_care_report_shortcut.dart
// 功能說明：從訂單詳細頁帶入既有每日照護填寫／查看頁，不另開權限。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/room/daily_care_record_edit_launcher.dart';

class AdminDailyCareReportShortcut extends StatelessWidget {
  const AdminDailyCareReportShortcut({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;

  static bool shouldShow(Map<String, dynamic> booking) {
    if ((booking['status'] ?? '').toString() == 'cancelled') {
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

  DailyCareEntitlement get _entitlement {
    final Object? raw = booking['dailyCareEntitlement'];
    if (raw is! Map) {
      return const DailyCareEntitlement();
    }
    return DailyCareEntitlement.fromMap(Map<String, dynamic>.from(raw));
  }

  List<String> get _petIds {
    final Object? raw = booking['petIds'];
    if (raw is Iterable) {
      return raw
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final Object? pets = booking['pets'];
    if (pets is! Iterable) {
      return const <String>[];
    }
    return pets
        .whereType<Map>()
        .map(
          (Map item) =>
              (item['petId'] ?? item['id'] ?? '').toString().trim(),
        )
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (shopId.isEmpty || bookingId.isEmpty || !shouldShow(booking)) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(shopId),
      builder:
          (BuildContext context, AsyncSnapshot<DailyCareSettingModel> snap) {
            final DailyCareSettingModel setting =
                snap.data ?? const DailyCareSettingModel();
            final String status = (booking['status'] ?? '').toString();
            final bool cancelled = status == 'cancelled';
            if (cancelled) {
              return const SizedBox.shrink();
            }
            final bool daycare = BookingKind.isDaycare(booking);
            final bool completed =
                status == 'completed' || status == 'checked_out';
            final bool canFill = !completed &&
                (daycare
                    ? DailyCareDaycareAccess.canOperate(
                        setting: setting,
                        booking: booking,
                      )
                    : status == 'checked_in' || status == 'confirmed');
            final String label = canFill ? '前往填寫照護回報' : '查看照護回報';
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => canFill
                      ? _openFill(context, setting, _entitlement, daycare)
                      : _openView(context),
                  icon: Icon(canFill ? Icons.edit_note : Icons.photo_library_outlined),
                  label: Text(label),
                ),
              ),
            );
          },
    );
  }

  Future<void> _openFill(
    BuildContext context,
    DailyCareSettingModel setting,
    DailyCareEntitlement entitlement,
    bool daycare,
  ) {
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
    return DailyCareRecordEditLauncher.open(
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
