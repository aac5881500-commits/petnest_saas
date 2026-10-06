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

  ShopHouseAppearance copyWith({
    String? roofAssetId,
    String? wallAssetId,
    String? windowFrameAssetId,
    String? decorationLeftAssetId,
    String? decorationRightAssetId,
    String? decorationTopAssetId,
    String? baseAssetId,
  }) {
    return ShopHouseAppearance(
      roofAssetId: roofAssetId ?? this.roofAssetId,
      wallAssetId: wallAssetId ?? this.wallAssetId,
      windowFrameAssetId: windowFrameAssetId ?? this.windowFrameAssetId,
      decorationLeftAssetId:
          decorationLeftAssetId ?? this.decorationLeftAssetId,
      decorationRightAssetId:
          decorationRightAssetId ?? this.decorationRightAssetId,
      decorationTopAssetId: decorationTopAssetId ?? this.decorationTopAssetId,
      baseAssetId: baseAssetId ?? this.baseAssetId,
    );
  }

  ShopHouseAppearance withPlacement(String placement, String assetId) {
    final String id = assetId.trim();
    switch (placement) {
      case ShopHousePlacements.roof:
        return copyWith(roofAssetId: id);
      case ShopHousePlacements.wall:
        return copyWith(wallAssetId: id);
      case ShopHousePlacements.windowFrame:
        return copyWith(windowFrameAssetId: id);
      case ShopHousePlacements.decorationLeft:
        return copyWith(decorationLeftAssetId: id);
      case ShopHousePlacements.decorationRight:
        return copyWith(decorationRightAssetId: id);
      case ShopHousePlacements.decorationTop:
        return copyWith(decorationTopAssetId: id);
      case ShopHousePlacements.base:
        return copyWith(baseAssetId: id);
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
