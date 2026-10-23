// 功能：介紹與比較共用房型資料解析；缺值不推算成價格或容量。
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'room_feature_tags.dart';

class RoomIntroFacts {
  RoomIntroFacts(this.room);
  final Map<String, dynamic> room;
  String get id => '${room['id'] ?? ''}';
  String get name => '${room['name'] ?? '未命名房型'}';
  List<String> get photos => roomPhotoUrls(room['images']);
  static num? number(Object? value, {bool positive = false}) {
    final n = num.tryParse('$value');
    return n != null && n.isFinite && (positive ? n > 0 : n >= 0) ? n : null;
  }

  String get price => number(room['price']) == null
      ? '未提供'
      : 'NT\$ ${number(room['price'])} / 晚';
  String get capacity => number(room['capacity'], positive: true) == null
      ? '未提供'
      : '最多 ${number(room['capacity'])} 隻';
  String get extra => number(room['extraPrice']) == null
      ? '未提供'
      : '每多一隻 NT\$ ${number(room['extraPrice'])}';
  String get dimensions =>
      {'寬': room['width'], '深': room['depth'], '高': room['height']}.entries
          .where((e) => number(e.value, positive: true) != null)
          .map((e) => '${e.key} ${number(e.value)} cm')
          .join(' × ');
  List<String> get featureKeys => [
    if (room['features'] is List)
      for (final key in room['features'] as List)
        if ('$key'.trim().isNotEmpty) '$key',
    if (room['customFeatures'] is List)
      for (final item in (room['customFeatures'] as List).whereType<Map>())
        if ('${item['name'] ?? ''}'.trim().isNotEmpty)
          '${item['icon'] ?? ''} ${item['name']}'.trim(),
  ];
  List<Map<String, dynamic>> get featureItems => [
    if (room['features'] is List)
      for (final key in room['features'] as List)
        if ('$key'.trim().isNotEmpty)
          RoomFeatureTags.featureOptions['$key'] ?? {'name': '$key'},
    if (room['customFeatures'] is List)
      for (final item in (room['customFeatures'] as List).whereType<Map>())
        if ('${item['name'] ?? ''}'.trim().isNotEmpty)
          {'name': '${item['name']}', 'emoji': '${item['icon'] ?? ''}'},
  ];
  List<String> get features =>
      featureItems.map((item) => '${item['name']}').toList();
}
