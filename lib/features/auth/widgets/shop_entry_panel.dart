// 檔案名稱：lib/features/auth/widgets/shop_entry_panel.dart
// 功能說明：暖木小屋外框只負責裝飾，店家內容放在 child 裡。屋頂區佔有自己的高度，避免被父層裁切。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_badges.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_meta_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_qr_link_card.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_stat_row.dart';

/// 第一套預設：暖木小屋。顏色集中在這裡，之後可整組換成平台外框。
class _WarmWoodPalette {
  const _WarmWoodPalette({
    required this.roof,
    required this.roofEdge,
    required this.wall,
    required this.base,
    required this.plaque,
    required this.glow,
    required this.wallLight,
  });

  final Color roof;
  final Color roofEdge;
  final Color wall;
  final Color base;
  final Color plaque;
  final Color glow;
  final Color wallLight;

  static _WarmWoodPalette of(ColorScheme colors) {
    final bool dark = colors.brightness == Brightness.dark;
    const Color wood = Color(0xFFC4A574);
    const Color woodDeep = Color(0xFF8C6844);
    return _WarmWoodPalette(
      roof: dark ? const Color(0xFF8D6A45) : wood,
      roofEdge: dark ? const Color(0xFF6E5134) : woodDeep,
      wall: dark
          ? Color.alphaBlend(const Color(0xFF3A3128), colors.surface)
          : const Color(0xFFFFFBF6),
      base: dark ? const Color(0xFF6B5340) : const Color(0xFFE4D0B4),
      plaque: dark ? const Color(0xFF4A3B2E) : const Color(0xFFF3E4D0),
      glow: Colors.white.withValues(alpha: dark ? 0.04 : 0.12),
      wallLight: colors.primary.withValues(alpha: dark ? 0.05 : 0.035),
    );
  }
}

class ShopEntryPanel extends StatelessWidget {
  const ShopEntryPanel({
    super.key,
    required this.shopName,
    required this.shopId,
    required this.shopCode,
    required this.businessType,
    required this.city,
    required this.district,
    required this.role,
    required this.coverUrl,
    required this.logoUrl,
    required this.isOpenNow,
    required this.isPublic,
    required this.enabledModules,
    required this.openTime,
    required this.closeTime,
    required this.licenseNumber,
    required this.taxId,
    required this.updatedAt,
    required this.onEnter,
    required this.onEditMedia,
    this.showHero = true,
    this.showDetails = true,
    this.allowPhotoHint = false,
    this.statsFuture,
    this.roofAssetId = '',
  });

  final String shopName;
  final String shopId;
  final String shopCode;
  final String businessType;
  final String city;
  final String district;
  final String role;
  final String coverUrl;
  final String logoUrl;
  final bool isOpenNow;
  final bool isPublic;
  final List<String> enabledModules;
  final String openTime;
  final String closeTime;
  final String licenseNumber;
  final String taxId;
  final dynamic updatedAt;
  final VoidCallback onEnter;
  final VoidCallback onEditMedia;
  final bool showHero;
  final bool showDetails;
  final bool allowPhotoHint;
  final Future<Map<String, int>>? statsFuture;
  final String roofAssetId;

  /// 屋頂區高度。有圖片比例時用寬度除以比例，再限制在屋頂區範圍內。
  /// 沒有素材時使用同一個範圍裡的預設高度，不另做一套屋頂。
  static double roofZoneHeight({
    required double availableWidth,
    required bool wide,
    double? imageAspectRatio,
  }) {
    final double minHeight = wide ? 120 : 90;
    final double maxHeight = wide ? 170 : 130;
    final double aspect = imageAspectRatio ?? 0;
    if (availableWidth <= 0 || aspect <= 0 || !aspect.isFinite) {
      return wide ? 146 : 110;
    }
    return (availableWidth / aspect).clamp(minHeight, maxHeight);
  }

