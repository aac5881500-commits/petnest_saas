// lib/core/services/shop_task_center_service.dart
// 🐾 後台共用待辦中心
// 依 checked_in / pending 訂單與固定 Daily Care record ID 即時計算。
// 不掃全店 daily care、不寫 notification document。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_care_date_helper.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_stay_info.dart';
import '../models/shop_task_item.dart';
import 'booking_service.dart';
import 'daily_care_record_service.dart';
import 'daily_care_setting_service.dart';

class ShopTaskCenterService {
  ShopTaskCenterService._();

  static final ShopTaskCenterService instance = ShopTaskCenterService._();

  Stream<ShopTaskCenterSnapshot> streamSnapshot({
    required String shopId,
    required bool canViewBookings,
    required bool canFillDailyCare,
    DateTime? careDate,
  }) {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return Stream<ShopTaskCenterSnapshot>.value(
        const ShopTaskCenterSnapshot(),
      );
    }

    final StreamController<ShopTaskCenterSnapshot> controller =
        StreamController<ShopTaskCenterSnapshot>();

    DailyCareSettingModel setting = const DailyCareSettingModel();
    List<Map<String, dynamic>> checkedIn = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> pending = <Map<String, dynamic>>[];
    final Set<String> filledRecordIds = <String>{};

    bool settingReady = false;
    bool checkedInReady = false;
    bool pendingReady = !canViewBookings;
    bool hasError = false;

    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];
    final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
    recordSubscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

    void emit() {
      if (controller.isClosed) {
        return;
      }
      if (hasError) {
        controller.add(ShopTaskCenterSnapshot.error);
        return;
      }
      if (!settingReady || !checkedInReady || !pendingReady) {
        return;
      }
      controller.add(
        _buildSnapshot(
          shopId: normalizedShopId,
          setting: setting,
          checkedIn: checkedIn,
          pending: pending,
          filledRecordIds: filledRecordIds,
          canViewBookings: canViewBookings,
          canFillDailyCare: canFillDailyCare,
          careDate: careDate,
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
      filledRecordIds.clear();

      if (!setting.enabled) {
        emit();
        return;
      }

      final DateTime today = DailyCareDateHelper.dateOnly(
        careDate ?? DailyCareDateHelper.todayInTaipei(),
      );
      final DailyCareRecordService records = DailyCareRecordService.instance;

      for (final Map<String, dynamic> booking in checkedIn) {
        final DateTime? start = _readDate(booking['startDate']);
        final DateTime? end = _readDate(booking['endDate']);
        if (!DailyCareDateHelper.isCareDate(
          date: today,
          checkIn: start,
          checkOut: end,
        )) {
          continue;
        }

        final String bookingId = (booking['bookingId'] ?? '').toString().trim();
        if (bookingId.isEmpty) {
          continue;
        }

        for (int index = 0; index < setting.sessionCount; index++) {
          final String recordId = records.buildRecordId(
            bookingId: bookingId,
            recordDate: today,
            sessionIndex: index,
          );
          recordSubscriptions.add(
            FirebaseFirestore.instance
                .collection('daily_care_records')
                .doc(recordId)
                .snapshots()
                .listen(
                  (DocumentSnapshot<Map<String, dynamic>> snapshot) {
                    if (snapshot.exists) {
                      filledRecordIds.add(recordId);
                    } else {
                      filledRecordIds.remove(recordId);
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
              bindRecordListeners();
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
              checkedInReady = true;
              hasError = false;
              bindRecordListeners();
            },
            onError: (_) {
              hasError = true;
              emit();
            },
          ),
    );

    if (canViewBookings) {
      subscriptions.add(
        BookingService.instance
            .streamShopBookingsByStatus(
              shopId: normalizedShopId,
              status: 'pending',
            )
            .listen(
              (List<Map<String, dynamic>> next) {
                pending = next;
                pendingReady = true;
                hasError = false;
                emit();
              },
              onError: (_) {
                hasError = true;
                emit();
              },
            ),
      );
    }

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

  ShopTaskCenterSnapshot _buildSnapshot({
    required String shopId,
    required DailyCareSettingModel setting,
    required List<Map<String, dynamic>> checkedIn,
    required List<Map<String, dynamic>> pending,
    required Set<String> filledRecordIds,
    required bool canViewBookings,
    required bool canFillDailyCare,
    DateTime? careDate,
  }) {
    final DateTime today = DailyCareDateHelper.dateOnly(
      careDate ?? DailyCareDateHelper.todayInTaipei(),
    );
    final List<ShopTaskItem> items = <ShopTaskItem>[];
    final Map<String, ShopRoomCareProgress> roomProgress =
        <String, ShopRoomCareProgress>{};
    final Set<String> checkedInRooms = <String>{};

    if (setting.enabled) {
      for (final Map<String, dynamic> booking in checkedIn) {
        final DateTime? start = _readDate(booking['startDate']);
        final DateTime? end = _readDate(booking['endDate']);
        if (!DailyCareDateHelper.isCareDate(
          date: today,
          checkIn: start,
          checkOut: end,
        )) {
          continue;
        }

        final String bookingId = (booking['bookingId'] ?? '').toString().trim();
        final String roomId = (booking['roomId'] ?? '').toString().trim();
        if (bookingId.isEmpty) {
          continue;
        }
        if (roomId.isNotEmpty) {
          checkedInRooms.add(roomId);
        }

        final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(
          booking,
        );
        int filled = 0;
        for (int index = 0; index < setting.sessionCount; index++) {
          final String recordId = DailyCareRecordService.instance.buildRecordId(
            bookingId: bookingId,
            recordDate: today,
            sessionIndex: index,
          );
          if (filledRecordIds.contains(recordId)) {
            filled++;
            continue;
          }

          items.add(
            ShopTaskItem(
              id: 'dailyCare_$recordId',
              type: ShopTaskType.dailyCare,
              shopId: shopId,
              title: [
                if (stay.roomName.isNotEmpty) stay.roomName,
                if (stay.pets.isNotEmpty) stay.petNamesText,
              ].join(' '),
              subtitle: setting.sessionLabel(index),
              statusLabel: '待填',
              createdAt: _readDate(
                booking['checkedInAt'] ?? booking['checkInAt'],
              ),
              priority: index,
              iconKey: 'dailyCare',
              targetType: 'dailyCareRecord',
              targetId: recordId,
              canOpen: canFillDailyCare,
              metadata: <String, dynamic>{
                'bookingId': bookingId,
                'roomId': roomId,
                'roomName': stay.roomName,
                'sessionIndex': index,
                'sessionName': setting.sessionLabel(index),
                'recordDateYear': today.year,
                'recordDateMonth': today.month,
                'recordDateDay': today.day,
              },
            ),
          );
        }

        if (roomId.isNotEmpty) {
          roomProgress[roomId] = ShopRoomCareProgress(
            roomId: roomId,
            bookingId: bookingId,
            filled: filled,
            total: setting.sessionCount,
          );
        }
      }
    } else {
      for (final Map<String, dynamic> booking in checkedIn) {
        final String roomId = (booking['roomId'] ?? '').toString().trim();
        if (roomId.isNotEmpty) {
          checkedInRooms.add(roomId);
        }
      }
    }

    if (canViewBookings) {
      for (final Map<String, dynamic> booking in pending) {
        final String status = (booking['status'] ?? '').toString().trim();
        if (status == 'cancelled' || status == 'completed') {
          continue;
        }

        final String bookingId = (booking['bookingId'] ?? '').toString().trim();
        if (bookingId.isEmpty) {
          continue;
        }

        final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(
          booking,
        );
        final String customerName = (booking['customerName'] ?? '')
            .toString()
            .trim();
        final String code = _bookingShortCode(booking);

        items.add(
          ShopTaskItem(
            id: 'booking_$bookingId',
            type: ShopTaskType.booking,
            shopId: shopId,
            title: '新預約',
            subtitle: [
              code,
              if (customerName.isNotEmpty) customerName,
            ].join(' · '),
            statusLabel: '待確認',
            createdAt: _readDate(booking['createdAt']),
            priority: 20,
            iconKey: 'booking',
            targetType: 'booking',
            targetId: bookingId,
            canOpen: true,
            metadata: <String, dynamic>{
              'bookingId': bookingId,
              'stayDates': stay.stayDateText,
              'petNames': stay.petNamesText,
              'createdLabel': _createdLabel(_readDate(booking['createdAt'])),
            },
          ),
        );
      }
    }

    items.sort((ShopTaskItem a, ShopTaskItem b) {
      final int typeCompare = a.priority.compareTo(b.priority);
      if (typeCompare != 0) {
        return typeCompare;
      }
      final DateTime aTime =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return ShopTaskCenterSnapshot(
      items: items,
      roomCareProgress: roomProgress,
      checkedInRoomCount: checkedInRooms.isEmpty
          ? checkedIn.length
          : checkedInRooms.length,
    );
  }

  static String _bookingShortCode(Map<String, dynamic> booking) {
    final String code = (booking['bookingCode'] ?? '').toString().trim();
    if (code.contains('-')) {
      return '#${code.split('-').last}';
    }
    if (code.isNotEmpty) {
      return '#$code';
    }
    final String id = (booking['bookingId'] ?? '').toString();
    if (id.length >= 6) {
      return '#${id.substring(id.length - 6)}';
    }
    return id.isEmpty ? '#' : '#$id';
  }

  static String _createdLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return '';
    }
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return '剛剛建立';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分鐘前建立';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小時前建立';
    }
    return '${createdAt.month}/${createdAt.day} 建立';
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
