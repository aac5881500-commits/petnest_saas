import '../../../core/models/platform_media_asset.dart';
import 'shop_house_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 本頁的庭院環境層；木屋、資料與互動仍各自獨立。
class ShopHouseCourtyard extends StatelessWidget {
  const ShopHouseCourtyard({
    super.key,
    this.media = ShopHouseMedia.empty,
    required this.child,
    required this.wide,
    this.backgroundAsset = assetPath,
  });
  static const assetPath =
      'assets/images/shop_house/warm_wood/courtyard_daylight.jpg';
  final Widget child;
  final bool wide;
  final String backgroundAsset;

  final ShopHouseMedia media;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 28 : 20),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [const Color(0xFF263A3E), const Color(0xFF34382A)]
                        : [
                            const Color(0xFFE8F2F4),
                            const Color(0xFFFFF9EA),
                            const Color(0xFFE5ECD8),
                          ],
                  ),
                ),
                child: shopHouseImage(
                  media: media,
                  placement: ShopHousePlacements.sceneBackground,
                  imageKey: const ValueKey('house-courtyard-remote'),
                  fit: BoxFit.cover,
                  opacity: AlwaysStoppedAnimation(dark ? .24 : .90),
                  fallback: Image.asset(
                    backgroundAsset,
                    key: const ValueKey('house-courtyard-background'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    opacity: AlwaysStoppedAnimation(dark ? .24 : .90),
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(
                      key: ValueKey('house-courtyard-fallback'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 16 : 6,
              wide ? 18 : 10,
              wide ? 16 : 6,
              wide ? 22 : 14,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 裝飾載入失敗時安靜隱藏，不攔截既有照片與按鈕。
class ShopHouseDecoration extends StatelessWidget {
  const ShopHouseDecoration({
    super.key,
    required this.asset,
    this.media = ShopHouseMedia.empty,
    this.placement = ShopHousePlacements.decorationLeft,
  });
  final ShopHouseMedia media;
  final String placement;
  final String asset;

  @override
  Widget build(BuildContext context) => shopHouseImage(
    media: media,
    placement: placement,
    imageKey: ValueKey(placement),
    fallback: Image.asset(
      asset,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

/// 僅裁去手機屋頂右下方的對稱吊燈，保留原圖木瓦、招牌與左側藤蔓。
class _MobileRoofClipper extends CustomClipper<Path> {
  const _MobileRoofClipper();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height * .69)
    ..lineTo(size.width * .85, size.height * .69)
    ..lineTo(size.width * .85, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(covariant _MobileRoofClipper oldClipper) => false;
}

class _HouseSignLabel extends StatelessWidget {
  const _HouseSignLabel({required this.name, required this.wide});
  final String name;
  final bool wide;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final maximum = wide ? 28.0 : 14.0;
      final style = TextStyle(
        fontFamily: 'NotoSerifTC',
        fontSize: maximum,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF49301B),
      );
      final painter = TextPainter(
        text: TextSpan(text: name, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final fitted = painter.width > box.maxWidth
          ? maximum * box.maxWidth / painter.width
          : maximum;
      painter.dispose();
      return Center(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style.copyWith(
            fontSize: fitted.clamp(wide ? 18 : 11, maximum),
          ),
        ),
      );
    },
  );
}

class _HouseRoofFallback extends CustomPainter {
  const _HouseRoofFallback(this.sign);
  final Rect sign;

  @override
  void paint(Canvas canvas, Size size) {
    final eave = size.height * .76;
    final roof = Path()
      ..moveTo(4, eave)
      ..lineTo(size.width / 2, 4)
      ..lineTo(size.width - 4, eave)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFE0BD8B));
    canvas.drawPath(
      roof,
      Paint()
        ..color = const Color(0xFF98714B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    final plaque = Rect.fromLTWH(
      size.width * sign.left,
      size.height * sign.top,
      size.width * sign.width,
      size.height * sign.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plaque.inflate(4), const Radius.circular(6)),
      Paint()..color = const Color(0xFFF5DFC0),
    );
  }

  @override
  bool shouldRepaint(covariant _HouseRoofFallback oldDelegate) =>
      oldDelegate.sign != sign;
}

Widget _housePhotoFallback(
  BuildContext context,
  Object error,
  StackTrace? stack,
) => const ColoredBox(
  key: ValueKey('house-photo-fallback'),
  color: Color(0xFFF3E5CE),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.photo_outlined, color: Color(0xFF8C6844)),
        SizedBox(height: 6),
        Text('店家照片', style: TextStyle(color: Color(0xFF674E38))),
      ],
    ),
  ),
);

/// PageView 仍使用明確高度，子頁則量測自然高度，避免固定預留的空白牆面。
class ShopHouseMeasuredBody extends StatelessWidget {
  const ShopHouseMeasuredBody({
    super.key,
    required this.onHeight,
    required this.child,
  });
  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => OverflowBox(
    alignment: Alignment.topCenter,
    minHeight: 0,
    maxHeight: double.infinity,
    child: _HouseHeightReporter(onHeight: onHeight, child: child),
  );
}

class _HouseHeightReporter extends SingleChildRenderObjectWidget {
  const _HouseHeightReporter({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HouseHeightRender(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _HouseHeightRender renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _HouseHeightRender extends RenderProxyBox {
  _HouseHeightRender(this.onHeight);
  ValueChanged<double> onHeight;
  double? previousHeight;
  @override
  void performLayout() {
    super.performLayout();
    if (size.height == previousHeight) return;
    previousHeight = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}

/// 本頁專用的素材組。未來風格只需提供各部件與對應的幾何區域，
/// 不參與店家資料、權限或任何儲存流程。
@immutable
class ShopHouseArtwork {
  const ShopHouseArtwork({
    required this.roofWide,
    required this.roofPhone,
    required this.window,
    required this.plants,
    required this.base,
    required this.defaultPhoto,
    required this.wallColor,
    this.roofWideAspect = 3,
    this.roofPhoneAspect = 3,
    this.wideSign = const Rect.fromLTWH(.375, .49, .25, .18),
    this.phoneSign = const Rect.fromLTWH(.375, .49, .25, .18),
    this.windowOpening = const Rect.fromLTWH(.18, .15, .64, .64),
    this.baseCenterSlice = const Rect.fromLTRB(180, 30, 1992, 255),
    this.baseImageScale = 4,
  });

  final String roofWide;
  final String roofPhone;
  final String window;
  final String plants;
  final String base;
  final String defaultPhoto;
  final Color wallColor;
  final double roofWideAspect;
  final double roofPhoneAspect;
  final Rect wideSign;
  final Rect phoneSign;
  final Rect windowOpening;
  final Rect? baseCenterSlice;
  final double baseImageScale;

  static const warmWood = ShopHouseArtwork(
    roofWide: 'assets/images/shop_house/warm_wood/roof_wide.png',
    // 手機沿用較低的寬屋頂原圖，不壓扁木瓦；舊手機素材仍保留。
    roofPhone: 'assets/images/shop_house/warm_wood/roof_wide.png',
    window: 'assets/images/shop_house/warm_wood/window.png',
    plants: 'assets/images/shop_house/warm_wood/plants.png',
    base: 'assets/images/shop_house/warm_wood/base.png',
    defaultPhoto: 'assets/images/shop_house/warm_wood/cat_default.png',
    wallColor: Color(0xFFFFF9ED),
  );

  double roofHeight(double width, bool wide) =>
      width / (wide ? roofWideAspect : roofPhoneAspect);
  Rect signRect(bool wide) => wide ? wideSign : phoneSign;
}

/// 圖片只負責建築外觀；內容始終是可操作的 Flutter 元件。
class ShopHouseScene extends StatelessWidget {
  const ShopHouseScene({
    super.key,
    this.media = ShopHouseMedia.empty,
    required this.shopName,
    required this.wide,
    required this.child,
    this.artwork = ShopHouseArtwork.warmWood,
  });
  final String shopName;
  final bool wide;
  final Widget child;
  final ShopHouseArtwork artwork;

  final ShopHouseMedia media;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      final roofAsset = media.assetFor(ShopHousePlacements.roof, wide: wide);
      final roofHeight =
          roofAsset != null && roofAsset.width > 0 && roofAsset.height > 0
          ? (width * roofAsset.height / roofAsset.width).clamp(
              width * .15,
              width * .8,
            )
          : artwork.roofHeight(width, wide);
      final inset = wide ? 36.0 : 10.0;
      final sign = !wide && roofAsset?.sourceFileName == 'roof_phone.png'
          ? const Rect.fromLTWH(.30, .57, .40, .24)
          : artwork.signRect(wide);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final baseHeight = wide ? 54.0 : 28.0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: roofHeight * (wide ? .70 : .64),
              left: inset,
              right: inset,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xFF40372C), const Color(0xFF2F2923)]
                      : [
                          const Color(0xFFFFFDF7),
                          artwork.wallColor,
                          const Color(0xFFF8E7CC),
                        ],
                ),
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: const Color(0xFFCBA471).withValues(alpha: .7),
                    width: wide ? 9 : 5,
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20836640),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (media.assetFor(ShopHousePlacements.wall) != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: shopHouseImage(
                          media: media,
                          placement: ShopHousePlacements.wall,
                          imageKey: const ValueKey('house-wall-remote'),
                          fit: BoxFit.cover,
                          fallback: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 10,
                      roofHeight * .12,
                      wide ? 28 : 10,
                      baseHeight * .6 + (wide ? 16 : 6),
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: roofHeight,
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipPath(
                    clipper: wide || roofAsset != null
                        ? null
                        : const _MobileRoofClipper(),
                    child: shopHouseImage(
                      media: media,
                      placement: ShopHousePlacements.roof,
                      wide: wide,
                      imageKey: const ValueKey('house-roof-remote'),
                      fallback: Image.asset(
                        key: const ValueKey('house-roof-artwork'),
                        wide ? artwork.roofWide : artwork.roofPhone,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => CustomPaint(
                          key: const ValueKey('house-roof-fallback'),
                          painter: _HouseRoofFallback(sign),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * sign.left,
                    top: roofHeight * sign.top,
                    width: width * sign.width,
                    height: roofHeight * sign.height,
                    child: _HouseSignLabel(name: shopName, wide: wide),
                  ),
                ],
              ),
            ),
          ),
          // 裝飾只佔邊緣，按鈕區保持完整的點擊範圍。
          if (wide)
            Positioned(
              left: 0,
              bottom: baseHeight * .45,
              width: 130,
              child: IgnorePointer(
                child: ShopHouseDecoration(
                  asset: artwork.plants,
                  media: media,
                  placement: ShopHousePlacements.decorationLeft,
                ),
              ),
            ),
          if (wide)
            Positioned(
              right: 0,
              bottom: baseHeight * .45,
              width: 95,
              child: IgnorePointer(
                child: ShopHouseDecoration(
                  asset: artwork.plants,
                  media: media,
                  placement: ShopHousePlacements.decorationRight,
                ),
              ),
            ),
          if (!wide &&
              media.assetFor(ShopHousePlacements.decorationRight) != null)
            Positioned(
              right: 0,
              bottom: baseHeight * .45,
              width: 35,
              child: IgnorePointer(
                child: shopHouseImage(
                  media: media,
                  placement: ShopHousePlacements.decorationRight,
                  imageKey: const ValueKey('house-right-remote'),
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),
          if (media.assetFor(ShopHousePlacements.decorationTop) != null)
            Positioned(
              left: width * .04,
              top: roofHeight * .8,
              width: width * .12,
              height: roofHeight * .25,
              child: IgnorePointer(
                child: shopHouseImage(
                  media: media,
                  placement: ShopHousePlacements.decorationTop,
                  imageKey: const ValueKey('house-top-remote'),
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: baseHeight,
            child: IgnorePointer(
              child: shopHouseImage(
                media: media,
                placement: ShopHousePlacements.base,
                imageKey: const ValueKey('house-base-remote'),
                fallback: Image.asset(
                  key: const ValueKey('house-base-artwork'),
                  artwork.base,
                  scale: artwork.baseImageScale,
                  centerSlice: artwork.baseCenterSlice,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    key: ValueKey('house-base-fallback'),
                    decoration: BoxDecoration(
                      color: Color(0xFFD9B887),
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      border: Border(
                        top: BorderSide(color: Color(0xFFB78B58), width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ShopHouseDisplayWindow extends StatelessWidget {
  const ShopHouseDisplayWindow({
    super.key,
    this.media = ShopHouseMedia.empty,
    required this.coverUrl,
    required this.logoUrl,
    required this.allowPhotoHint,
    required this.onEditMedia,
    this.artwork = ShopHouseArtwork.warmWood,
    this.fallbackLogoUrl = '',
    this.fallbackCoverUrl = '',
  });
  final String fallbackLogoUrl;
  final String fallbackCoverUrl;
  final String coverUrl;
  final String logoUrl;
  final bool allowPhotoHint;
  final VoidCallback onEditMedia;
  final ShopHouseArtwork artwork;

  final ShopHouseMedia media;

  @override
  Widget build(BuildContext context) {
    final hasLogo =
        logoUrl.trim().isNotEmpty || fallbackLogoUrl.trim().isNotEmpty;
    final hasPhoto =
        coverUrl.trim().isNotEmpty || fallbackCoverUrl.trim().isNotEmpty;
    final hasMedia = hasLogo || hasPhoto;
    Widget defaultPhoto() => shopHouseImage(
      media: media,
      placement: ShopHousePlacements.defaultPhoto,
      imageKey: const ValueKey('shop-library-default'),
      fit: BoxFit.cover,
      fallback: Image.asset(
        artwork.defaultPhoto,
        key: const ValueKey('shop-default-cat'),
        fit: BoxFit.cover,
        semanticLabel: '預設貓咪展示圖',
        errorBuilder: _housePhotoFallback,
      ),
    );
    final candidates = <(String, bool)>[
      (logoUrl.trim(), true),
      (fallbackLogoUrl.trim(), true),
      (coverUrl.trim(), false),
      (fallbackCoverUrl.trim(), false),
    ].where((entry) => entry.$1.isNotEmpty).toList();
    Widget photoAt(int index, double size) {
      if (index >= candidates.length) return defaultPhoto();
      final (url, logo) = candidates[index];
      return ColoredBox(
        color: const Color(0xFFFFFCF4),
        child: Padding(
          padding: EdgeInsets.all(logo ? size * .025 : 0),
          child: Image.network(
            url,
            key: ValueKey(logo ? 'shop-logo' : 'shop-uploaded-photo'),
            fit: logo ? BoxFit.contain : BoxFit.cover,
            semanticLabel: logo ? '店家 Logo' : '店家照片',
            errorBuilder: (_, _, _) => photoAt(index + 1, size),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.maxWidth;
          final opening = artwork.windowOpening;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: size * opening.left,
                right: size * (1 - opening.right),
                top: size * opening.top,
                bottom: size * (1 - opening.bottom),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: photoAt(0, size),
                ),
              ),
              IgnorePointer(
                child: shopHouseImage(
                  media: media,
                  placement: ShopHousePlacements.windowFrame,
                  imageKey: const ValueKey('house-window-remote'),
                  fallback: Image.asset(
                    key: const ValueKey('house-window-artwork'),
                    artwork.window,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Padding(
                      key: const ValueKey('house-window-fallback'),
                      padding: EdgeInsets.fromLTRB(
                        size * opening.left,
                        size * opening.top,
                        size * (1 - opening.right),
                        size * (1 - opening.bottom),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFB99365),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (allowPhotoHint)
                Positioned(
                  left: size * .18,
                  right: size * .18,
                  bottom: 0,
                  child: Align(
                    alignment: hasMedia
                        ? Alignment.bottomLeft
                        : Alignment.bottomCenter,
                    child: hasMedia
                        ? IconButton.filledTonal(
                            tooltip: '編輯照片',
                            onPressed: onEditMedia,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xE6FFF6E5),
                              foregroundColor: const Color(0xFF674E38),
                              minimumSize: const Size(44, 44),
                            ),
                          )
                        : Material(
                            color: const Color(0xBB49301B),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: onEditMedia,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '加入店家照片',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
