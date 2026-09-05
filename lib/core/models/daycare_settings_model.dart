// 檔案名稱：lib/core/models/daycare_settings_model.dart
// 功能說明：臨托店家設定：shops/{shopId}/daycare_settings/main

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';

/// Firestore 開關相容：true / 1 / 'true' / '1' 為開；false / 0 / 'false' / '0' / null 為關。
class DaycareBool {
  DaycareBool._();

  static bool parse(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized.isEmpty) {
        return false;
      }
    }
    return fallback;
  }
}

class DaycarePricingModes {
  DaycarePricingModes._();

  /// 訂單／設定正式值。Cloud Functions 仍讀舊值 room_based／time_based。
  static const String roomType = 'roomType';
  static const String independentPlan = 'independentPlan';
  static const String roomBased = 'room_based';
  static const String timeBased = 'time_based';

  static bool isRoomBased(String? raw) {
    final String value = (raw ?? '').trim();
    return value == roomType || value == roomBased;
  }

  static String normalize(String? raw) {
    return isRoomBased(raw) ? roomType : independentPlan;
  }

  /// 新資料寫入 roomType／independentPlan；仍相容舊 room_based／time_based。
  static String persist(String? raw) {
    return isRoomBased(raw) ? roomType : independentPlan;
  }
}

class DaycareRoundingModes {
  DaycareRoundingModes._();

  static const String ceilHour = 'ceil_hour';
  static const String ceilHalfHour = 'ceil_half_hour';
  static const String prorated = 'prorated';
}

class DaycareCapModes {
  DaycareCapModes._();