  /// 平台屋頂的水平放大。以完整 contain 後的寬度為準，把屋簷拉向房子兩側。
  /// 超過 [maxRoofScaleX] 就停住，避免把窄圖拉到變形。
  static const double maxRoofScaleX = 1.6;

  static double roofFitScaleX({
    required double houseWidth,
    required double roofHeight,
    required double imageAspectRatio,
    required bool wide,
  }) {
    if (houseWidth <= 0 ||
        roofHeight <= 0 ||
        imageAspectRatio <= 0 ||
        !imageAspectRatio.isFinite) {
      return 1;
    }
    final double slotAspect = houseWidth / roofHeight;
    final double containedWidth = imageAspectRatio >= slotAspect
        ? houseWidth
        : roofHeight * imageAspectRatio;
    if (containedWidth <= 0) {
      return 1;
    }
    final double targetWidth = houseWidth * (wide ? 1.03 : 1.07);
    final double needed = targetWidth / containedWidth;
    if (needed <= 1) {
      return 1;
    }
    return needed > maxRoofScaleX ? maxRoofScaleX : needed;
  }

  /// PageView 需要明確高度。對齊整棟小屋，避免窄螢幕 overflow。
  static double heroHeightFor(double width, {double textScale = 1}) {
    final double scale = textScale < 1 ? 1 : textScale;
    final double extra = scale <= 1 ? 0 : (scale - 1) * 140;
    if (width >= 1160) {
      return 620 + extra;
    }
    if (width >= 1000) {
      return 660 + extra;
    }
    if (width >= 760) {
      return 680 + extra;
    }
    if (width >= 700) {
      return 720 + extra;
    }
    return 960 + extra;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool wide = width >= 700;
        final Widget house = _PetNestHouseShell(
          wide: wide,
          roofAssetId: roofAssetId,
          child: _HouseInterior(
            shopName: shopName,
            shopId: shopId,
            shopCode: shopCode,
            businessType: businessType,
            city: city,
            district: district,
            role: role,
            coverUrl: coverUrl,
            logoUrl: logoUrl,
            isOpenNow: isOpenNow,
            isPublic: isPublic,
            wide: wide,
            allowPhotoHint: allowPhotoHint,
            statsFuture: statsFuture,
            onEnter: onEnter,
            onEditMedia: onEditMedia,
          ),
        );
        final Widget file = _FileNest(
          child: MyShopMetaInfo(
            enabledModules: enabledModules,
            openTime: openTime,
            closeTime: closeTime,
            isPublic: isPublic,
            licenseNumber: licenseNumber,
            taxId: taxId,
            updatedAt: updatedAt,
            city: city,
            district: district,
            shopId: shopId,
            businessType: businessType,
          ),
        );
        if (!showHero) {
          return file;
        }
        if (!showDetails) {
          return house;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[house, const SizedBox(height: 28), file],
        );
      },
    );
  }
}

