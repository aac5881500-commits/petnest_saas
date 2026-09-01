// lib/core/models/policy_applicable_service.dart
// 📜 條款適用服務：住宿 / 臨托 / 共用
// 舊條款沒有適用類型時，一律視為僅住宿，不可自動套用臨托。

class PolicyApplicableService {
  PolicyApplicableService._();

  static const String accommodation = 'accommodation';
  static const String daycare = 'daycare';

  static const List<String> accommodationOnly = <String>[accommodation];
  static const List<String> daycareOnly = <String>[daycare];
  static const List<String> shared = <String>[accommodation, daycare];

  static List<String> parse(dynamic raw) {
    if (raw is! List) {
      return List<String>.from(accommodationOnly);
    }
    final List<String> values = raw
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item == accommodation || item == daycare)
        .toSet()
        .toList();
    if (values.isEmpty) {
      return List<String>.from(accommodationOnly);
    }
    return values;
  }

  static bool appliesTo(List<String> services, String serviceType) {
    return services.contains(serviceType);
  }

  static String label(List<String> services) {
    final bool stay = services.contains(accommodation);
    final bool daycareOn = services.contains(daycare);
    if (stay && daycareOn) {
      return '住宿與臨托共用';
    }
    if (daycareOn) {
      return '僅臨托';
    }
    return '僅住宿';
  }

  static List<Map<String, dynamic>> normalizeCustomPolicies(dynamic raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (final dynamic item in raw) {
      if (item is String) {
        final String text = item.trim();
        if (text.isEmpty) {
          continue;
        }
        items.add(<String, dynamic>{
          'text': text,
          'applicableServices': List<String>.from(accommodationOnly),
        });
        continue;
      }
      if (item is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        final String text = (map['text'] ?? map['content'] ?? '')
            .toString()
            .trim();
        if (text.isEmpty) {
          continue;
        }
        items.add(<String, dynamic>{
          'text': text,
          'applicableServices': parse(map['applicableServices']),
        });
      }
    }
    return items;
  }

  static List<String> textsForService({
    required List<Map<String, dynamic>> items,
    required String serviceType,
  }) {
    return items
        .where(
          (Map<String, dynamic> item) =>
              appliesTo(parse(item['applicableServices']), serviceType),
        )
        .map((Map<String, dynamic> item) => (item['text'] ?? '').toString())
        .where((String text) => text.trim().isNotEmpty)
        .toList();
  }
}
