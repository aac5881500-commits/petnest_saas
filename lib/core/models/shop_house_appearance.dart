// 檔案名稱：lib/core/models/shop_house_appearance.dart
// 功能說明：店家小屋各區域選用的平台圖庫 assetId。空字串代表 PetNest 預設。

import 'platform_media_asset.dart';

class ShopHouseAppearance {
  const ShopHouseAppearance({
    this.roofAssetId = '',
    this.wallAssetId = '',
    this.windowFrameAssetId = '',
    this.decorationLeftAssetId = '',
    this.decorationRightAssetId = '',
    this.decorationTopAssetId = '',
    this.baseAssetId = '',
  });

  static const String fieldName = 'houseAppearance';
  static const ShopHouseAppearance empty = ShopHouseAppearance();

  final String roofAssetId;
  final String wallAssetId;
  final String windowFrameAssetId;
  final String decorationLeftAssetId;
  final String decorationRightAssetId;
  final String decorationTopAssetId;
  final String baseAssetId;

  factory ShopHouseAppearance.fromMap(Object? raw) {
    if (raw is! Map) {
      return empty;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return ShopHouseAppearance(
      roofAssetId: _id(map['roofAssetId']),
      wallAssetId: _id(map['wallAssetId']),
      windowFrameAssetId: _id(map['windowFrameAssetId']),
      decorationLeftAssetId: _id(map['decorationLeftAssetId']),
      decorationRightAssetId: _id(map['decorationRightAssetId']),
      decorationTopAssetId: _id(map['decorationTopAssetId']),
      baseAssetId: _id(map['baseAssetId']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'roofAssetId': roofAssetId,
      'wallAssetId': wallAssetId,
      'windowFrameAssetId': windowFrameAssetId,
      'decorationLeftAssetId': decorationLeftAssetId,
      'decorationRightAssetId': decorationRightAssetId,
      'decorationTopAssetId': decorationTopAssetId,
      'baseAssetId': baseAssetId,
    };
  }

  String idFor(String placement) {
    switch (placement) {
      case ShopHousePlacements.roof:
        return roofAssetId;
      case ShopHousePlacements.wall:
        return wallAssetId;
      case ShopHousePlacements.windowFrame:
        return windowFrameAssetId;
      case ShopHousePlacements.decorationLeft:
        return decorationLeftAssetId;
      case ShopHousePlacements.decorationRight:
        return decorationRightAssetId;
      case ShopHousePlacements.decorationTop:
        return decorationTopAssetId;
      case ShopHousePlacements.base:
        return baseAssetId;
      default:
        return '';
    }
  }

  ShopHouseAppearance withPlacement(String placement, String assetId) {
    final String id = assetId.trim();
    switch (placement) {
      case ShopHousePlacements.roof:
        return ShopHouseAppearance(
          roofAssetId: id,
          wallAssetId: wallAssetId,
          windowFrameAssetId: windowFrameAssetId,
          decorationLeftAssetId: decorationLeftAssetId,
          decorationRightAssetId: decorationRightAssetId,
          decorationTopAssetId: decorationTopAssetId,
          baseAssetId: baseAssetId,
        );
      case ShopHousePlacements.wall:
        return ShopHouseAppearance(
          roofAssetId: roofAssetId,
          wallAssetId: id,
          windowFrameAssetId: windowFrameAssetId,
          decorationLeftAssetId: decorationLeftAssetId,
          decorationRightAssetId: decorationRightAssetId,
          decorationTopAssetId: decorationTopAssetId,
          baseAssetId: baseAssetId,
        );
      case ShopHousePlacements.windowFrame:
        return ShopHouseAppearance(
          roofAssetId: roofAssetId,
          wallAssetId: wallAssetId,
          windowFrameAssetId: id,
          decorationLeftAssetId: decorationLeftAssetId,
          decorationRightAssetId: decorationRightAssetId,
          decorationTopAssetId: decorationTopAssetId,
          baseAssetId: baseAssetId,
        );
      case ShopHousePlacements.decorationLeft:
        return ShopHouseAppearance(
          roofAssetId: roofAssetId,
          wallAssetId: wallAssetId,
          windowFrameAssetId: windowFrameAssetId,
          decorationLeftAssetId: id,
          decorationRightAssetId: decorationRightAssetId,
          decorationTopAssetId: decorationTopAssetId,
          baseAssetId: baseAssetId,
        );
      case ShopHousePlacements.decorationRight:
        return ShopHouseAppearance(
          roofAssetId: roofAssetId,
          wallAssetId: wallAssetId,
          windowFrameAssetId: windowFrameAssetId,
          decorationLeftAssetId: decorationLeftAssetId,
          decorationRightAssetId: id,
          decorationTopAssetId: decorationTopAssetId,
          baseAssetId: baseAssetId,
        );
      case ShopHousePlacements.decorationTop:
        return ShopHouseAppearance(
          roofAssetId: roofAssetId,
          wallAssetId: wallAssetId,
          windowFrameAssetId: windowFrameAssetId,
          decorationLeftAssetId: decorationLeftAssetId,
          decorationRightAssetId: decorationRightAssetId,
          decorationTopAssetId: id,
          baseAssetId: baseAssetId,
        );
      case ShopHousePlacements.base:
        return ShopHouseAppearance(
          roofAssetId: roofAssetId,
          wallAssetId: wallAssetId,
          windowFrameAssetId: windowFrameAssetId,
          decorationLeftAssetId: decorationLeftAssetId,
          decorationRightAssetId: decorationRightAssetId,
          decorationTopAssetId: decorationTopAssetId,
          baseAssetId: id,
        );
      default:
        return this;
    }
  }

  Iterable<String> get selectedIds sync* {
    for (final String placement in ShopHousePlacements.known) {
      final String id = idFor(placement);
      if (id.isNotEmpty) {
        yield id;
      }
    }
  }

  static String _id(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