class _FileNest extends StatelessWidget {
  const _FileNest({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '我的店家小檔案',
            style: text.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// 只畫屋頂、屋身、底座與很淡的裝飾。店家內容全部由 [child] 提供。
class _PetNestHouseShell extends StatefulWidget {
  const _PetNestHouseShell({
    required this.wide,
    required this.child,
    this.roofAssetId = '',
  });

  final bool wide;
  final Widget child;
  final String roofAssetId;

  @override
  State<_PetNestHouseShell> createState() => _PetNestHouseShellState();
}

class _PetNestHouseShellState extends State<_PetNestHouseShell> {
  bool _showPlatformRoof = false;
  double? _roofAspect;

  @override
  void didUpdateWidget(covariant _PetNestHouseShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roofAssetId != widget.roofAssetId) {
      _showPlatformRoof = false;
      _roofAspect = null;
    }
  }

  void _onRoofVisible(bool visible) {
    if (_showPlatformRoof == visible) {
      return;
    }
    setState(() {
      _showPlatformRoof = visible;
    });
  }

  void _onRoofAspect(double? aspect) {
    if (_roofAspect == aspect) {
      return;
    }
    setState(() {
      _roofAspect = aspect;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _WarmWoodPalette palette = _WarmWoodPalette.of(
      Theme.of(context).colorScheme,
    );
    final double wallInset = widget.wide ? 26 : 16;
    final double overlap = 12;
    final double base = widget.wide ? 24 : 20;
    final bool hasRoofId = widget.roofAssetId.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0;
        final double roof = ShopEntryPanel.roofZoneHeight(
          availableWidth: width,
          wide: widget.wide,
          imageAspectRatio: _roofAspect,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            CustomPaint(
              painter: _WarmWoodHousePainter(
                palette: palette,
                roofHeight: roof,
                wallInset: wallInset,
                eaveOverlap: overlap,
                baseHeight: base,
                paintRoof: !hasRoofId || !_showPlatformRoof,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: roof),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      wallInset + 18,
                      4,
                      wallInset + 18,
                      base + 14,
                    ),
                    child: widget.child,
                  ),
                ],
              ),
            ),
            // 裝飾層預留：wall、windowFrame、decorationLeft、decorationRight、
            // decorationTop、base。這一輪只有 roof 接平台素材，其餘用 Flutter 骨架。
            if (hasRoofId)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: roof,
                child: _PlatformRoofImage(
                  assetId: widget.roofAssetId,
                  wide: widget.wide,
                  onVisible: _onRoofVisible,
                  onAspect: _onRoofAspect,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlatformRoofImage extends StatefulWidget {
  const _PlatformRoofImage({
    required this.assetId,
    required this.wide,
    required this.onVisible,
    required this.onAspect,
  });

  final String assetId;
  final bool wide;
  final ValueChanged<bool> onVisible;
  final ValueChanged<double?> onAspect;

  @override
  State<_PlatformRoofImage> createState() => _PlatformRoofImageState();
}

class _PlatformRoofImageState extends State<_PlatformRoofImage> {
  late Future<PlatformMediaAsset?> _future;
  bool _reportedVisible = false;
  double? _reportedAspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _PlatformRoofImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _reportedVisible = false;
      _reportedAspect = null;
      _stopListening();
      _future = _load();
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  Future<PlatformMediaAsset?> _load() {
    return PlatformMediaLibraryService.instance.getEnabledAssetById(
      widget.assetId,
    );
  }

  void _stopListening() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _reportVisible(bool visible) {
    if (_reportedVisible == visible) {
      return;
    }
    _reportedVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onVisible(visible);
    });
  }

  void _reportAspect(double? aspect) {
    if (_reportedAspect == aspect) {
      return;
    }
    _reportedAspect = aspect;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onAspect(aspect);
    });
  }

  void _listenForAspect(String url) {
    if (_stream != null) {
      return;
    }
    final ImageStream stream = NetworkImage(
      url,
    ).resolve(const ImageConfiguration());
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final int width = info.image.width;
        final int height = info.image.height;
        if (width <= 0 || height <= 0) {
          return;
        }
        _reportAspect(width / height);
      },
      onError: (Object _, StackTrace? _) {
        _reportVisible(false);
        _reportAspect(null);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformMediaAsset?>(
      future: _future,
      builder:
          (BuildContext context, AsyncSnapshot<PlatformMediaAsset?> snapshot) {
            final PlatformMediaAsset? asset = snapshot.data;
            final String url =
                asset != null &&
                    asset.allowsPlacement(ShopHousePlacements.roof) &&
                    asset.imageUrl.trim().isNotEmpty
                ? asset.imageUrl
                : '';
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            if (url.isEmpty || asset == null) {
              _reportVisible(false);
              _reportAspect(null);
              return const SizedBox.shrink();
            }
            final double metaAspect = asset.width > 0 && asset.height > 0
                ? asset.width / asset.height
                : 0;
            if (metaAspect > 0) {
              _reportAspect(metaAspect);
            } else {
              _listenForAspect(url);
            }
            return _HouseRoofFit(
              wide: widget.wide,
              aspect: metaAspect > 0 ? metaAspect : (_reportedAspect ?? 0),
              child: Image.network(
                url,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) {
                  _reportVisible(false);
                  _reportAspect(null);
                  return const SizedBox.shrink();
                },
                frameBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      int? frame,
                      bool wasSynchronouslyLoaded,
                    ) {
                      if (frame != null || wasSynchronouslyLoaded) {
                        _reportVisible(true);
                        return child;
                      }
                      return const SizedBox.shrink();
                    },
              ),
            );
          },
    );
  }
}

