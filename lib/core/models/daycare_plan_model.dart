// 檔案名稱：lib/core/models/daycare_plan_model.dart
// 功能說明：臨托收費方案快照

import 'package:cloud_firestore/cloud_firestore.dart';

class DaycarePlanTypes {
  DaycarePlanTypes._();

  static const String hourly = 'hourly';
  static const String halfHourly = 'half_hourly';
  static const String fixedHours = 'fixed_hours';
  static const String morning = 'morning';
  static const String afternoon = 'afternoon';
  static const String fullDay = 'full_day';
  static const String custom = 'custom';

  /// 舊方案類型仍可解析與顯示，但後台新建／編輯與前台選用不提供。
  static const List<String> all = <String>[
    hourly,
    halfHourly,
    fixedHours,
    morning,
    afternoon,
    fullDay,
    custom,
  ];

  static const List<String> selectable = <String>[hourly, halfHourly];

  static bool isSelectable(String type) => selectable.contains(type);

  static String label(String type) {
    switch (type) {
      case hourly:
        return '每小時計費';
      case halfHourly:
        return '每 30 分鐘計費';
      case fixedHours:
        return '固定時數方案';
      case morning:
        return '上午方案';
      case afternoon:
        return '下午方案';
      case fullDay:
        return '全天方案';
      default:
        return '自訂方案';
    }
  }
}

class DaycareOvertimeModes {
  DaycareOvertimeModes._();

  static const String hourly = 'hourly';
  static const String halfHourly = 'half_hourly';
  static const String none = 'none';
}

