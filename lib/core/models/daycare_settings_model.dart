// lib/core/models/daycare_settings_model.dart
// 🐾 臨托店家設定：shops/{shopId}/daycare_settings/main

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';

class DaycareOccupancyModes {
  DaycareOccupancyModes._();

  static const String slot = 'slot';
  static const String fullDay = 'full_day';
}

class DaycareDepositTypes {
  DaycareDepositTypes._();

  static const String none = 'none';
  static const String fixed = 'fixed';
  static const String percent = 'percent';
  static const String full = 'full';
  static const String staffDecide = 'staff_decide';
}

class DaycareRoomTypeSetting {
  const DaycareRoomTypeSetting({
    required this.roomTypeId,
    this.enabled = false,
    this.maxPets = 1,
    this.requiresRoom = true,
    this.shareWithAccommodation = true,
    this.occupancyMode = DaycareOccupancyModes.slot,
    this.markCleaningOnComplete = true,
    this.blockUntilCleaned = true,
    this.allowNonOverlappingSameDay = true,
  });

  final String roomTypeId;
  final bool enabled;
  final int maxPets;
  final bool requiresRoom;
  final bool shareWithAccommodation;
  final String occupancyMode;
  final bool markCleaningOnComplete;
  final bool blockUntilCleaned;
  final bool allowNonOverlappingSameDay;

  factory DaycareRoomTypeSetting.fromMap(
    Map<String, dynamic> map, {
    String roomTypeId = '',
  }) {
    return DaycareRoomTypeSetting(
      roomTypeId: (map['roomTypeId'] ?? roomTypeId).toString(),
      enabled: map['enabled'] == true,
      maxPets: _toInt(map['maxPets'], 1).clamp(1, 20),
      requiresRoom: map['requiresRoom'] != false,
      shareWithAccommodation: map['shareWithAccommodation'] != false,
      occupancyMode: (map['occupancyMode'] ?? DaycareOccupancyModes.slot)
          .toString(),
      markCleaningOnComplete: map['markCleaningOnComplete'] != false,
      blockUntilCleaned: map['blockUntilCleaned'] != false,
      allowNonOverlappingSameDay: map['allowNonOverlappingSameDay'] != false,
    );
  }

  DaycareRoomTypeSetting copyWith({
    bool? enabled,
    int? maxPets,
    bool? requiresRoom,
    bool? shareWithAccommodation,
    String? occupancyMode,
    bool? markCleaningOnComplete,
    bool? blockUntilCleaned,
    bool? allowNonOverlappingSameDay,
  }) {
    return DaycareRoomTypeSetting(
      roomTypeId: roomTypeId,
      enabled: enabled ?? this.enabled,
      maxPets: maxPets ?? this.maxPets,
      requiresRoom: requiresRoom ?? this.requiresRoom,
      shareWithAccommodation:
          shareWithAccommodation ?? this.shareWithAccommodation,
      occupancyMode: occupancyMode ?? this.occupancyMode,
      markCleaningOnComplete:
          markCleaningOnComplete ?? this.markCleaningOnComplete,
      blockUntilCleaned: blockUntilCleaned ?? this.blockUntilCleaned,
      allowNonOverlappingSameDay:
          allowNonOverlappingSameDay ?? this.allowNonOverlappingSameDay,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'roomTypeId': roomTypeId,
      'enabled': enabled,
      'maxPets': maxPets,
      'requiresRoom': requiresRoom,
      'shareWithAccommodation': shareWithAccommodation,
      'occupancyMode': occupancyMode == DaycareOccupancyModes.fullDay
          ? DaycareOccupancyModes.fullDay
          : DaycareOccupancyModes.slot,
      'markCleaningOnComplete': markCleaningOnComplete,
      'blockUntilCleaned': blockUntilCleaned,
      'allowNonOverlappingSameDay': allowNonOverlappingSameDay,
    };
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}

class DaycareSettingsModel {
  const DaycareSettingsModel({
    this.enabled = false,
    this.serviceName = '寵物臨托',
    this.intro = '',
    this.requiresManualConfirm = true,
    this.allowSameDay = true,
    this.minAdvanceHours = 0,
    this.weekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
    this.openTime = '09:00',
    this.closeTime = '18:00',
    this.earliestDropOff = '09:00',
    this.latestPickUp = '18:00',
    this.slotMinutes = 30,
    this.minDurationMinutes = 60,
    this.maxDurationMinutes = 480,
    this.forbidOvernight = true,
    this.dailyMaxPets = 10,
    this.blockOutsideHours = true,
    this.showRemainingSlots = true,
    this.allowedPetTypes = const <String>['cat'],
    this.minPets = 1,
    this.maxPets = 3,
    this.requireVaccine = false,
    this.allowUnneutered = true,
    this.allowStaffRejectSpecial = true,
    this.blockBlacklisted = true,
    this.requireRoomType = true,
    this.allowedAddonIds = const <String>[],
    this.roomTypes = const <DaycareRoomTypeSetting>[],
    this.plans = const <DaycarePlanModel>[],
    this.depositType = DaycareDepositTypes.none,
    this.depositValue = 0,
    this.allowCash = true,
    this.allowCoupon = false,
    this.refundDepositOnCancel = true,
    this.forfeitDepositOnNoShow = true,
    this.overtimeGraceMinutes = 15,
    this.pointsEarnEnabled = false,
    this.pointsSpendEnabled = false,
    this.pointsIncludeAddons = false,
    this.pointsIncludeSurcharge = false,
    this.pointsIncludeOvertime = false,
    this.updatedAt,
  });

