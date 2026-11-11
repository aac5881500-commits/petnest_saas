// 檔案名稱：lib/core/services/shop_task_center_service.dart
// 功能說明：後台共用待辦中心
// 訂單、照護、攝影機分享各自監聽。照護只查該店當日已存在的紀錄。
// 不為缺少的場次建立空白文件，也不把單一分類錯誤當成全部失敗。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/shop_permission_keys.dart';
import '../models/booking_kind.dart';
import '../models/booking_medication_task.dart';
import '../models/booking_service_task.dart';
import '../models/daycare_settings_model.dart';
import '../models/camera_entry_watch.dart';
import '../models/daily_care_date_helper.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_report_center_item.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_stay_info.dart';
import '../models/shop_task_item.dart';
import 'booking_service.dart';
import 'camera_access_service.dart';
import 'daily_care_record_service.dart';
import 'daily_care_report_eligibility.dart';
import 'daily_care_setting_service.dart';
import 'shop_service.dart';
import 'daycare_enabled.dart';
import 'daycare_settings_service.dart';
import 'stay_booking_readiness.dart';

class ShopTaskAccess {
  const ShopTaskAccess({
    required this.canViewBookings,
    required this.canFillDailyCare,
    required this.canManageDevices,
  });

  final bool canViewBookings;
  final bool canFillDailyCare;
  final bool canManageDevices;

  static const ShopTaskAccess none = ShopTaskAccess(
    canViewBookings: false,
    canFillDailyCare: false,
    canManageDevices: false,
  );
}

/// 與寫入時相同的本地日曆日，只拿來比對該日已存在的照護紀錄。
DateTime careRecordQueryDay(DateTime taipeiDay) {
  return DateTime(taipeiDay.year, taipeiDay.month, taipeiDay.day);
}

/// 已完成的紀錄才算填完。文件不存在就不會出現在這個集合。
Set<String> completedCareRecordIds(Iterable<DailyCareRecordModel> records) {
  final Set<String> ids = <String>{};
  for (final DailyCareRecordModel record in records) {
    if (!record.countsAsCompleted) {
      continue;
    }
    ids.addAll(
      DailyCareRecordService.matchKeys(
        bookingId: record.bookingId,
        recordDate: record.recordDate,
        sessionIndex: record.sessionIndex,
        recordId: record.id,
      ),
    );
  }
  return ids;
}

String firebaseFailureCode(Object error) {
  if (error is FirebaseException) {
    return error.code;
  }
  return 'unknown';
}

class ShopTaskCenterService {
  ShopTaskCenterService._();

  static final ShopTaskCenterService instance = ShopTaskCenterService._();

  Future<ShopTaskAccess> loadAccess(String shopId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ShopTaskAccess.none;
    }
    final Map<String, dynamic>? member = await ShopService.instance
        .getUserMemberInShop(shopId: shopId, uid: user.uid);
    bool canManageDevices = ShopService.instance.hasPermission(
      member,
      ShopPermissionKeys.manageDevices,
    );
    if (!canManageDevices) {
      try {
        final Map<String, dynamic>? shop = await ShopService.instance.getShop(
          shopId,
        );
        if ((shop?['ownerUid'] ?? '').toString() == user.uid) {
          canManageDevices = true;
        }
      } catch (error) {
        debugPrint(
          'shopTaskCenter source=shops.ownerUid '
          'code=${firebaseFailureCode(error)} shopId=$shopId',
        );
      }
    }
    return ShopTaskAccess(
      canViewBookings: ShopService.instance.hasPermission(
        member,
        ShopPermissionKeys.manageBookings,
      ),
      canFillDailyCare: ShopService.instance.hasPermission(
        member,
        ShopPermissionKeys.manageRoomDashboard,
      ),
      canManageDevices: canManageDevices,
    );
  }

  Stream<ShopTaskCenterSnapshot> streamSnapshot({
    required String shopId,
    required bool canViewBookings,
    required bool canFillDailyCare,
    bool canManageDevices = false,
    DateTime? careDate,
  }) {
    final ShopTaskCenterBinding binding = ShopTaskCenterBinding(
      shopId: shopId,
      canViewBookings: canViewBookings,
      canFillDailyCare: canFillDailyCare,
      canManageDevices: canManageDevices,
      careDate: careDate,
    );
    binding.controller.onCancel = binding.close;
    return binding.snapshots;
  }

  ShopTaskCenterBinding openBinding({
    required String shopId,
    required bool canViewBookings,
    required bool canFillDailyCare,
    bool canManageDevices = false,
    DateTime? careDate,
  }) {
    return ShopTaskCenterBinding(
      shopId: shopId,
      canViewBookings: canViewBookings,
      canFillDailyCare: canFillDailyCare,
      canManageDevices: canManageDevices,
      careDate: careDate,
    );
  }
}

