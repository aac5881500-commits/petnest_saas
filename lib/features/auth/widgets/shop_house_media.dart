import 'package:flutter/material.dart';
import '../../../core/models/platform_media_asset.dart';
import '../../../core/models/shop_house_appearance.dart';
import '../../../core/services/platform_media_library_service.dart';

/// 圖庫只解析素材；不寫入店家資料。相同 Firestore 查詢由 SDK 共用連線。
class ShopHouseMediaBuilder extends StatefulWidget {
  const ShopHouseMediaBuilder({
    super.key,
    required this.appearance,
    required this.builder,
    this.assetsOverride,
  });
  final ShopHouseAppearance appearance;
  final Widget Function(ShopHouseMedia media) builder;
  final List<PlatformMediaAsset>? assetsOverride;
  @override
  State<ShopHouseMediaBuilder> createState() => _ShopHouseMediaBuilderState();
}

class _ShopHouseMediaBuilderState extends State<ShopHouseMediaBuilder> {
  Stream<List<PlatformMediaAsset>>? _stream;
  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant ShopHouseMediaBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance.selectedIds.isEmpty !=
            widget.appearance.selectedIds.isEmpty ||
        oldWidget.assetsOverride != widget.assetsOverride) {
      _connect();
    }
  }

  void _connect() {
    _stream =
        widget.appearance.selectedIds.isEmpty || widget.assetsOverride != null
        ? null
        : PlatformMediaLibraryService.instance.streamEnabledAssets(
            PlatformMediaCategories.shopHouse,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return widget.builder(
        ShopHouseMedia(widget.appearance, widget.assetsOverride ?? const []),
      );
    }
    return StreamBuilder<List<PlatformMediaAsset>>(
      stream: _stream,
      builder: (_, snapshot) => widget.builder(
        ShopHouseMedia(
          widget.appearance,
          snapshot.hasError ? const [] : snapshot.data ?? const [],
        ),
      ),
    );
  }
}

@immutable
class ShopHouseMedia {
  const ShopHouseMedia(this.appearance, this.assets);
  static const empty = ShopHouseMedia(ShopHouseAppearance.empty, []);
  final ShopHouseAppearance appearance;
  final List<PlatformMediaAsset> assets;

  PlatformMediaAsset? assetFor(String placement, {bool wide = true}) {
    final ids = placement == ShopHousePlacements.roof && !wide
        ? [appearance.roofPhoneAssetId, appearance.roofAssetId]
        : [appearance.idFor(placement)];
    for (final id in ids) {
      if (id.isEmpty) continue;
      for (final asset in assets) {
        if (asset.id == id &&
            asset.enabled &&
            asset.hasUsableUrl &&
            asset.allowsPlacement(placement) &&
            (placement != ShopHousePlacements.roof ||
                asset.supportsDevice(wide ? 'desktop' : 'phone') ||
                (!wide &&
                    id == appearance.roofAssetId &&
                    asset.device == 'desktop'))) {
          return asset;
        }
      }
    }
    return null;
  }
}

/// 遠端失敗回到既有本機素材；幾何尺寸由呼叫端負責。
Widget shopHouseImage({
  required ShopHouseMedia media,
  required String placement,
  required Widget fallback,
  bool wide = true,
  Key? imageKey,
  BoxFit fit = BoxFit.contain,
  Animation<double>? opacity,
}) {
  final asset = media.assetFor(placement, wide: wide);
  if (asset == null) return fallback;
  final slicedBase =
      placement == ShopHousePlacements.base &&
      const {
        'base.png',
        'romantic_garden_base.png',
        'modern_japanese_base.png',
      }.contains(asset.sourceFileName) &&
      asset.width == 2172 &&
      asset.height == 285;
  return Image.network(
    asset.houseImageUrl,
    scale: slicedBase ? 4 : 1,
    centerSlice: slicedBase ? const Rect.fromLTRB(180, 30, 1992, 255) : null,
    key: imageKey,
    fit: slicedBase ? BoxFit.fill : fit,
    opacity: opacity,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) {
      if (placement == ShopHousePlacements.roof && !wide) {
        final desktop = media.assetFor(placement, wide: true);
        if (desktop != null && desktop.id != asset.id) {
          return Image.network(
            desktop.houseImageUrl,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      }
      return fallback;
    },
  );
}
