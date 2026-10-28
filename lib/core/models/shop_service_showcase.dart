import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/services/shop_plan_access.dart';

/// Optional service introductions. Module availability is always checked at render time.
class ShopServiceShowcase {
  const ShopServiceShowcase({
    this.layout = 'hidden',
    this.selected = const [],
    this.images = const {},
    this.shape = 'theme',
    this.imageFit = 'cover',
    this.imagePosition = 'center',
    this.artworkStyle = 'simple',
  });
  static const artworkStyles = {
    'simple': '簡約圖示',
    'storybook': '柔和繪本',
    'sticker': '卡通貼紙',
    'postcard': '旅宿手帳',
  };
  final String artworkStyle;
  static const layouts = {
    'hidden': '不顯示',
    'icons': '圖示排列',
    'cards': '服務卡片',
    'photoGrid': '照片格',
    'editorial': '左右圖文',
    'overlay': '大圖覆字',
    'compact': '精簡標籤',
  };
  static const shapes = {
    'theme': '原有造型',
    'soft': '柔和底色',
    'outline': '細框留白',
    'rounded': '圓潤造型',
  };
  final Map<String, Map<String, dynamic>> images;
  final String shape, imageFit, imagePosition;
  Map<String, dynamic> imageFor(String id) => images[id] ?? const {};
  ShopServiceShowcase withImage(String id, Map<String, dynamic> image) =>
      copyWith(images: {...images, id: image});
  final String layout;
  final List<String> selected;
  static const labels = {
    ShopModules.catHotel: '貓咪旅店',
    ShopModules.dogHotel: '狗狗旅店',
    ShopModules.grooming: '寵物美容',
    ShopModules.hospital: '動物醫院',
    ShopModules.store: '寵物賣場',
  };
  static const descriptions = {
    ShopModules.catHotel: '舒適的貓咪住宿與細心照護',
    ShopModules.dogHotel: '狗狗住宿、安親與日常陪伴',
    ShopModules.grooming: '洗澡、毛髮整理與造型服務',
    ShopModules.hospital: '門診諮詢與健康照護服務',
    ShopModules.store: '日常用品與毛孩生活選物',
  };
  factory ShopServiceShowcase.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    final ids = map['selected'];
    return ShopServiceShowcase(
      layout: layouts.containsKey(map['layout'])
          ? map['layout'] as String
          : 'hidden',
      artworkStyle: artworkStyles.containsKey(map['artworkStyle'])
          ? map['artworkStyle'] as String
          : 'simple',
      images: map['images'] is Map
          ? {
              for (final entry in (map['images'] as Map).entries)
                if (labels.containsKey(entry.key) && entry.value is Map)
                  entry.key as String: Map<String, dynamic>.from(
                    entry.value as Map,
                  ),
            }
          : const {},
      shape: shapes.containsKey(map['shape'])
          ? map['shape'] as String
          : 'theme',
      imageFit: map['imageFit'] == 'contain' ? 'contain' : 'cover',
      imagePosition:
          const ['top', 'center', 'bottom'].contains(map['imagePosition'])
          ? map['imagePosition'] as String
          : 'center',
      selected: ids is List
          ? ids.whereType<String>().where(labels.containsKey).toSet().toList()
          : const [],
    );
  }
  Map<String, dynamic> toMap() => {
    'layout': layout,
    'selected': selected,
    'images': images,
    'shape': shape,
    'imageFit': imageFit,
    'imagePosition': imagePosition,
    'artworkStyle': artworkStyle,
  };
  List<String> visibleModules(Iterable<String> enabled) => layout == 'hidden'
      ? []
      : selected
            .where((id) => labels.containsKey(id) && enabled.contains(id))
            .toList();
  ShopServiceShowcase copyWith({
    String? layout,
    List<String>? selected,
    Map<String, Map<String, dynamic>>? images,
    String? shape,
    String? imageFit,
    String? imagePosition,
    String? artworkStyle,
  }) => ShopServiceShowcase(
    layout: layout ?? this.layout,
    selected: selected ?? this.selected,
    images: images ?? this.images,
    shape: shape ?? this.shape,
    imageFit: imageFit ?? this.imageFit,
    imagePosition: imagePosition ?? this.imagePosition,
    artworkStyle: artworkStyle ?? this.artworkStyle,
  );
}

/// Match existing module switches, including scheduled plan changes, without Firebase reads.
List<String> serviceShowcaseEnabledModules(Map<String, dynamic> shop) {
  Iterable<String> modules;
  if (ShopPlanAccess.scheduleApplied(shop)) {
    modules = ShopPlanAccess.modulesFor(
      shop,
      ShopPlanAccess.effectivePlan(shop),
    );
  } else {
    final raw = shop['enabledModules'];
    final values = raw is List
        ? raw.whereType<String>().where(ShopModules.all.contains).toList()
        : <String>[];
    modules = values.isEmpty ? ShopModules.defaultEnabled : values;
  }
  return modules.where(ShopServiceShowcase.labels.containsKey).toSet().toList();
}