class DaycarePlanModel {
  const DaycarePlanModel({
    required this.id,
    required this.name,
    this.description = '',
    this.enabled = true,
    this.type = DaycarePlanTypes.hourly,
    this.weekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
    this.startTime = '09:00',
    this.endTime = '18:00',
    this.includedMinutes = 240,
    this.basePrice = 0,
    this.overtimeMode = DaycareOvertimeModes.hourly,
    this.overtimeUnitPrice = 0,
    this.extraBillingMinutes = 60,
    this.extraBillingPrice = 0,
    this.extraPetPrice = 0,
    this.maxBaseCharge = 0,
    this.maxPets = 20,
    this.minChargeUnits = 1,
    this.extraPetSurcharge = 0,
    this.requiresRoomType = false,
    this.roomTypeIds = const <String>[],
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;
  final String type;
  final List<int> weekdays;
  final String startTime;
  final String endTime;
  final int includedMinutes;
  final int basePrice;
  final String overtimeMode;
  final int overtimeUnitPrice;
  final int extraBillingMinutes;
  final int extraBillingPrice;
  final int extraPetPrice;
  final int maxBaseCharge;
  final int maxPets;
  final int minChargeUnits;
  final int extraPetSurcharge;
  final bool requiresRoomType;
  final List<String> roomTypeIds;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DaycarePlanModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return DaycarePlanModel(
      id: (map['id'] ?? id).toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      enabled: map['enabled'] != false,
      type: _oneOf(map['type'], DaycarePlanTypes.all, DaycarePlanTypes.hourly),
      weekdays: _intList(map['weekdays'], const <int>[1, 2, 3, 4, 5, 6, 7]),
      startTime: _time(map['startTime'], '09:00'),
      endTime: _time(map['endTime'], '18:00'),
      includedMinutes: _int(
        map['includedMinutes'] ?? map['baseMinutes'],
        240,
      ).clamp(15, 1440),
      basePrice: _int(map['basePrice'], 0),
      overtimeMode: _oneOf(map['overtimeMode'], const <String>[
        DaycareOvertimeModes.hourly,
        DaycareOvertimeModes.halfHourly,
        DaycareOvertimeModes.none,
      ], DaycareOvertimeModes.hourly),
      overtimeUnitPrice: _int(
        map['extraBillingPrice'] ?? map['overtimeUnitPrice'],
        0,
      ),
      extraBillingMinutes: _billingUnit(
        map['extraBillingMinutes'] ??
            (map['overtimeMode'] == DaycareOvertimeModes.halfHourly ? 30 : 60),
      ),
      extraBillingPrice: _int(
        map['extraBillingPrice'] ?? map['overtimeUnitPrice'],
        0,
      ),
      extraPetPrice: _int(map['extraPetPrice'] ?? map['extraPetSurcharge'], 0),
      maxBaseCharge: _int(map['maxBaseCharge'], 0),
      maxPets: () {
        final int pets = _int(map['maxPets'], 20);
        if (pets < 0) {
          return 0;
        }
        return pets > 99 ? 99 : pets;
      }(),
      minChargeUnits: _int(map['minChargeUnits'], 1).clamp(1, 99),
      extraPetSurcharge: _int(
        map['extraPetPrice'] ?? map['extraPetSurcharge'],
        0,
      ),
      requiresRoomType: map['requiresRoomType'] == true,
      roomTypeIds: _stringList(map['roomTypeIds']),
      sortOrder: _int(map['sortOrder'], 0),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'enabled': enabled,
      'type': type,
      'weekdays': weekdays,
      'startTime': startTime,
      'endTime': endTime,
      'includedMinutes': includedMinutes,
      'basePrice': basePrice,
      'overtimeMode': overtimeMode,
      'overtimeUnitPrice': extraBillingPrice,
      'extraBillingMinutes': extraBillingMinutes,
      'extraBillingPrice': extraBillingPrice,
      'extraPetPrice': extraPetPrice,
      'maxBaseCharge': maxBaseCharge,
      'maxPets': maxPets,
      'minChargeUnits': minChargeUnits,
      'extraPetSurcharge': extraPetPrice,
      'roomTypeIds': roomTypeIds,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toCallableSnapshot() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'enabled': enabled,
      'includedMinutes': includedMinutes,
      'basePrice': basePrice,
      'extraBillingMinutes': extraBillingMinutes,
      'extraBillingPrice': extraBillingPrice,
      'extraPetPrice': extraPetPrice,
      'maxBaseCharge': maxBaseCharge,
      'maxPets': maxPets,
      'sortOrder': sortOrder,
    };
  }

  DaycarePlanModel copyWith({
    String? name,
    String? description,
    bool? enabled,
    String? type,
    List<int>? weekdays,
    String? startTime,
    String? endTime,
    int? includedMinutes,
    int? basePrice,
    String? overtimeMode,
    int? overtimeUnitPrice,
    int? extraBillingMinutes,
    int? extraBillingPrice,
    int? extraPetPrice,
    int? maxBaseCharge,
    int? maxPets,
    int? minChargeUnits,
    int? extraPetSurcharge,
    bool? requiresRoomType,
    List<String>? roomTypeIds,
    int? sortOrder,
  }) {
    return DaycarePlanModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      weekdays: weekdays ?? this.weekdays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      includedMinutes: includedMinutes ?? this.includedMinutes,
      basePrice: basePrice ?? this.basePrice,
      overtimeMode: overtimeMode ?? this.overtimeMode,
      overtimeUnitPrice:
          extraBillingPrice ?? overtimeUnitPrice ?? this.extraBillingPrice,
      extraBillingMinutes: extraBillingMinutes ?? this.extraBillingMinutes,
      extraBillingPrice:
          extraBillingPrice ?? overtimeUnitPrice ?? this.extraBillingPrice,
      extraPetPrice: extraPetPrice ?? extraPetSurcharge ?? this.extraPetPrice,
      maxBaseCharge: maxBaseCharge ?? this.maxBaseCharge,
      maxPets: maxPets ?? this.maxPets,
      minChargeUnits: minChargeUnits ?? this.minChargeUnits,
      extraPetSurcharge:
          extraPetPrice ?? extraPetSurcharge ?? this.extraPetPrice,
      requiresRoomType: requiresRoomType ?? this.requiresRoomType,
      roomTypeIds: roomTypeIds ?? this.roomTypeIds,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get includedTimeLabel {
    if (includedMinutes % 60 == 0) {
      return '${includedMinutes ~/ 60} 小時';
    }
    return '$includedMinutes 分鐘';
  }

  String get extraUnitLabel => extraBillingMinutes == 30 ? '每 30 分鐘' : '每 1 小時';

  static String moneyLabel(int amount) => 'NT\$$amount';

  static String includedTimeText(int minutes) {
    if (minutes <= 0) {
      return '0 分鐘';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60} 小時';
    }
    if (minutes > 60) {
      return '${minutes ~/ 60} 小時 ${minutes % 60} 分鐘';
    }
    return '$minutes 分鐘';
  }

  static String extraUnitText(int extraBillingMinutes) {
    return extraBillingMinutes == 30 ? '每 30 分鐘' : '每 1 小時';
  }

  static List<String> offerDetailLines({
    required int includedMinutes,
    required int basePrice,
    required int extraBillingMinutes,
    required int extraBillingPrice,
    required int maxBaseCharge,
    required int extraPetPrice,
    required int maxPets,
    required bool enabled,
    bool roomBased = false,
    int? remainingRooms,
  }) {
    final List<String> lines = <String>[
      '基本 ${includedTimeText(includedMinutes)}　${moneyLabel(basePrice)}',
      '超過後${extraUnitText(extraBillingMinutes)}　${moneyLabel(extraBillingPrice)}',
    ];
    if (maxBaseCharge > 0) {
      lines.add(
        roomBased
            ? '當日房型收費最高上限 ${moneyLabel(maxBaseCharge)}'
            : '當次最高計費　${moneyLabel(maxBaseCharge)}',
      );
    }
    if (extraPetPrice > 0) {
      lines.add('每增加 1 隻　+${moneyLabel(extraPetPrice)}');
    }
    if (maxPets > 0) {
      lines.add('最多 $maxPets 隻');
    } else {
      lines.add('寵物數量不限');
    }
    if (remainingRooms != null && remainingRooms >= 0) {
      lines.add('剩餘 $remainingRooms 間');
    }
    if (!enabled) {
      lines.add(roomBased ? '房型未啟用' : '方案未啟用');
    }
    return lines;
  }

  List<String> get customerSummaryLines {
    return offerDetailLines(
      includedMinutes: includedMinutes,
      basePrice: basePrice,
      extraBillingMinutes: extraBillingMinutes,
      extraBillingPrice: extraBillingPrice,
      maxBaseCharge: maxBaseCharge,
      extraPetPrice: extraPetPrice,
      maxPets: maxPets,
      enabled: enabled,
    );
  }

  static int _int(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ??
        double.tryParse(raw?.toString() ?? '')?.round() ??
        fallback;
  }

  static int _billingUnit(dynamic raw) {
    final int value = _int(raw, 60);
    if (value == 30 || value == 60) {
      return value;
    }
    return 60;
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

  static List<String> _stringList(dynamic raw) {
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

  static String _time(dynamic raw, String fallback) {
    final String text = (raw ?? '').toString().trim();
    final RegExp ok = RegExp(r'^\d{2}:\d{2}$');
    return ok.hasMatch(text) ? text : fallback;
  }

  static DateTime? _date(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}