  static const String overnightRate = 'overnight_rate';
  static const String fixedAmount = 'fixed_amount';
  static const String none = 'none';
}

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
    this.description = '',
    this.baseMinutes = 240,
    this.includedMinutes = 240,
    this.basePrice = 0,
    this.extraPetPrice = 0,
    this.extraTimeUnitMinutes = 60,
    this.extraTimePrice = 0,
    this.extraBillingMinutes = 60,
    this.extraBillingPrice = 0,
    this.maxBaseCharge = 0,
    this.overtimeEnabled = false,
    this.overtimeGraceMinutes = 0,
    this.latePickupUnitMinutes = 30,
    this.latePickupPrice = 0,
    this.roundingMode = DaycareRoundingModes.ceilHour,
    this.capMode = DaycareCapModes.overnightRate,
    this.fixedCapAmount = 0,
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
  final String description;
  final int baseMinutes;
  final int includedMinutes;
  final int basePrice;
  final int extraPetPrice;
  final int extraTimeUnitMinutes;
  final int extraTimePrice;
  final int extraBillingMinutes;
  final int extraBillingPrice;
  final int maxBaseCharge;

  /// 是否收取逾時接回費用。舊資料沒有此欄時，若已填 extraTimePrice 則視為開啟。
  final bool overtimeEnabled;

  /// 0 表示沿用店家 overtimeGraceMinutes。
  final int overtimeGraceMinutes;
  final int latePickupUnitMinutes;
  final int latePickupPrice;
  final String roundingMode;
  final String capMode;
  final int fixedCapAmount;

  factory DaycareRoomTypeSetting.fromMap(
    Map<String, dynamic> map, {
    String roomTypeId = '',
  }) {
    final bool latePickup = map.containsKey('overtimeEnabled')
        ? DaycareBool.parse(map['overtimeEnabled'])
        : DaycareBool.parse(map['latePickupEnabled']);
    final int extraTimePrice = _toInt(map['extraTimePrice'], 0);
    final int extraBillingPrice = _toInt(
      map['extraBillingPrice'],
      latePickup ? 0 : extraTimePrice,
    );
    final int extraBillingMinutes = _timeUnit(
      map['extraBillingMinutes'] ??
          (latePickup ? 60 : map['extraTimeUnitMinutes']),
    );
    final int included = _toInt(
      map['includedMinutes'] ?? map['baseMinutes'],
      240,
    ).clamp(15, 1440);
    final int maxBase = _toInt(
      map['maxBaseCharge'],
      map['capMode']?.toString() == DaycareCapModes.fixedAmount
          ? _toInt(map['fixedCapAmount'], 0)
          : 0,
    );
    return DaycareRoomTypeSetting(
      roomTypeId: (map['roomTypeId'] ?? roomTypeId).toString(),
      enabled: DaycareBool.parse(map['enabled']),
      maxPets: _toInt(map['maxPets'], 1).clamp(1, 20),
      requiresRoom: map['requiresRoom'] != false,
      shareWithAccommodation: map['shareWithAccommodation'] != false,
      occupancyMode: (map['occupancyMode'] ?? DaycareOccupancyModes.slot)
          .toString(),
      markCleaningOnComplete: map['markCleaningOnComplete'] != false,
      blockUntilCleaned: map['blockUntilCleaned'] != false,
      allowNonOverlappingSameDay: map['allowNonOverlappingSameDay'] != false,
      description: (map['description'] ?? '').toString(),
      baseMinutes: included,
      includedMinutes: included,
      basePrice: _toInt(map['basePrice'], 0),
      extraPetPrice: _toInt(map['extraPetPrice'], 0),
      extraTimeUnitMinutes: extraBillingMinutes,
      extraTimePrice: extraBillingPrice,
      extraBillingMinutes: extraBillingMinutes,
      extraBillingPrice: extraBillingPrice,
      maxBaseCharge: maxBase < 0 ? 0 : maxBase,
      overtimeEnabled: latePickup,
      overtimeGraceMinutes: _toInt(
        map['overtimeGraceMinutes'] ?? map['latePickupGraceMinutes'],
        0,
      ).clamp(0, 180),
      latePickupUnitMinutes: _timeUnit(
        map['latePickupUnitMinutes'] ??
            (latePickup ? map['extraTimeUnitMinutes'] : 30),
      ),
      latePickupPrice: _toInt(
        map['latePickupPrice'],
        latePickup ? extraTimePrice : 0,
      ),
      roundingMode: _oneOf(map['roundingMode'], const <String>[
        DaycareRoundingModes.ceilHour,
        DaycareRoundingModes.ceilHalfHour,
        DaycareRoundingModes.prorated,
      ], DaycareRoundingModes.ceilHour),
      capMode: _oneOf(map['capMode'], const <String>[
        DaycareCapModes.overnightRate,
        DaycareCapModes.fixedAmount,
        DaycareCapModes.none,
      ], DaycareCapModes.overnightRate),
      fixedCapAmount: _toInt(map['fixedCapAmount'], 0),
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
    String? description,
    int? baseMinutes,
    int? includedMinutes,
    int? basePrice,
    int? extraPetPrice,
    int? extraTimeUnitMinutes,
    int? extraTimePrice,
    int? extraBillingMinutes,
    int? extraBillingPrice,
    int? maxBaseCharge,
    bool? overtimeEnabled,
    int? overtimeGraceMinutes,
    int? latePickupUnitMinutes,
    int? latePickupPrice,
    String? roundingMode,
    String? capMode,
    int? fixedCapAmount,
  }) {
    final int included = includedMinutes ?? baseMinutes ?? this.includedMinutes;
    final int extraMin =
        extraBillingMinutes ?? extraTimeUnitMinutes ?? this.extraBillingMinutes;
    final int extraPrice =
        extraBillingPrice ?? extraTimePrice ?? this.extraBillingPrice;
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
      description: description ?? this.description,
      baseMinutes: included,
      includedMinutes: included,
      basePrice: basePrice ?? this.basePrice,
      extraPetPrice: extraPetPrice ?? this.extraPetPrice,
      extraTimeUnitMinutes: extraMin,
      extraTimePrice: extraPrice,
      extraBillingMinutes: extraMin,
      extraBillingPrice: extraPrice,
      maxBaseCharge: maxBaseCharge ?? this.maxBaseCharge,
      overtimeEnabled: overtimeEnabled ?? this.overtimeEnabled,
      overtimeGraceMinutes: overtimeGraceMinutes ?? this.overtimeGraceMinutes,
      latePickupUnitMinutes:
          latePickupUnitMinutes ?? this.latePickupUnitMinutes,
      latePickupPrice: latePickupPrice ?? this.latePickupPrice,
      roundingMode: roundingMode ?? this.roundingMode,
      capMode: capMode ?? this.capMode,
      fixedCapAmount: fixedCapAmount ?? this.fixedCapAmount,
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
      'description': description,
      'baseMinutes': includedMinutes,
      'includedMinutes': includedMinutes,
      'basePrice': basePrice,
      'extraPetPrice': extraPetPrice,
      'extraTimeUnitMinutes': extraBillingMinutes,
      'extraTimePrice': extraBillingPrice,
      'extraBillingMinutes': extraBillingMinutes,
      'extraBillingPrice': extraBillingPrice,
      'maxBaseCharge': maxBaseCharge,
      'overtimeEnabled': overtimeEnabled,
      'overtimeGraceMinutes': overtimeGraceMinutes,
      'latePickupUnitMinutes': latePickupUnitMinutes,
      'latePickupPrice': latePickupPrice,
      'roundingMode': roundingMode,
      'capMode': capMode,
      'fixedCapAmount': fixedCapAmount,
    };
  }

  static String _oneOf(dynamic raw, List<String> allowed, String fallback) {
    final String text = (raw ?? '').toString().trim();
    return allowed.contains(text) ? text : fallback;
  }

  static int _timeUnit(dynamic raw) {
    final int value = _toInt(raw, 60);
    if (value == 15 || value == 30 || value == 60) {
      return value;
    }
    return 60;
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    final String text = (raw?.toString() ?? '').trim();
    if (text.isEmpty) {
      return fallback;
    }
    return int.tryParse(text) ?? double.tryParse(text)?.round() ?? fallback;
  }
}

