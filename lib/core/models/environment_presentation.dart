// 檔案：lib/core/models/environment_presentation.dart
// 功能：環境介紹範本、設備與服務草稿序列化；保留未知欄位。
class EnvironmentServiceCard {
  EnvironmentServiceCard(Map<String, dynamic> data) : data = Map.of(data);
  final Map<String, dynamic> data;
  String get id => (data['id'] ?? '').toString();
  String get title => (data['title'] ?? '').toString().trim().isEmpty
      ? '未命名服務'
      : data['title'].toString();
  String get description => (data['description'] ?? '').toString();
  String get icon => (data['icon'] ?? 'pets').toString();
  String get category =>
      EnvironmentPresentation.categories.containsKey(data['category'])
      ? data['category'] as String
      : 'service';
  bool get visible => data['visible'] != false;
  String get tag => const ['included', 'contact', 'paid'].contains(data['tag'])
      ? data['tag'] as String
      : '';
  String get imageUrl => (data['imageUrl'] ?? '').toString().trim();
  String get imagePath => (data['imageStoragePath'] ?? '').toString().trim();
  Map<String, dynamic> toMap() => Map.of(data);
  EnvironmentServiceCard copyWith(Map<String, dynamic> changes) =>
      EnvironmentServiceCard({...data, ...changes});
}

class EnvironmentPresentation {
  static const categories = {
    'environment': '環境設備',
    'safety': '清潔安全',
    'care': '日常照護',
    'service': '貼心服務',
  };
  static const presets = {
    'warm': '溫暖旅宿',
    'minimal': '清爽簡約',
    'photo': '照片導覽',
    'care': '安心照護',
  };
  static const layouts = {
    'legacy': '原有樣式',
    'icon': '精簡圖示',
    'square': '說明方卡',
    'list': '橫向清單',
    'photo': '圖片服務卡',
  };
  EnvironmentPresentation({Map<String, dynamic>? raw})
    : _raw = Map.of(raw ?? {});
  final Map<String, dynamic> _raw;
  factory EnvironmentPresentation.fromMap(dynamic raw) =>
      EnvironmentPresentation(
        raw: raw is Map ? Map<String, dynamic>.from(raw) : null,
      );
  String get preset =>
      presets.containsKey(_raw['preset']) ? _raw['preset'] as String : '';
  bool get customized => _raw['customized'] == true;
  bool get groupedFacilities => _raw['groupFacilities'] == true;
  String get equipmentLayout => layouts.containsKey(_raw['equipmentLayout'])
      ? _raw['equipmentLayout'] as String
      : 'legacy';
  String get serviceLayout => layouts.containsKey(_raw['serviceLayout'])
      ? _raw['serviceLayout'] as String
      : 'legacy';
  List<String> _strings(String key) => _raw[key] is List
      ? (_raw[key] as List).whereType<String>().toSet().toList()
      : [];
  List<String> get facilityOrder => _strings('facilityOrder');
  List<String> get hiddenFacilityKeys => _strings('hiddenFacilityKeys');
  List<EnvironmentServiceCard> get services {
    final seen = <String>{};
    return (_raw['customServices'] is List
            ? _raw['customServices'] as List
            : [])
        .whereType<Map>()
        .map((m) {
          final data = Map<String, dynamic>.from(m);
          if ((data['id'] ?? '').toString().isEmpty) {
            var hash = 2166136261;
            for (final unit
                in '${data['title']}|${data['description']}|${data['imageUrl']}|${data['category']}'
                    .codeUnits) {
              hash = ((hash ^ unit) * 16777619) & 0xffffffff;
            }
            data['id'] = 'legacy_${hash.toRadixString(16)}';
          }
          return EnvironmentServiceCard(data);
        })
        .where((s) => seen.add(s.id))
        .toList();
  }

  Map<String, dynamic> toMap() => Map.of(_raw);
  EnvironmentPresentation copyWith(Map<String, dynamic> changes) =>
      EnvironmentPresentation(raw: {..._raw, ...changes});
  EnvironmentPresentation applyPreset(String value) => copyWith({
    'preset': value,
    'customized': false,
    'equipmentLayout': value == 'minimal' || value == 'photo'
        ? 'list'
        : 'square',
    'serviceLayout': value == 'minimal' || value == 'photo' ? 'list' : 'square',
  });
}
