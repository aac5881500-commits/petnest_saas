// 檔案名稱：lib/core/services/daycare_addon_line.dart
// 功能說明：安親加購依既有客製／每日分時段紅字規則重算，不信任前端金額

import '../models/policy_applicable_service.dart';
import 'daycare_addon_catalog.dart';
import 'daycare_pricing_service.dart';
import 'daycare_time_helper.dart';

class DaycareAddonLineResult {
  const DaycareAddonLineResult({
    required this.ok,
    this.error,
    this.line = const <String, dynamic>{},
    this.amount = 0,
  });

  final bool ok;
  final String? error;
  final Map<String, dynamic> line;
  final int amount;
}

class DaycareAddonLine {
  DaycareAddonLine._();

  static const String groupCustom = 'customServices';
  static const String groupDailyTimed = 'dailyTimedServices';

  static bool appliesToDaycare(Map<String, dynamic> item) {
    return PolicyApplicableService.appliesTo(
      PolicyApplicableService.parse(item['applicableServices']),
      PolicyApplicableService.daycare,
    );
  }

  static List<String> uniqueIds(Iterable<dynamic>? raw) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    if (raw == null) {
      return out;
    }
    for (final dynamic item in raw) {
      final String id = item.toString().trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      out.add(id);
    }
    return out;
  }

  static bool slotFullyInside({
    required String label,
    required DateTime scheduledStartAt,
    required DateTime scheduledEndAt,
  }) {
    final String hhmm = label.trim();
    if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(hhmm)) {
      return false;
    }
    final DateTime startTw = DaycareTimeHelper.toTaiwan(scheduledStartAt);
    final DateTime endTw = DaycareTimeHelper.toTaiwan(scheduledEndAt);
    final DateTime startWall = DateTime(
      startTw.year,
      startTw.month,
      startTw.day,
      startTw.hour,
      startTw.minute,
    );
    final DateTime endWall = DateTime(
      endTw.year,
      endTw.month,
      endTw.day,
      endTw.hour,
      endTw.minute,
    );
    DateTime slotOn(DateTime day) {
      return DaycareTimeHelper.combineDateAndTime(
        DateTime(day.year, day.month, day.day),
        hhmm,
      );
    }

    bool inside(DateTime slot) {
      return !slot.isBefore(startWall) && slot.isBefore(endWall);
    }

    return inside(slotOn(startTw)) || inside(slotOn(endTw));
  }

  static List<Map<String, dynamic>> slotsFullyInside({
    required List<Map<String, dynamic>> timeSlots,
    required DateTime scheduledStartAt,
    required DateTime scheduledEndAt,
  }) {
    return timeSlots.where((Map<String, dynamic> slot) {
      final String label = (slot['label'] ?? '').toString().trim();
      return slotFullyInside(
        label: label,
        scheduledStartAt: scheduledStartAt,
        scheduledEndAt: scheduledEndAt,
      );
    }).toList();
  }

  static String groupKeyOf(Map<String, dynamic> live) {
    final String group = (live['groupKey'] ?? live['type'] ?? '').toString();
    if (group == 'custom' || group == groupCustom) {
      return groupCustom;
    }
    if (group == 'daily_timed' || group == groupDailyTimed) {
      return groupDailyTimed;
    }
    return group;
  }

  static DaycareAddonLineResult resolve({
    required Map<String, dynamic> live,
    required Map<String, dynamic> requested,
    required List<String> orderPetIds,
    required List<String> allowedAddonIds,
    required DateTime scheduledStartAt,
    required DateTime scheduledEndAt,
  }) {
    final String id = (live['id'] ?? requested['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return const DaycareAddonLineResult(ok: false, error: '加購服務無效');
    }
    if (!DaycareAddonCatalog.isAllowed(
          allowedAddonIds: allowedAddonIds,
          addonId: id,
        ) ||
        !DaycareAddonCatalog.isItemEnabled(live) ||
        !appliesToDaycare(live)) {
      return const DaycareAddonLineResult(ok: false, error: '所選加購服務未開放安親');
    }

    final int minutes = scheduledEndAt.difference(scheduledStartAt).inMinutes;
    final String group = groupKeyOf(live);
    final int price = _toInt(live['price'], 0);
    final String name = DaycareAddonCatalog.displayName(live);
    final String type = (live['type'] ?? group).toString();

    if (group == groupCustom) {
      final List<String> selected = uniqueIds(
        requested['selectedPetIds'] as Iterable<dynamic>?,
      );
      if (selected.isEmpty) {
        return const DaycareAddonLineResult(ok: false, error: '客製化服務請選擇寵物');
      }
      final Set<String> order = orderPetIds.toSet();
      for (final String petId in selected) {
        if (!order.contains(petId)) {
          return const DaycareAddonLineResult(ok: false, error: '所選寵物不屬於此訂單');
        }
      }
      final int count = selected.length;
      final int amount = price * count;
      return DaycareAddonLineResult(
        ok: true,
        amount: amount,
        line: <String, dynamic>{
          'id': id,
          'name': name,
          'type': type.isEmpty ? groupCustom : type,
          'price': price,
          'count': count,
          'quantity': count,
          'selectedPetIds': selected,
          'selectedTimeSlots': const <Map<String, dynamic>>[],
          'amount': amount,
        },
      );
    }

    if (group == groupDailyTimed) {
      final List<String> selectedPets = uniqueIds(
        requested['selectedPetIds'] as Iterable<dynamic>?,
      );
      if (selectedPets.isEmpty) {
        return const DaycareAddonLineResult(ok: false, error: '每日分時段服務請選擇寵物');
      }
      final Set<String> order = orderPetIds.toSet();
      for (final String petId in selectedPets) {
        if (!order.contains(petId)) {
          return const DaycareAddonLineResult(ok: false, error: '所選寵物不屬於此訂單');
        }
      }
      final List<Map<String, dynamic>> catalogSlots =
          (live['timeSlots'] is List)
          ? (live['timeSlots'] as List)
                .whereType<Map>()
                .map((Map item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> selectedSlots = _matchSlots(
        requested: requested,
        catalogSlots: catalogSlots,
        scheduledStartAt: scheduledStartAt,
        scheduledEndAt: scheduledEndAt,
      );
      if (selectedSlots.isEmpty) {
        return const DaycareAddonLineResult(ok: false, error: '每日分時段服務請選擇有效時段');
      }
      final int count = selectedPets.length * selectedSlots.length;
      final int amount = price * count;
      return DaycareAddonLineResult(
        ok: true,
        amount: amount,
        line: <String, dynamic>{
          'id': id,
          'name': name,
          'type': type.isEmpty ? groupDailyTimed : type,
          'price': price,
          'count': count,
          'quantity': count,
          'slotCount': selectedSlots.length,
          'selectedPetIds': selectedPets,
          'selectedTimeSlots': selectedSlots,
          'amount': amount,
        },
      );
    }

    final int amount = DaycarePricingService.instance.addonLineAmount(
      addon: live,
      minutes: minutes,
      petCount: orderPetIds.isEmpty ? 1 : orderPetIds.length,
    );
    return DaycareAddonLineResult(
      ok: true,
      amount: amount,
      line: <String, dynamic>{
        'id': id,
        'name': name,
        'type': type,
        'price': price,
        'count': 1,
        'quantity': 1,
        'daycareChargeMode': (live['daycareChargeMode'] ?? 'per_order')
            .toString(),
        'selectedPetIds': uniqueIds(
          requested['selectedPetIds'] as Iterable<dynamic>?,
        ),
        'selectedTimeSlots': const <Map<String, dynamic>>[],
        'amount': amount,
      },
    );
  }

  static List<Map<String, dynamic>> _matchSlots({
    required Map<String, dynamic> requested,
    required List<Map<String, dynamic>> catalogSlots,
    required DateTime scheduledStartAt,
    required DateTime scheduledEndAt,
  }) {
    final List<dynamic> raw = <dynamic>[];
    final Object? slots = requested['selectedTimeSlots'];
    if (slots is Iterable) {
      raw.addAll(slots);
    }
    final Object? ids = requested['selectedSlotIds'];
    if (ids is Iterable) {
      raw.addAll(ids);
    }
    final List<String> keys = uniqueIds(
      raw.map((dynamic item) {
        if (item is Map) {
          final String id = (item['id'] ?? '').toString().trim();
          if (id.isNotEmpty) {
            return id;
          }
          return (item['label'] ?? '').toString().trim();
        }
        return item.toString();
      }),
    );
    final List<Map<String, dynamic>> matched = <Map<String, dynamic>>[];
    final Set<String> seen = <String>{};
    for (final String key in keys) {
      Map<String, dynamic>? found;
      for (final Map<String, dynamic> slot in catalogSlots) {
        final String slotId = (slot['id'] ?? '').toString().trim();
        final String label = (slot['label'] ?? '').toString().trim();
        if (slotId == key || label == key) {
          found = slot;
          break;
        }
      }
      if (found == null) {
        return const <Map<String, dynamic>>[];
      }
      final String label = (found['label'] ?? '').toString().trim();
      if (!slotFullyInside(
        label: label,
        scheduledStartAt: scheduledStartAt,
        scheduledEndAt: scheduledEndAt,
      )) {
        return const <Map<String, dynamic>>[];
      }
      final String identity =
          ((found['id'] ?? '').toString().trim().isNotEmpty
                  ? found['id']
                  : label)
              .toString()
              .trim();
      if (seen.contains(identity)) {
        continue;
      }
      seen.add(identity);
      matched.add(<String, dynamic>{
        'id': (found['id'] ?? '').toString(),
        'label': label,
      });
    }
    return matched;
  }

  static int _toInt(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