/// 平台屋頂裝飾層。完整顯示圖片，再以屋簷底邊為準水平拉寬。
class _HouseRoofFit extends StatelessWidget {
  const _HouseRoofFit({
    required this.wide,
    required this.aspect,
    required this.child,
  });

  final bool wide;
  final double aspect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double houseWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0;
        final double roofHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0;
        final double scaleX = ShopEntryPanel.roofFitScaleX(
          houseWidth: houseWidth,
          roofHeight: roofHeight,
          imageAspectRatio: aspect,
          wide: wide,
        );
        final double overhang = wide ? 1.06 : 1.10;
        return OverflowBox(
          alignment: Alignment.bottomCenter,
          minWidth: 0,
          minHeight: 0,
          maxWidth: houseWidth * overhang,
          maxHeight: roofHeight,
          child: Transform.scale(
            scaleX: scaleX,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.medium,
            child: SizedBox(
              width: houseWidth,
              height: roofHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _WarmWoodHousePainter extends CustomPainter {
  const _WarmWoodHousePainter({
    required this.palette,
    required this.roofHeight,
    required this.wallInset,
    required this.eaveOverlap,
    required this.baseHeight,
    this.paintRoof = true,
  });

  final _WarmWoodPalette palette;
  final double roofHeight;
  final double wallInset;
  final double eaveOverlap;
  final double baseHeight;
  final bool paintRoof;

  @override
  void paint(Canvas canvas, Size size) {
    final double wallLeft = wallInset;
    final double wallRight = size.width - wallInset;
    final double wallTop = roofHeight - eaveOverlap;
    final double wallBottom = size.height - baseHeight;
    final RRect wall = RRect.fromRectAndRadius(
      Rect.fromLTRB(wallLeft, wallTop, wallRight, wallBottom),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      wall.shift(const Offset(0, 3)),
      Paint()
        ..color = palette.roofEdge.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final Paint wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Color.alphaBlend(palette.glow, palette.wall),
          palette.wall,
          Color.alphaBlend(palette.wallLight, palette.wall),
        ],
        stops: const <double>[0, 0.46, 1],
      ).createShader(wall.outerRect);
    canvas.drawRRect(wall, wallPaint);
    canvas.drawRRect(
      wall,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = palette.roofEdge.withValues(alpha: 0.22),
    );

    if (paintRoof) {
      const double lip = 14;
      const double ridgeY = 4;
      final double mid = size.width / 2;
      final double eaveY = roofHeight - 10;
      final Path roof = Path()
        ..moveTo(0, eaveY)
        ..lineTo(mid, ridgeY)
        ..lineTo(size.width, eaveY)
        ..lineTo(size.width, eaveY + lip)
        ..lineTo(mid, ridgeY + lip + 6)
        ..lineTo(0, eaveY + lip)
        ..close();
      canvas.drawPath(
        roof,
        Paint()
          ..color = palette.roofEdge.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(roof, Paint()..color = palette.roof);
      final Path eaveLip = Path()
        ..moveTo(0, eaveY + lip - 6)
        ..lineTo(mid, ridgeY + lip)
        ..lineTo(size.width, eaveY + lip - 6)
        ..lineTo(size.width, eaveY + lip)
        ..lineTo(mid, ridgeY + lip + 6)
        ..lineTo(0, eaveY + lip)
        ..close();
      canvas.drawPath(
        eaveLip,
        Paint()..color = palette.roofEdge.withValues(alpha: 0.88),
      );
    }

    final double extra = (wallRight - wallLeft) * 0.016;
    final Rect plinth = Rect.fromLTRB(
      (wallLeft - extra).clamp(0, size.width),
      wallBottom - 2,
      (wallRight + extra).clamp(0, size.width),
      size.height - 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        plinth.shift(const Offset(0, 2)),
        const Radius.circular(6),
      ),
      Paint()
        ..color = palette.roofEdge.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plinth, const Radius.circular(6)),
      Paint()..color = palette.base,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(plinth.left, plinth.top, plinth.right, plinth.top + 5),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          plinth.left,
          plinth.bottom - 5,
          plinth.right,
          plinth.bottom,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = palette.roofEdge.withValues(alpha: 0.34),
    );
  }

  @override
  bool shouldRepaint(covariant _WarmWoodHousePainter oldDelegate) {
    return oldDelegate.roofHeight != roofHeight ||
        oldDelegate.wallInset != wallInset ||
        oldDelegate.eaveOverlap != eaveOverlap ||
        oldDelegate.baseHeight != baseHeight ||
        oldDelegate.palette != palette ||
        oldDelegate.paintRoof != paintRoof;
  }
}

class _HouseInterior extends StatelessWidget {
  const _HouseInterior({
    required this.shopName,
    required this.shopId,
    required this.shopCode,
    required this.businessType,
    required this.city,
    required this.district,
    required this.role,
    required this.coverUrl,
    required this.logoUrl,
    required this.isOpenNow,
    required this.isPublic,
    required this.wide,
    required this.allowPhotoHint,
    required this.statsFuture,
    required this.onEnter,
    required this.onEditMedia,
  });

  final String shopName;
  final String shopId;
  final String shopCode;
  final String businessType;
  final String city;
  final String district;
  final String role;
  final String coverUrl;
  final String logoUrl;
  final bool isOpenNow;
  final bool isPublic;
  final bool wide;
  final bool allowPhotoHint;
  final Future<Map<String, int>>? statsFuture;
  final VoidCallback onEnter;
  final VoidCallback onEditMedia;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '歡迎回來',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        MyShopInfo(shopName: shopName, city: city, district: district),
        if (!wide) ...<Widget>[
          const SizedBox(height: 8),
          _ShopPlaque(shopId: shopId),
        ],
        if (businessType.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            businessType,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 8),
        MyShopBadges(role: role, isPublic: isPublic, isOpenNow: isOpenNow),
      ],
    );
    final Widget story = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: identity),
              const SizedBox(width: 12),
              _ShopPlaque(shopId: shopId),
            ],
          )
        else
          identity,
        const SizedBox(height: 14),
        _HouseToday(statsFuture: statsFuture),
        const SizedBox(height: 14),
        _ShopActions(shopCode: shopCode, stacked: !wide, onEnter: onEnter),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320;
        final double photoWidth = wide
            ? ((maxWidth - 22) * 0.40).clamp(220.0, 480.0)
            : maxWidth;
        final double photoHeight = wide ? 286 : 188;
        final Widget window = _ShopWindow(
          width: photoWidth,
          height: photoHeight,
          coverUrl: coverUrl,
          logoUrl: logoUrl,
          allowPhotoHint: allowPhotoHint,
          onEditMedia: onEditMedia,
        );
        if (!wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[window, const SizedBox(height: 14), story],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            window,
            const SizedBox(width: 22),
            Expanded(child: story),
          ],
        );
      },
    );
  }
}

