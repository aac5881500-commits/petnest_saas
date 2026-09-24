// 檔案名稱：lib/core/services/daily_care_report_center_service.dart
// 功能說明：即時監聽本店應處理的住宿／安親每日回報，並以訂單 query 合併已存紀錄。

import 'dart:async';

import '../models/booking_kind.dart';
import '../models/daily_care_date_helper.dart';
import '../models/daily_care_photo_model.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_report_center_item.dart';
import '../models/daily_care_report_center_snapshot.dart';
import '../models/daily_care_session_status.dart';
import '../models/daily_care_setting_model.dart';
import 'booking_service.dart';
import 'daily_care_photo_service.dart';
import 'daily_care_record_service.dart';
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
    List<Map<String, dynamic>> bookings = <Map<String, dynamic>>[];
    List<DailyCareRecordModel> records = <DailyCareRecordModel>[];
    List<DailyCarePhotoModel> photos = <DailyCarePhotoModel>[];
    final Map<String, List<DailyCareRecordModel>> recordsByBooking =
        <String, List<DailyCareRecordModel>>{};
    final Map<String, List<DailyCarePhotoModel>> photosByBooking =
        <String, List<DailyCarePhotoModel>>{};

    bool settingReady = false;
    bool bookingsReady = false;
    bool recordsReady = false;
    bool photosReady = false;
    bool hasError = false;

    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];
    final List<StreamSubscription<List<DailyCareRecordModel>>>
    recordSubscriptions = <StreamSubscription<List<DailyCareRecordModel>>>[];
    final List<StreamSubscription<List<DailyCarePhotoModel>>>
    photoSubscriptions = <StreamSubscription<List<DailyCarePhotoModel>>>[];

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
      if (!settingReady || !bookingsReady || !recordsReady || !photosReady) {
        return;
      }
      controller.add(
        buildTodaySnapshot(
          shopId: normalizedShopId,
          setting: setting,
          checkedIn: bookings,
          canOperate: canOperate,
          today: today(),
          records: records,
          photos: photos,
        ),
      );
    }

    Future<void> bindRecordListeners() async {
      for (final StreamSubscription<List<DailyCareRecordModel>> subscription
          in recordSubscriptions) {
        await subscription.cancel();
      }
      for (final StreamSubscription<List<DailyCarePhotoModel>> subscription
          in photoSubscriptions) {
        await subscription.cancel();
      }
      recordSubscriptions.clear();
      photoSubscriptions.clear();
      recordsByBooking.clear();
      photosByBooking.clear();
      records = <DailyCareRecordModel>[];
      photos = <DailyCarePhotoModel>[];

      if (!setting.enabled && !setting.daycareEnabled) {
        recordsReady = true;
        photosReady = true;
        emit();
        return;
      }

      final List<Map<String, dynamic>> targets = <Map<String, dynamic>>[];
      for (final Map<String, dynamic> booking in bookings) {
        try {
          final bool daycare = BookingKind.isDaycare(booking);
          final List<DailyCareReportCenterItem> expected =
              DailyCareReportEligibility.expandBooking(
                shopId: normalizedShopId,
                booking: booking,
                setting: setting,
                today: today(),
                canOperate: canOperate,
                daycare: daycare,
                allWorkItems: true,
              );
          if (expected.isEmpty) {
            continue;
          }
          targets.add(booking);
        } catch (_) {
          continue;
        }
      }

      if (targets.isEmpty) {
        recordsReady = true;
        photosReady = true;
        emit();
        return;
      }

      recordsReady = false;
      photosReady = false;
      int remainingRecords = targets.length;
      int remainingPhotos = targets.length;
      void markRecordsReady() {
        if (remainingRecords > 0) {
          remainingRecords -= 1;
        }
        if (remainingRecords <= 0) {
          recordsReady = true;
        }
      }

      void markPhotosReady() {
        if (remainingPhotos > 0) {
          remainingPhotos -= 1;
        }
        if (remainingPhotos <= 0) {
          photosReady = true;
        }
      }

      for (final Map<String, dynamic> booking in targets) {
        final String bookingId = DailyCareReportEligibility.bookingIdOf(
          booking,
        );
        final bool daycare = BookingKind.isDaycare(booking);
        final List<DateTime> dates = daycare
            ? DailyCareReportEligibility.daycareCareDates(booking)
            : DailyCareReportEligibility.stayCareDates(
                booking,
                setting: setting,
              );
        final int sessions = DailyCareReportEligibility.resolvedEntitlement(
          booking: booking,
          setting: setting,
          daycare: daycare,
        ).finalReports;
        recordSubscriptions.add(
          DailyCareRecordService.instance
              .streamBookingRecords(
                bookingId: bookingId,
                shopId: normalizedShopId,
                careDates: dates,
                sessionCount: sessions < 1 ? 1 : sessions,
              )
              .listen(
                (List<DailyCareRecordModel> next) {
                  recordsByBooking[bookingId] = next;
                  records = recordsByBooking.values
                      .expand((List<DailyCareRecordModel> list) => list)
                      .toList();
                  markRecordsReady();
                  emit();
                },
                onError: (_) {
                  recordsByBooking[bookingId] = const <DailyCareRecordModel>[];
                  records = recordsByBooking.values
                      .expand((List<DailyCareRecordModel> list) => list)
                      .toList();
                  markRecordsReady();
                  emit();
                },
              ),
        );
        photoSubscriptions.add(
          DailyCarePhotoService.instance
              .streamBookingPhotos(
                bookingId: bookingId,
                shopId: normalizedShopId,
              )
              .listen(
                (List<DailyCarePhotoModel> next) {
                  photosByBooking[bookingId] = next;
                  photos = photosByBooking.values
                      .expand((List<DailyCarePhotoModel> list) => list)
                      .toList();
                  markPhotosReady();
                  emit();
                },
                onError: (_) {
                  photosByBooking[bookingId] = const <DailyCarePhotoModel>[];
                  photos = photosByBooking.values
                      .expand((List<DailyCarePhotoModel> list) => list)
                      .toList();
                  markPhotosReady();
                  emit();
                },
              ),
        );
      }
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
          .streamShopBookings(normalizedShopId)
          .listen(
            (List<Map<String, dynamic>> next) {
              bookings = next;
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
      for (final StreamSubscription<List<DailyCareRecordModel>> subscription
          in recordSubscriptions) {
        await subscription.cancel();
      }
      for (final StreamSubscription<List<DailyCarePhotoModel>> subscription
          in photoSubscriptions) {
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
    List<DailyCareRecordModel> records = const <DailyCareRecordModel>[],
    List<DailyCarePhotoModel> photos = const <DailyCarePhotoModel>[],
  }) {
    if (!setting.enabled && !setting.daycareEnabled) {
      return const DailyCareReportCenterSnapshot(settingEnabled: false);
    }

    final Set<String> filledKeys = <String>{...completedIds};
    final Map<String, DateTime?> filledUpdated = <String, DateTime?>{
      ...updatedAtById,
    };
    for (final DailyCareRecordModel record in records) {
      final int index = record.recordIndex ?? record.sessionIndex;
      filledKeys.addAll(
        DailyCareRecordService.matchKeys(
          bookingId: record.bookingId,
          recordDate: record.recordDate,
          sessionIndex: index,
          recordId: record.id,
        ),
      );
      for (final String key in DailyCareRecordService.matchKeys(
        bookingId: record.bookingId,
        recordDate: record.recordDate,
        sessionIndex: index,
        recordId: record.id,
      )) {
        filledUpdated[key] = record.updatedAt ?? filledUpdated[key];
      }
    }

    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[];
    for (final Map<String, dynamic> booking in checkedIn) {
      try {
        final bool daycare = BookingKind.isDaycare(booking);
        final List<DailyCareReportCenterItem> expanded =
            DailyCareReportEligibility.expandBooking(
              shopId: shopId,
              booking: booking,
              setting: setting,
              today: today,
              canOperate: canOperate,
              daycare: daycare,
              allWorkItems: true,
            );
        for (final DailyCareReportCenterItem item in expanded) {
          final Set<String> keys = DailyCareRecordService.matchKeys(
            bookingId: item.bookingId,
            recordDate: item.recordDate,
            sessionIndex: item.sessionIndex,
            recordId: item.id,
          );
          final bool completed = keys.any(filledKeys.contains);
          DateTime? updatedAt;
          for (final String key in keys) {
            final DateTime? value = filledUpdated[key];
            if (value != null) {
              updatedAt = value;
              break;
            }
          }
          items.add(
            item.copyWith(
              isCompleted: completed,
              updatedAt: updatedAt,
              photoCount: DailyCareSessionStatus.countPhotos(
                photos: photos,
                bookingId: item.bookingId,
                recordId: item.id,
                recordDate: item.recordDate,
                sessionIndex: item.sessionIndex,
                roomId: item.roomId,
              ),
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return DailyCareReportCenterSnapshot.fromItems(
      items,
      settingEnabled: setting.enabled || setting.daycareEnabled,
    );
  }
}
