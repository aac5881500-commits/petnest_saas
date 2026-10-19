import 'platform_media_asset.dart';

/// 供現有圖庫編輯器選取的本機來源。選取僅預覽，儲存才走原上傳流程。
class ShopHouseLocalAsset {
  const ShopHouseLocalAsset(
    this.fileName,
    this.placements, {
    this.device = 'any',
    this.directory = 'warm_wood',
    this.displayName = '',
    this.sortOrder = 0,
  });
  final String fileName;
  final List<String> placements;
  final String device;
  final String directory;
  final String displayName;
  final int sortOrder;
  String get label => displayName.isEmpty ? fileName : displayName;
  String get path => 'assets/images/shop_house/$directory/$fileName';
  static const warmWoodEntries = <ShopHouseLocalAsset>[
    ShopHouseLocalAsset('roof_wide.png', [
      ShopHousePlacements.roof,
    ], device: 'desktop'),
    ShopHouseLocalAsset('roof_phone.png', [
      ShopHousePlacements.roof,
    ], device: 'phone'),
    ShopHouseLocalAsset('window.png', [ShopHousePlacements.windowFrame]),
    ShopHouseLocalAsset('plants.png', [
      ShopHousePlacements.decorationLeft,
      ShopHousePlacements.decorationRight,
    ]),
    ShopHouseLocalAsset('base.png', [ShopHousePlacements.base]),
    ShopHouseLocalAsset('courtyard_daylight.jpg', [
      ShopHousePlacements.sceneBackground,
    ]),
    ShopHouseLocalAsset('cat_default.png', [ShopHousePlacements.defaultPhoto]),
  ];

  /// 僅供平台編輯器選取；加入目錄不會上傳或替店家套用。
  static const entries = <ShopHouseLocalAsset>[
    ...warmWoodEntries,
    ShopHouseLocalAsset(
      'romantic_garden_roof_wide.png',
      [ShopHousePlacements.roof],
      directory: 'romantic_garden',
      displayName: '浪漫花園－桌機屋頂',
      device: 'desktop',
      sortOrder: 200,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_roof_phone.png',
      [ShopHousePlacements.roof],
      directory: 'romantic_garden',
      displayName: '浪漫花園－手機屋頂',
      device: 'phone',
      sortOrder: 201,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_wall.jpg',
      [ShopHousePlacements.wall],
      directory: 'romantic_garden',
      displayName: '浪漫花園－牆面',
      device: 'any',
      sortOrder: 202,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_window.png',
      [ShopHousePlacements.windowFrame],
      directory: 'romantic_garden',
      displayName: '浪漫花園－照片相框',
      device: 'any',
      sortOrder: 203,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_decoration_left.png',
      [ShopHousePlacements.decorationLeft],
      directory: 'romantic_garden',
      displayName: '浪漫花園－左側裝飾',
      device: 'any',
      sortOrder: 204,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_decoration_right.png',
      [ShopHousePlacements.decorationRight],
      directory: 'romantic_garden',
      displayName: '浪漫花園－右側裝飾',
      device: 'any',
      sortOrder: 205,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_decoration_top.png',
      [ShopHousePlacements.decorationTop],
      directory: 'romantic_garden',
      displayName: '浪漫花園－上方裝飾',
      device: 'any',
      sortOrder: 206,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_base.png',
      [ShopHousePlacements.base],
      directory: 'romantic_garden',
      displayName: '浪漫花園－底座',
      device: 'any',
      sortOrder: 207,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_courtyard.jpg',
      [ShopHousePlacements.sceneBackground],
      directory: 'romantic_garden',
      displayName: '浪漫花園－庭院背景',
      device: 'any',
      sortOrder: 208,
    ),
    ShopHouseLocalAsset(
      'romantic_garden_cat_default.jpg',
      [ShopHousePlacements.defaultPhoto],
      directory: 'romantic_garden',
      displayName: '浪漫花園－相框預設照片',
      device: 'any',
      sortOrder: 209,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_roof_wide.png',
      [ShopHousePlacements.roof],
      directory: 'modern_japanese',
      displayName: '現代日式－桌機屋頂',
      device: 'desktop',
      sortOrder: 300,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_roof_phone.png',
      [ShopHousePlacements.roof],
      directory: 'modern_japanese',
      displayName: '現代日式－手機屋頂',
      device: 'phone',
      sortOrder: 301,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_wall.jpg',
      [ShopHousePlacements.wall],
      directory: 'modern_japanese',
      displayName: '現代日式－牆面',
      device: 'any',
      sortOrder: 302,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_window.png',
      [ShopHousePlacements.windowFrame],
      directory: 'modern_japanese',
      displayName: '現代日式－照片相框',
      device: 'any',
      sortOrder: 303,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_decoration_left.png',
      [ShopHousePlacements.decorationLeft],
      directory: 'modern_japanese',
      displayName: '現代日式－左側裝飾',
      device: 'any',
      sortOrder: 304,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_decoration_right.png',
      [ShopHousePlacements.decorationRight],
      directory: 'modern_japanese',
      displayName: '現代日式－右側裝飾',
      device: 'any',
      sortOrder: 305,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_decoration_top.png',
      [ShopHousePlacements.decorationTop],
      directory: 'modern_japanese',
      displayName: '現代日式－上方裝飾',
      device: 'any',
      sortOrder: 306,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_base.png',
      [ShopHousePlacements.base],
      directory: 'modern_japanese',
      displayName: '現代日式－底座',
      device: 'any',
      sortOrder: 307,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_courtyard.jpg',
      [ShopHousePlacements.sceneBackground],
      directory: 'modern_japanese',
      displayName: '現代日式－庭院背景',
      device: 'any',
      sortOrder: 308,
    ),
    ShopHouseLocalAsset(
      'modern_japanese_cat_default.jpg',
      [ShopHousePlacements.defaultPhoto],
      directory: 'modern_japanese',
      displayName: '現代日式－相框預設照片',
      device: 'any',
      sortOrder: 309,
    ),
  ];

  static String? defaultPath(String placement) {
    for (final entry in warmWoodEntries) {
      if (entry.placements.contains(placement)) return entry.path;
    }
    return null; // 牆面使用既有漸層，上方裝飾已合成於原圖。
  }
}