class _ShopPlaque extends StatelessWidget {
  const _ShopPlaque({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final _WarmWoodPalette wood = _WarmWoodPalette.of(
      Theme.of(context).colorScheme,
    );
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 156),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: wood.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: wood.roofEdge.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: wood.roofEdge.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.storefront_outlined, size: 14, color: wood.roofEdge),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '店家編號',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: wood.roofEdge),
                ),
                Text(
                  shopId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF3E4D0)
                        : const Color(0xFF5C4A38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopWindow extends StatelessWidget {
  const _ShopWindow({
    required this.width,
    required this.height,
    required this.coverUrl,
    required this.logoUrl,
    required this.allowPhotoHint,
    required this.onEditMedia,
  });

  final double width;
  final double height;
  final String coverUrl;
  final String logoUrl;
  final bool allowPhotoHint;
  final VoidCallback onEditMedia;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _WarmWoodPalette wood = _WarmWoodPalette.of(colors);
    final bool hasCover = coverUrl.trim().isNotEmpty;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: wood.plaque,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: wood.roofEdge.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: wood.roofEdge.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: hasCover
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFF8F3EC), Color(0xFFEFE4D4)],
                      ),
                image: hasCover
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[Color(0x00000000), Color(0x246E5134)],
                  stops: <double>[0.72, 1],
                ),
              ),
            ),
            if (!hasCover)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.storefront_outlined,
                      size: 30,
                      color: colors.primary.withValues(alpha: 0.82),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '你的店，從這裡開始',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '加入一張店家照片，\n讓這裡更像自己的小天地。',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (allowPhotoHint) ...<Widget>[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: onEditMedia,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('加入店家照片'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (logoUrl.trim().isNotEmpty)
              Positioned(
                left: 10,
                bottom: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    logoUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (hasCover && allowPhotoHint)
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: const Color(0xFF2C241C).withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onEditMedia,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '編輯照片',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HouseToday extends StatelessWidget {
  const _HouseToday({required this.statsFuture});

  final Future<Map<String, int>>? statsFuture;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Future<Map<String, int>>? future = statsFuture;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '今天店裡',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        if (future == null)
          Text(
            '今天的店務還在整理。',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          )
        else
          FutureBuilder<Map<String, int>>(
            future: future,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Map<String, int>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Text(
                      '店務數字暫時無法讀取',
                      style: text.bodyMedium?.copyWith(color: colors.error),
                    );
                  }
                  final bool waiting =
                      snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;
                  if (waiting) {
                    return const SizedBox(height: 36);
                  }
                  final int pending = snapshot.data?['pendingOrders'] ?? 0;
                  final int transfers =
                      snapshot.data?['transferUploadedOrders'] ?? 0;
                  final bool calm = pending + transfers <= 0;
                  final Color accent = calm
                      ? const Color(0xFF3E7A4A)
                      : const Color(0xFFC47A3A);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            calm
                                ? Icons.check_circle_outline
                                : Icons.notifications_none,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shopTodayHeadline(pending, transfers),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: calm ? null : accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        shopTodaySubline(pending, transfers),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
          ),
        const SizedBox(height: 8),
        MyShopStatRow(
          shopId: 'house',
          statsFuture:
              future ??
              Future<Map<String, int>>.value(const <String, int>{
                'pendingOrders': 0,
                'transferUploadedOrders': 0,
                'memberCount': 0,
              }),
        ),
      ],
    );
  }
}

class _ShopActions extends StatelessWidget {
  const _ShopActions({
    required this.shopCode,
    required this.stacked,
    required this.onEnter,
  });

  final String shopCode;
  final bool stacked;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final _WarmWoodPalette wood = _WarmWoodPalette.of(
      Theme.of(context).colorScheme,
    );
    final Widget doorway = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: wood.plaque,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wood.roofEdge.withValues(alpha: 0.38)),
      ),
      child: FilledButton.icon(
        onPressed: onEnter,
        icon: const Icon(Icons.door_front_door_outlined, size: 18),
        label: const Text('進入我的店'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          doorway,
          const SizedBox(height: 8),
          MyShopQrLinkCard(shopCode: shopCode),
        ],
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double door = constraints.maxWidth * 0.60;
        return Row(
          children: <Widget>[
            SizedBox(width: door, child: doorway),
            const SizedBox(width: 4),
            Flexible(child: MyShopQrLinkCard(shopCode: shopCode, quiet: true)),
          ],
        );
      },
    );
  }
}