  final bool enabled;
  final String serviceName;
  final String intro;
  final bool requiresManualConfirm;
  final bool allowSameDay;
  final int minAdvanceHours;
  final List<int> weekdays;
  final String openTime;
  final String closeTime;
  final String earliestDropOff;
  final String latestPickUp;
  final int slotMinutes;
  final int minDurationMinutes;
  final int maxDurationMinutes;
  final bool forbidOvernight;
  final int dailyMaxPets;
  final bool blockOutsideHours;
  final bool showRemainingSlots;
  final List<String> allowedPetTypes;
  final int minPets;
  final int maxPets;
  final bool requireVaccine;
  final bool allowUnneutered;
  final bool allowStaffRejectSpecial;
  final bool blockBlacklisted;
  final bool requireRoomType;
  final List<String> allowedAddonIds;
  final List<DaycareRoomTypeSetting> roomTypes;
  final List<DaycarePlanModel> plans;
  final String depositType;
  final int depositValue;
  final bool allowCash;
  final bool allowCoupon;
  final bool refundDepositOnCancel;
  final bool forfeitDepositOnNoShow;
  final int overtimeGraceMinutes;
  final bool pointsEarnEnabled;
  final bool pointsSpendEnabled;
  final bool pointsIncludeAddons;
  final bool pointsIncludeSurcharge;
  final bool pointsIncludeOvertime;
  final DateTime? updatedAt;