class ShopTaskCenterBinding {
  ShopTaskCenterBinding({
    required String shopId,
    required bool canViewBookings,
    required bool canFillDailyCare,
    bool canManageDevices = false,
    DateTime? careDate,
  }) : _shopId = shopId.trim(),
       _canViewBookings = canViewBookings,
       _canFillDailyCare = canFillDailyCare,
       _canManageDevices = canManageDevices,
       _careDate = careDate {
    if (_shopId.isEmpty) {
      controller.add(const ShopTaskCenterSnapshot());
      return;
    }
    _bookingLoading = canViewBookings;
    _careLoading = canFillDailyCare;
    if (canFillDailyCare) {
      _listenSetting();
    }
    if (canViewBookings || canFillDailyCare) _listenCheckedIn();
    if (canViewBookings) {
      _listenConfirmed();
      _listenServices();
      _listenPending();
      _medicationClock = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _emit(),
      );
    }
    if (canViewBookings || canManageDevices) _listenShop();
    _emit();
  }

  final String _shopId;
  final bool _canViewBookings;
  final bool _canFillDailyCare;
  final bool _canManageDevices;
  final DateTime? _careDate;
  final StreamController<ShopTaskCenterSnapshot> controller =
      StreamController<ShopTaskCenterSnapshot>();

  Stream<ShopTaskCenterSnapshot> get snapshots => controller.stream;

  DailyCareSettingModel _setting = const DailyCareSettingModel();
  Map<String, dynamic>? _shop;
  bool _shopLoading = false;
  String _shopError = '';
  StreamSubscription<Map<String, dynamic>?>? _shopSub;
  StreamSubscription<DaycareSettingsModel>? _legacyDaycareSub;
  bool _legacyDaycareOn = false;

  List<Map<String, dynamic>> _confirmed = [];
  bool _confirmedLoading = false;
  String _confirmedError = '';
  StreamSubscription<List<Map<String, dynamic>>>? _confirmedSub;
  void _listenConfirmed() {
    _confirmedSub?.cancel();
    _confirmedLoading = true;
    _confirmedError = '';
    _confirmedSub = BookingService.instance
        .streamShopBookingsByStatus(shopId: _shopId, status: 'confirmed')
        .listen(
          (items) {
            _confirmed = items;
            _confirmedLoading = false;
            _confirmedError = '';
            _emit();
          },
          onError: (Object error) {
            _confirmed = [];
            _confirmedLoading = false;
            _confirmedError = firebaseFailureCode(error);
            _emit();
          },
        );
  }

  bool _servicesOn = false;
  bool _servicesLoading = true;
  String _servicesError = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _servicesSub;
  void _listenServices() {
    _servicesSub?.cancel();
    _servicesLoading = true;
    _servicesError = '';
    _servicesSub = FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopId)
        .collection('addons')
        .doc('main')
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            _servicesOn =
                data?['enabled'] == true &&
                BookingServiceTask.maps(data?['dailyTimedServices']).isNotEmpty;
            _servicesLoading = false;
            _servicesError = '';
            _emit();
          },
          onError: (Object error) {
            _servicesOn = false;
            _servicesLoading = false;
            _servicesError = firebaseFailureCode(error);
            _emit();
          },
        );
  }

  void retryServices() {
    if (_closed || !_canViewBookings) return;
    _listenServices();
    _listenCheckedIn();
    _emit();
  }

  bool get _serviceEnabled => _canViewBookings && _servicesOn;

  bool get _medicationEnabled {
    final setting = _shop?['medicationSetting'];
    return _canViewBookings && setting is Map && setting['enabled'] == true;
  }

  bool get _cameraEnabled =>
      _canManageDevices && _shop != null && shopCameraSectionOn(_shop);
  bool get _stayEnabled =>
      _shop != null && StayBookingReadiness.requested(_shop!);
  bool get _daycareEnabled =>
      _shop != null &&
      DaycareEnabled.isOn(shop: _shop, settingsEnabled: _legacyDaycareOn);
  bool get _bookingEnabled =>
      _canViewBookings && (_stayEnabled || _daycareEnabled);
  bool get _careEnabled =>
      _canFillDailyCare &&
      _settingReady &&
      (_setting.enabled || _setting.daycareEnabled);

  void retryShop() {
    if (_closed || !(_canViewBookings || _canManageDevices)) return;
    _listenShop();
    _emit();
  }

  void _listenShop() {
    _shopSub?.cancel();
    _shopLoading = true;
    _shopError = '';
    _shopSub = ShopService.instance
        .streamShop(_shopId)
        .listen(
          (shop) {
            final wasCameraEnabled = _cameraEnabled;
            _shop = shop;
            _syncLegacyDaycare();
            _shopLoading = false;
            _shopError = '';
            if (_cameraEnabled && !wasCameraEnabled) {
              retryCamera();
            } else if (!_cameraEnabled) {
              _resetCamera();
            }
            _emit();
          },
          onError: (Object error) {
            _shop = null;
            _syncLegacyDaycare();
            _shopLoading = false;
            _shopError = firebaseFailureCode(error);
            _resetCamera();
            _emit();
          },
        );
  }

  void _syncLegacyDaycare() {
    if (!_canViewBookings ||
        _shop == null ||
        '${_shop?['daycareEnabled'] ?? ''}'.trim().isNotEmpty) {
      _legacyDaycareSub?.cancel();
      _legacyDaycareSub = null;
      _legacyDaycareOn = false;
      return;
    }
    _legacyDaycareSub ??= DaycareSettingsService.instance
        .stream(_shopId)
        .listen(
          (setting) {
            _legacyDaycareOn = setting.enabled;
            _emit();
          },
          onError: (Object error) {
            _legacyDaycareOn = false;
            _log('daycare_settings', firebaseFailureCode(error));
            _emit();
          },
        );
  }

  void _resetCamera() {
    _cameraSub?.cancel();
    _cameraSub = null;
    _cameraRequests = [];
    _cameraLoading = false;
    _cameraErrorCode = '';
    _cameraErrorSource = '';
  }

  List<Map<String, dynamic>> _checkedIn = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pending = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cameraRequests = <Map<String, dynamic>>[];
  Set<String> _filledRecordIds = <String>{};

  bool _settingReady = false;
  bool _checkedInReady = false;
  String _checkedInErrorCode = '';
  Timer? _medicationClock;
  bool _bookingLoading = false;
  bool _careLoading = false;
  bool _cameraLoading = false;
  String _bookingErrorCode = '';
  String _bookingErrorSource = '';
  String _careErrorCode = '';
  String _careErrorSource = '';
  String _cameraErrorCode = '';
  String _cameraErrorSource = '';

  int _careGeneration = 0;
  bool _closed = false;
  StreamSubscription<DailyCareSettingModel>? _settingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _checkedInSub;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cameraSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _careSub;

  void retryBooking() {
    if (_closed || !_canViewBookings) {
      return;
    }
    _bookingErrorCode = '';
    _bookingErrorSource = '';
    _bookingLoading = true;
    _listenPending();
    _emit();
  }

  void retryCare() {
    if (_closed || !_canFillDailyCare) {
      return;
    }
    _careErrorCode = '';
    _careErrorSource = '';
    _careLoading = true;
    _settingReady = false;
    _checkedInReady = false;
    _listenSetting();
    _listenCheckedIn();
    _emit();
  }

  void retryCamera() {
    if (_closed || !_cameraEnabled) {
      return;
    }
    _cameraErrorCode = '';
    _cameraErrorSource = '';
    _cameraLoading = true;
    _listenCamera();
    _emit();
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _confirmedSub?.cancel();
    _servicesSub?.cancel();
    _medicationClock?.cancel();
    _shopSub?.cancel();
    _legacyDaycareSub?.cancel();
    _careGeneration++;
    _settingSub?.cancel();
    _checkedInSub?.cancel();
    _pendingSub?.cancel();
    _cameraSub?.cancel();
    _careSub?.cancel();
    _settingSub = null;
    _checkedInSub = null;
    _pendingSub = null;
    _cameraSub = null;
    _careSub = null;
    if (!controller.isClosed) {
      controller.close();
    }
  }

  void _listenSetting() {
    _settingSub?.cancel();
    _settingSub = DailyCareSettingService.instance
        .streamSetting(_shopId)
        .listen(
          (DailyCareSettingModel next) {
            _setting = next;
            _settingReady = true;
            _bindCare();
          },
          onError: (Object error) {
            _settingReady = false;
            _failCare(error, 'daily_care_settings');
          },
        );
  }

  void retryMedication() {
    if (_closed || !_canViewBookings) return;
    _listenConfirmed();
    _listenPending();
    if (_canFillDailyCare) {
      retryCare();
    } else {
      _listenCheckedIn();
      _emit();
    }
  }

  void _listenCheckedIn() {
    _checkedInErrorCode = '';
    _checkedInReady = false;
    _checkedInSub?.cancel();
    _checkedInSub = BookingService.instance
        .streamShopBookingsByStatus(shopId: _shopId, status: 'checked_in')
        .listen(
          (List<Map<String, dynamic>> next) {
            _checkedIn = next;
            _checkedInReady = true;
            _checkedInErrorCode = '';
            _bindCare();
            _emit();
          },
          onError: (Object error) {
            _checkedInReady = false;
            _checkedInErrorCode = firebaseFailureCode(error);
            if (_canFillDailyCare) {
              _failCare(error, 'bookings.checked_in');
            } else {
              _emit();
            }
          },
        );
  }

  void _listenPending() {
    _pendingSub?.cancel();
    _pendingSub = BookingService.instance
        .streamShopBookingsByStatus(shopId: _shopId, status: 'pending')
        .listen(
          (List<Map<String, dynamic>> next) {
            _pending = next;
            _bookingLoading = false;
            _bookingErrorCode = '';
            _bookingErrorSource = '';
            _emit();
          },
          onError: (Object error) {
            _bookingLoading = false;
            _bookingErrorCode = firebaseFailureCode(error);
            _bookingErrorSource = 'bookings.pending';
            _log(_bookingErrorSource, _bookingErrorCode);
            _emit();
          },
        );
  }

  void _listenCamera() {
    _cameraSub?.cancel();
    _cameraSub = CameraAccessService.instance
        .watchShopActiveRequests(_shopId)
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            _cameraRequests = snapshot.docs.map((
              QueryDocumentSnapshot<Map<String, dynamic>> doc,
            ) {
              return <String, dynamic>{
                'requestId': doc.id,
                'status': doc.data()['status'],
                'roomName': doc.data()['roomName'],
                'customerName': doc.data()['customerName'],
                'provider': doc.data()['provider'],
                'createdAt': doc.data()['createdAt'],
              };
            }).toList();
            _cameraLoading = false;
            _cameraErrorCode = '';
            _cameraErrorSource = '';
            _emit();
          },
          onError: (Object error) {
            _cameraLoading = false;
            _cameraErrorCode = firebaseFailureCode(error);
            _cameraErrorSource = 'camera_access_requests.active';
            _log(_cameraErrorSource, _cameraErrorCode);
            _emit();
          },
        );
  }

  void _bindCare() {
    final int token = ++_careGeneration;
    _careSub?.cancel();
    _careSub = null;
    if (_closed || !_canFillDailyCare) {
      return;
    }
    if (!_settingReady || !_checkedInReady) {
      return;
    }
    if (_careErrorCode.isNotEmpty) {
      _emit();
      return;
    }
    if (!_careEnabled) {
      _filledRecordIds = <String>{};
      _careLoading = false;
      _careErrorCode = '';
      _careErrorSource = '';
      _emit();
      return;
    }
    _careLoading = true;
    _careErrorCode = '';
    _careErrorSource = '';
    final DateTime today = careRecordQueryDay(
      _careDate ?? DailyCareDateHelper.todayInTaipei(),
    );
    _careSub = FirebaseFirestore.instance
        .collection('daily_care_records')
        .where('shopId', isEqualTo: _shopId)
        .where('recordDate', isEqualTo: Timestamp.fromDate(today))
        .snapshots()
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (token != _careGeneration || _closed) {
              return;
            }
            _filledRecordIds = completedCareRecordIds(
              snapshot.docs.map((
                QueryDocumentSnapshot<Map<String, dynamic>> doc,
              ) {
                return DailyCareRecordModel.fromMap(
                  id: doc.id,
                  map: doc.data(),
                );
              }),
            );
            _careLoading = false;
            _careErrorCode = '';
            _careErrorSource = '';
            _emit();
          },
          onError: (Object error) {
            if (token != _careGeneration || _closed) {
              return;
            }
            _failCare(error, 'daily_care_records.shopId+recordDate');
          },
        );
  }

  void _failCare(Object error, String source) {
    _careGeneration++;
    _careSub?.cancel();
    _careSub = null;
    _careLoading = false;
    _careErrorCode = firebaseFailureCode(error);
    _careErrorSource = source;
    _log(source, _careErrorCode);
    _emit();
  }

  void _log(String source, String code) {
    debugPrint('shopTaskCenter source=$source code=$code shopId=$_shopId');
  }

  void _emit() {
    if (_closed || controller.isClosed) {
      return;
    }
    controller.add(_buildSnapshot());
  }

  String _petPhoto(Map<String, dynamic> booking, String petId) {
    final pet = BookingServiceTask.maps(
      booking['pets'],
    ).where((p) => '${p['petId'] ?? p['id'] ?? ''}' == petId).firstOrNull;
    return '${pet?['photoUrl'] ?? pet?['imageUrl'] ?? ''}';
  }

  ShopTaskCenterSnapshot _buildSnapshot() {
    final DateTime today = DailyCareDateHelper.dateOnly(
      _careDate ?? DailyCareDateHelper.todayInTaipei(),
    );
    final List<ShopTaskItem> items = <ShopTaskItem>[];
    final Map<String, ShopRoomCareProgress> roomProgress =
        <String, ShopRoomCareProgress>{};
    final Set<String> checkedInRooms = <String>{};
    final bool careReady =
        _canFillDailyCare && !_careLoading && _careErrorCode.isEmpty;

    if (_checkedInReady) {
      for (final Map<String, dynamic> booking in _checkedIn) {
        final String roomId = (booking['roomId'] ?? '').toString().trim();
        if (roomId.isNotEmpty) {
          checkedInRooms.add(roomId);
        }
      }
    }

    if (careReady && _careEnabled) {
      for (final Map<String, dynamic> booking in _checkedIn) {
        try {
          final bool daycare = BookingKind.isDaycare(booking);
          final List<DailyCareReportCenterItem> sessions =
              DailyCareReportEligibility.expandBooking(
                shopId: _shopId,
                booking: booking,
                setting: _setting,
                today: today,
                canOperate: _canFillDailyCare,
                daycare: daycare,
                completedIds: _filledRecordIds,
              );
          if (sessions.isEmpty) {
            continue;
          }
          int filled = 0;
          for (final DailyCareReportCenterItem session in sessions) {
            if (session.isCompleted) {
              filled++;
              continue;
            }
            items.add(
              ShopTaskItem(
                id: 'dailyCare_${session.id}',
                type: ShopTaskType.dailyCare,
                shopId: _shopId,
                title: [
                  session.placeLabel,
                  if (session.petNamesText.isNotEmpty) session.petNamesText,
                ].join(' '),
                subtitle: session.sessionName,
                statusLabel: '待填',
                createdAt: _readDate(
                  booking['checkedInAt'] ?? booking['checkInAt'],
                ),
                priority: session.sessionIndex,
                iconKey: 'dailyCare',
                targetType: 'dailyCareRecord',
                targetId: session.id,
                canOpen: _canFillDailyCare,
                metadata: <String, dynamic>{
                  'bookingId': session.bookingId,
                  'roomId': session.roomId,
                  'roomName': session.roomName,
                  'sessionIndex': session.sessionIndex,
                  'sessionName': session.sessionName,
                  'serviceType': session.serviceType,
                  'petIds': session.petIds,
                  'entitlement': session.entitlement.toMap(),
                  'recordDateYear': today.year,
                  'recordDateMonth': today.month,
                  'recordDateDay': today.day,
                },
              ),
            );
          }
          final String roomId = sessions.first.roomId;
          if (roomId.isNotEmpty) {
            roomProgress[roomId] = ShopRoomCareProgress(
              roomId: roomId,
              bookingId: sessions.first.bookingId,
              filled: filled,
              total: sessions.length,
            );
          }
        } catch (_) {
          continue;
        }
      }
    }

    if (_bookingEnabled && _bookingErrorCode.isEmpty && !_bookingLoading) {
      for (final Map<String, dynamic> booking in _pending) {
        if (BookingKind.isDaycare(booking) ? !_daycareEnabled : !_stayEnabled) {
          continue;
        }
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
            shopId: _shopId,
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

    if (_cameraEnabled && _cameraErrorCode.isEmpty && !_cameraLoading) {
      items.addAll(
        cameraOwnerTasks(shopId: _shopId, requests: _cameraRequests),
      );
    }

    if (_serviceEnabled && _checkedInReady) {
      final now = DateTime.now();
      final date = BookingMedicationTask.dateKey(
        BookingMedicationTask.taipei(now),
      );
      for (final booking in _checkedIn.where(BookingServiceTask.canRecord)) {
        final id = '${booking['bookingId'] ?? ''}';
        if (id.isEmpty) continue;
        for (final task in BookingServiceTask.fromBooking(booking)) {
          if (!task.pending) continue;
          final urgency = task.urgencyAt(now);
          if (task.day.compareTo(date) > 0 && urgency != 'soon') continue;
          items.add(
            ShopTaskItem(
              id: 'service_${id}_${task.id}',
              type: ShopTaskType.timedService,
              shopId: _shopId,
              title:
                  '${BookingMedicationTask.timeLabel(task.scheduledAt)} · ${task.pet}',
              subtitle:
                  '${task.title} · ${booking['roomName'] ?? ''}${task.day != date ? ' · ${task.day}' : ''}',
              statusLabel: task.petId.isEmpty
                  ? '寵物資料待核對'
                  : urgency == 'due'
                  ? '已到點・尚未記錄'
                  : urgency == 'soon'
                  ? '即將到點'
                  : '待到點',
              priority: urgency == 'due'
                  ? -3
                  : urgency == 'soon'
                  ? -2
                  : 25,
              createdAt: task.scheduledAt,
              targetType: 'timedService',
              targetId: id,
              metadata: {
                'needsIdentity': task.petId.isEmpty,
                'petPhoto': _petPhoto(booking, task.petId),
                'taskId': task.id,
                'urgency': urgency,
                'scheduledAt': task.scheduledAt.toUtc().toIso8601String(),
              },
            ),
          );
        }
      }
    }

    if (_medicationEnabled) {
      final unique = <String, Map<String, dynamic>>{
        for (final b in [..._pending, ..._confirmed, ..._checkedIn])
          '${b['bookingId'] ?? ''}': b,
      };
      for (final entry in unique.entries) {
        final b = entry.value;
        final raw = b['medication'];
        final legacy = b['medicationRequest'];
        final state = raw is Map
            ? '${raw['state'] ?? ''}'
            : legacy is Map && legacy.isNotEmpty
            ? 'pending_shop'
            : '';
        if (entry.key.isEmpty ||
            !{'pending_shop', 'pending_customer'}.contains(state)) {
          continue;
        }
        final customer = state == 'pending_customer';
        items.add(
          ShopTaskItem(
            id: 'medication_review_${entry.key}',
            type: ShopTaskType.medication,
            shopId: _shopId,
            title: '${b['customerName'] ?? '訂單'} · 用藥安排',
            subtitle: customer
                ? '等待家長確認藥品、時程與費用，尚未開始執行'
                : '核對藥品、用量、時程與費用，再送給家長確認',
            statusLabel: customer ? '待客戶確認' : '待店家確認',
            priority: customer ? 30 : 15,
            targetType: 'booking',
            targetId: entry.key,
            metadata: {'reviewMedication': true, 'awaitingCustomer': customer},
          ),
        );
      }
    }

    if (_medicationEnabled && _checkedInReady) {
      final now = DateTime.now();
      final date = BookingMedicationTask.dateKey(
        BookingMedicationTask.taipei(now),
      );
      for (final booking in _checkedIn.where(BookingMedicationTask.canRecord)) {
        final id = '${booking['bookingId'] ?? ''}';
        if (id.isEmpty) continue;
        for (final task in BookingMedicationTask.fromBooking(booking)) {
          if (!task.pending) continue;
          final urgency = task.urgencyAt(now);
          if (task.day.compareTo(date) > 0 && urgency != 'soon') continue;
          final due = urgency == 'due';
          final soon = urgency == 'soon';
          final time = BookingMedicationTask.timeLabel(task.scheduledAt);
          final room = '${booking['roomName'] ?? ''}'.trim();
          items.add(
            ShopTaskItem(
              id: 'medication_${id}_${task.id}',
              type: ShopTaskType.medication,
              shopId: _shopId,
              title: '$time · ${task.pet}',
              subtitle: [
                task.types,
                if (room.isNotEmpty) room,
                if (task.day != date) task.day,
              ].join(' · '),
              statusLabel: due
                  ? '已到點・尚未完成'
                  : soon
                  ? '即將到點'
                  : '待到點',
              priority: due
                  ? -3
                  : soon
                  ? -2
                  : 25,
              createdAt: task.scheduledAt,
              targetType: 'medication',
              targetId: id,
              metadata: {
                'petPhoto': _petPhoto(booking, task.petId),
                'taskId': task.id,
                'urgency': urgency,
                'scheduledAt': task.scheduledAt.toUtc().toIso8601String(),
              },
            ),
          );
        }
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
      if ({
            ShopTaskType.medication,
            ShopTaskType.timedService,
          }.contains(a.type) &&
          {
            ShopTaskType.medication,
            ShopTaskType.timedService,
          }.contains(b.type)) {
        return aTime.compareTo(bTime);
      }
      return bTime.compareTo(aTime);
    });

    return ShopTaskCenterSnapshot(
      items: items,
      roomCareProgress: roomProgress,
      checkedInRoomCount: checkedInRooms.isEmpty
          ? _checkedIn.length
          : checkedInRooms.length,
      settingsLoading:
          (_canViewBookings && _servicesLoading) ||
          _shopLoading ||
          (_canFillDailyCare && !_settingReady && _careLoading),
      settingsErrorCode: _shopError,
      serviceEnabled: _serviceEnabled,
      serviceLoading:
          _canViewBookings &&
          (_servicesLoading ||
              (_servicesOn && !_checkedInReady && _checkedInErrorCode.isEmpty)),
      serviceErrorCode: _servicesError.isNotEmpty
          ? _servicesError
          : _servicesOn
          ? _checkedInErrorCode
          : '',
      medicationEnabled: _medicationEnabled,
      medicationLoading:
          _medicationEnabled &&
          (_confirmedLoading ||
              _bookingLoading ||
              (!_checkedInReady && _checkedInErrorCode.isEmpty)),
      medicationErrorCode: _medicationEnabled
          ? (_checkedInErrorCode.isNotEmpty
                ? _checkedInErrorCode
                : _confirmedError.isNotEmpty
                ? _confirmedError
                : _bookingErrorCode)
          : '',
      bookingEnabled: _bookingEnabled,
      bookingLoading: _bookingLoading,
      bookingErrorCode: _bookingEnabled ? _bookingErrorCode : '',
      bookingErrorSource: _bookingErrorSource,
      careEnabled: _careEnabled,
      careLoading: _careLoading,
      careErrorCode: _careErrorCode,
      careErrorSource: _careErrorSource,
      cameraEnabled:
          _cameraEnabled &&
          (_shop?['showCameraSection'] == true ||
              items.any((item) => item.type == ShopTaskType.cameraShare)),
      cameraLoading: _cameraLoading,
      cameraErrorCode: _shop?['showCameraSection'] == true
          ? _cameraErrorCode
          : '',
      cameraErrorSource: _cameraErrorSource,
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
    return readShopTaskDate(value);
  }
}