class DaycareSettingsModel {
  const DaycareSettingsModel({
    this.enabled = false,
    this.serviceName = '寵物安親',
    this.intro = '',
    this.pricingMode = DaycarePricingModes.timeBased,
    this.timeBillingUnit = '',
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
    this.maxDurationMinutes = 1440,
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
    this.latePickupEnabled = false,
    this.latePickupUnitMinutes = 30,
    this.latePickupPrice = 0,
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
  final String pricingMode;
  final String timeBillingUnit;
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
  final bool latePickupEnabled;
  final int latePickupUnitMinutes;
  final int latePickupPrice;
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
      enabled: DaycareBool.parse(map['enabled']),
      serviceName: _str(map['serviceName'], '寵物安親'),
      intro: _str(map['intro'], ''),
      pricingMode: DaycarePricingModes.persist(map['pricingMode']),
      timeBillingUnit: _oneOf(map['timeBillingUnit'], const <String>[
        DaycarePlanTypes.hourly,
        DaycarePlanTypes.halfHourly,
      ], ''),
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
      dailyMaxPets: _int(map['dailyMaxPets'], 10).clamp(0, 200),
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
      overtimeGraceMinutes: _grace(
        map['overtimeGraceMinutes'] ?? map['latePickupGraceMinutes'],
      ),
      latePickupEnabled: DaycareBool.parse(
        map['latePickupEnabled'] ?? map['overtimeEnabled'],
      ),
      latePickupUnitMinutes: _timeUnit(
        map['latePickupUnitMinutes'] ?? map['extraTimeUnitMinutes'],
      ),
      latePickupPrice: _int(
        map['latePickupPrice'] ?? map['latePickupUnitPrice'],
        0,
      ),
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
      'pricingMode': DaycarePricingModes.persist(pricingMode),
      'timeBillingUnit': resolvedTimeBillingUnit,
      'allowSameDay': allowSameDay,
      'minAdvanceHours': minAdvanceHours,
      'weekdays': weekdays,
      'earliestDropOff': earliestDropOff,
      'latestPickUp': latestPickUp,
      'slotMinutes': slotMinutes,
      'minDurationMinutes': minDurationMinutes,
      // 舊欄位仍寫入，固定為全日上限，避免 Cloud Function 再用 480 分鐘預設擋長時段。
      'maxDurationMinutes': 1440,
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
      'latePickupEnabled': latePickupEnabled,
      'latePickupUnitMinutes': latePickupUnitMinutes,
      'latePickupPrice': latePickupPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isRoomBased => DaycarePricingModes.isRoomBased(pricingMode);

  String get resolvedTimeBillingUnit {
    if (timeBillingUnit == DaycarePlanTypes.hourly ||
        timeBillingUnit == DaycarePlanTypes.halfHourly) {
      return timeBillingUnit;
    }
    final List<DaycarePlanModel> enabled = enabledPlans;
    if (enabled.length == 1) {
      return enabled.first.type;
    }
    return DaycarePlanTypes.hourly;
  }

  List<DaycarePlanModel> get customerPlans {
    if (isRoomBased) {
      return const <DaycarePlanModel>[];
    }
    final List<DaycarePlanModel> plans = List<DaycarePlanModel>.from(
      enabledPlans,
    );
    plans.sort(
      (DaycarePlanModel a, DaycarePlanModel b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );
    return plans;
  }

  List<DaycareRoomTypeSetting> get enabledRoomTypeSettings {
    return roomTypes.where((DaycareRoomTypeSetting e) => e.enabled).toList();
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
        plans.where((DaycarePlanModel e) => e.enabled).toList()..sort(
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

  static int _grace(dynamic raw) {
    final int value = _int(raw, 15);
    if (value <= 0) {
      return 0;
    }
    if (value <= 15) {
      return 15;
    }
    if (value <= 30) {
      return 30;
    }
    return 60;
  }

  static int _timeUnit(dynamic raw) {
    return _int(raw, 30) == 60 ? 60 : 30;
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