  factory DaycareSettingsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DaycareSettingsModel();
    }
    return DaycareSettingsModel(
      enabled: map['enabled'] == true,
      serviceName: _str(map['serviceName'], '寵物臨托'),
      intro: _str(map['intro'], ''),
      requiresManualConfirm: map['requiresManualConfirm'] != false,
      allowSameDay: map['allowSameDay'] != false,
      minAdvanceHours: _int(map['minAdvanceHours'], 0).clamp(0, 72),
      weekdays: _intList(map['weekdays'], const <int>[1, 2, 3, 4, 5, 6, 7]),
      openTime: _time(map['openTime'], '09:00'),
      closeTime: _time(map['closeTime'], '18:00'),
      earliestDropOff: _time(map['earliestDropOff'], '09:00'),
      latestPickUp: _time(map['latestPickUp'], '18:00'),
      slotMinutes: _slot(map['slotMinutes']),
      minDurationMinutes: _int(map['minDurationMinutes'], 60).clamp(30, 1440),
      maxDurationMinutes: _int(map['maxDurationMinutes'], 480).clamp(30, 1440),
      forbidOvernight: map['forbidOvernight'] != false,
      dailyMaxPets: _int(map['dailyMaxPets'], 10).clamp(1, 200),
      blockOutsideHours: map['blockOutsideHours'] != false,
      showRemainingSlots: map['showRemainingSlots'] != false,
      allowedPetTypes: _stringList(map['allowedPetTypes'], const <String>[
        'cat',
      ]),
      minPets: _int(map['minPets'], 1).clamp(1, 10),
      maxPets: _int(map['maxPets'], 3).clamp(1, 20),
      requireVaccine: map['requireVaccine'] == true,
      allowUnneutered: map['allowUnneutered'] != false,
      allowStaffRejectSpecial: map['allowStaffRejectSpecial'] != false,
      blockBlacklisted: map['blockBlacklisted'] != false,
      requireRoomType: map['requireRoomType'] != false,
      allowedAddonIds: _idList(map['allowedAddonIds']),
      roomTypes: _roomTypes(map['roomTypes']),
      plans: _plans(map['plans']),
      depositType: _oneOf(map['depositType'], const <String>[
        DaycareDepositTypes.none,
        DaycareDepositTypes.fixed,
        DaycareDepositTypes.percent,
        DaycareDepositTypes.full,
        DaycareDepositTypes.staffDecide,
      ], DaycareDepositTypes.none),
      depositValue: _int(map['depositValue'], 0),
      allowCash: map['allowCash'] != false,
      allowCoupon: map['allowCoupon'] == true,
      refundDepositOnCancel: map['refundDepositOnCancel'] != false,
      forfeitDepositOnNoShow: map['forfeitDepositOnNoShow'] != false,
      overtimeGraceMinutes: _int(map['overtimeGraceMinutes'], 15).clamp(0, 180),
      pointsEarnEnabled: map['pointsEarnEnabled'] == true,
      pointsSpendEnabled: map['pointsSpendEnabled'] == true,
      pointsIncludeAddons: map['pointsIncludeAddons'] == true,
      pointsIncludeSurcharge: map['pointsIncludeSurcharge'] == true,
      pointsIncludeOvertime: map['pointsIncludeOvertime'] == true,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'serviceName': serviceName,
      'intro': intro,
      'allowSameDay': allowSameDay,
      'minAdvanceHours': minAdvanceHours,
      'weekdays': weekdays,
      'openTime': openTime,
      'closeTime': closeTime,
      'earliestDropOff': earliestDropOff,
      'latestPickUp': latestPickUp,
      'slotMinutes': slotMinutes,
      'minDurationMinutes': minDurationMinutes,
      'maxDurationMinutes': maxDurationMinutes,
      'forbidOvernight': forbidOvernight,
      'dailyMaxPets': dailyMaxPets,
      'blockOutsideHours': blockOutsideHours,
      'showRemainingSlots': showRemainingSlots,
      'allowedPetTypes': allowedPetTypes,
      'minPets': minPets,
      'maxPets': maxPets,
      'allowStaffRejectSpecial': allowStaffRejectSpecial,
      'allowedAddonIds': allowedAddonIds,
      'roomTypes': roomTypes
          .map((DaycareRoomTypeSetting e) => e.toMap())
          .toList(),
      'plans': plans.map((DaycarePlanModel e) => e.toMap()).toList(),
      'depositType': depositType,
      'depositValue': depositValue,
      'allowCash': allowCash,
      'allowCoupon': allowCoupon,
      'refundDepositOnCancel': refundDepositOnCancel,
      'forfeitDepositOnNoShow': forfeitDepositOnNoShow,
      'overtimeGraceMinutes': overtimeGraceMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DaycareRoomTypeSetting? roomTypeSetting(String roomTypeId) {
    for (final DaycareRoomTypeSetting item in roomTypes) {
      if (item.roomTypeId == roomTypeId) {
        return item;
      }
    }
    return null;
  }

  List<DaycarePlanModel> get enabledPlans {
    final List<DaycarePlanModel> list =
        plans
            .where(
              (DaycarePlanModel e) =>
                  e.enabled && DaycarePlanTypes.isSelectable(e.type),
            )
            .toList()
          ..sort(
            (DaycarePlanModel a, DaycarePlanModel b) =>
                a.sortOrder.compareTo(b.sortOrder),
          );
    return list;
  }

  bool allowsAddon(String addonId) {
    final String id = addonId.trim();
    return id.isNotEmpty && allowedAddonIds.contains(id);
  }

  static int _int(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static String _str(dynamic raw, String fallback) {
    final String text = (raw ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _time(dynamic raw, String fallback) {
    final String text = (raw ?? '').toString().trim();
    return RegExp(r'^\d{2}:\d{2}$').hasMatch(text) ? text : fallback;
  }

  static int _slot(dynamic raw) {
    final int value = _int(raw, 30);
    if (value == 15 || value == 30 || value == 60) {
      return value;
    }
    return 30;
  }

  static List<int> _intList(dynamic raw, List<int> fallback) {
    if (raw is! List) {
      return fallback;
    }
    final List<int> values = raw
        .map((dynamic e) => _int(e, 0))
        .where((int e) => e >= 1 && e <= 7)
        .toList();
    return values.isEmpty ? fallback : values;
  }

  static List<String> _stringList(dynamic raw, List<String> fallback) {
    if (raw is! List) {
      return fallback;
    }
    final List<String> values = raw
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    return values.isEmpty ? fallback : values;
  }

  static List<String> _idList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  static String _oneOf(dynamic raw, List<String> allowed, String fallback) {
    final String text = (raw ?? '').toString().trim();
    return allowed.contains(text) ? text : fallback;
  }

  static List<DaycareRoomTypeSetting> _roomTypes(dynamic raw) {
    if (raw is! List) {
      return const <DaycareRoomTypeSetting>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (Map e) =>
              DaycareRoomTypeSetting.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  static List<DaycarePlanModel> _plans(dynamic raw) {
    if (raw is! List) {
      return const <DaycarePlanModel>[];
    }
    return raw
        .whereType<Map>()
        .map((Map e) => DaycarePlanModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
