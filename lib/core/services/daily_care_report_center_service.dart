// 檔案名稱：lib/core/services/daily_care_report_center_service.dart
// 功能說明：集中即時監聽今天真正有回報權益的住宿與安親訂單，並以固定 record ID 判斷完成狀態。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_kind.dart';
import '../models/daily_care_date_helper.dart';
import '../models/daily_care_report_center_item.dart';
import '../models/daily_care_report_center_snapshot.dart';
import '../models/daily_care_setting_model.dart';
import 'booking_service.dart';
import 'daily_care_report_eligibility.dart';
import 'daily_care_setting_service.dart';

class DailyCareReportCenterService {
  DailyCareReportCenterService._();

  static final DailyCareReportCenterService instance =
      DailyCareReportCenterService._();

  Stream<DailyCareReportCenterSnapshot> streamToday({
    required String shopId,
    required bool canOperate,
    DateTime? careDate,
  }) {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return Stream<DailyCareReportCenterSnapshot>.value(
        DailyCareReportCenterSnapshot.empty,
      );
    }

    final StreamController<DailyCareReportCenterSnapshot> controller =
        StreamController<DailyCareReportCenterSnapshot>();

    DailyCareSettingModel setting = const DailyCareSettingModel();
    List<Map<String, dynamic>> checkedIn = <Map<String, dynamic>>[];
    final Map<String, DateTime?> updatedAtById = <String, DateTime?>{};
    final Set<String> completedIds = <String>{};

    bool settingReady = false;
    bool bookingsReady = false;
    bool hasError = false;

    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];
    final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
    recordSubscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

    DateTime today() {
      return DailyCareDateHelper.dateOnly(
        careDate ?? DailyCareDateHelper.todayInTaipei(),
      );
    }

    void emit() {
      if (controller.isClosed) {
        return;
      }
      if (hasError) {
        controller.add(DailyCareReportCenterSnapshot.error);
        return;
      }
      if (!settingReady || !bookingsReady) {
        return;
      }
      controller.add(
        buildTodaySnapshot(
          shopId: normalizedShopId,
          setting: setting,
          checkedIn: checkedIn,
          canOperate: canOperate,
          today: today(),
          completedIds: completedIds,
          updatedAtById: updatedAtById,
        ),
      );
    }

    Future<void> bindRecordListeners() async {
      for (final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
          subscription
          in recordSubscriptions) {
        await subscription.cancel();
      }
      recordSubscriptions.clear();
      completedIds.clear();
      updatedAtById.clear();

      if (!setting.enabled) {
        emit();
        return;
      }

      final DateTime careDay = today();
      final Set<String> recordIds = <String>{};
      for (final Map<String, dynamic> booking in checkedIn) {
        final bool daycare = BookingKind.isDaycare(booking);
        final List<DailyCareReportCenterItem> items =
            DailyCareReportEligibility.expandBooking(
              shopId: normalizedShopId,
              booking: booking,
              setting: setting,
              today: careDay,
              canOperate: canOperate,
              daycare: daycare,
            );
        for (final DailyCareReportCenterItem item in items) {
          recordIds.add(item.id);
        }
      }

      if (recordIds.isEmpty) {
        emit();
        return;
      }

      for (final String recordId in recordIds) {
        recordSubscriptions.add(
          FirebaseFirestore.instance
              .collection('daily_care_records')
              .doc(recordId)
              .snapshots()
              .listen(
                (DocumentSnapshot<Map<String, dynamic>> snapshot) {
                  if (snapshot.exists) {
                    completedIds.add(recordId);
                    updatedAtById[recordId] = _readDate(
                      snapshot.data()?['updatedAt'] ??
                          snapshot.data()?['createdAt'],
                    );
                  } else {
                    completedIds.remove(recordId);
                    updatedAtById.remove(recordId);
                  }
                  emit();
                },
                onError: (_) {
                  hasError = true;
                  emit();
                },
              ),
        );
      }
      emit();
    }

    subscriptions.add(
      DailyCareSettingService.instance
          .streamSetting(normalizedShopId)
          .listen(
            (DailyCareSettingModel next) {
              setting = next;
              settingReady = true;
              hasError = false;
              unawaited(bindRecordListeners());
            },
            onError: (_) {
              hasError = true;
              emit();
            },
          ),
    );

    subscriptions.add(
      BookingService.instance
          .streamShopBookingsByStatus(
            shopId: normalizedShopId,
            status: 'checked_in',
          )
          .listen(
            (List<Map<String, dynamic>> next) {
              checkedIn = next;
              bookingsReady = true;
              hasError = false;
              unawaited(bindRecordListeners());
            },
            onError: (_) {
              hasError = true;
              emit();
            },
          ),
    );

    controller.onCancel = () async {
      for (final StreamSubscription<dynamic> subscription in subscriptions) {
        await subscription.cancel();
      }
      for (final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
          subscription
          in recordSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  static DailyCareReportCenterSnapshot buildTodaySnapshot({
    required String shopId,
    required DailyCareSettingModel setting,
    required List<Map<String, dynamic>> checkedIn,
    required bool canOperate,
    required DateTime today,
    Set<String> completedIds = const <String>{},
    Map<String, DateTime?> updatedAtById = const <String, DateTime?>{},
  }) {
    if (!setting.enabled) {
      return const DailyCareReportCenterSnapshot(settingEnabled: false);
    }
    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[];
    for (final Map<String, dynamic> booking in checkedIn) {
      try {
        final bool daycare = BookingKind.isDaycare(booking);
        items.addAll(
          DailyCareReportEligibility.expandBooking(
            shopId: shopId,
            booking: booking,
            setting: setting,
            today: today,
            canOperate: canOperate,
            daycare: daycare,
            completedIds: completedIds,
            updatedAtById: updatedAtById,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return DailyCareReportCenterSnapshot.fromItems(items, settingEnabled: true);
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
