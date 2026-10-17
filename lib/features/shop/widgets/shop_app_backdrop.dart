// 檔案名稱：lib/features/shop/widgets/shop_app_backdrop.dart
// 功能說明：顧客端整頁背景。固定在內容下方，失效時退回頁面背景色。

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import 'package:petnest_saas/core/widgets/platform_media_library_scope.dart';

class ShopAppBackdrop extends StatefulWidget {
  const ShopAppBackdrop({
    super.key,
    required this.theme,
    this.assetOverride,
    this.imageProvider,
  });

  final HomeThemeModel theme;

  /// 測試或已解析的素材。正式頁面留空，改由圖庫 ID 查詢。
  final PlatformMediaAsset? assetOverride;
  final ImageProvider? imageProvider;

  static Widget behind({
    required HomeThemeModel theme,
    required Widget child,
    PlatformMediaAsset? assetOverride,
    ImageProvider? imageProvider,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: ShopAppBackdrop(
            theme: theme,
            assetOverride: assetOverride,
            imageProvider: imageProvider,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  @override
  State<ShopAppBackdrop> createState() => _ShopAppBackdropState();
}

class _ShopAppBackdropState extends State<ShopAppBackdrop> {
  PlatformMediaAsset? _asset;
  String _loadedId = '';
  String? _loadingId;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensure();
  }

  @override
  void didUpdateWidget(covariant ShopAppBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme.appBackgroundAssetId !=
            widget.theme.appBackgroundAssetId ||
        oldWidget.theme.appBackgroundMode != widget.theme.appBackgroundMode ||
        oldWidget.assetOverride?.id != widget.assetOverride?.id) {
      _failed = false;
      _loadedId = '';
      _loadingId = null;
      _asset = null;
      _ensure();
    }
  }

  void _ensure() {
    if (!widget.theme.usesAppBackgroundImage || widget.assetOverride != null) {
      return;
    }
    final String id = widget.theme.appBackgroundAssetId.trim();
    if (id.isEmpty || _loadingId == id || _loadedId == id) {
      return;
    }
    final PlatformMediaAsset? scoped = PlatformMediaLibraryScope.lookup(
      context,
      id,
    );
    if (_usable(scoped)) {
      _asset = scoped;
      _loadedId = id;
      return;
    }
    if (!_firebaseReady) {
      _loadedId = id;
      _asset = null;
      return;
    }
    _loadingId = id;
    PlatformMediaLibraryService.instance.getEnabledAssetById(id).then((
      PlatformMediaAsset? asset,
    ) {
      if (!mounted || widget.theme.appBackgroundAssetId.trim() != id) {
        return;
      }
      setState(() {
        _asset = _usable(asset) ? asset : null;
        _loadedId = id;
        _loadingId = null;
        _failed = false;
      });
    });
  }

  bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _usable(PlatformMediaAsset? asset) {
    if (asset == null || !asset.enabled || asset.imageUrl.trim().isEmpty) {
      return false;
    }
    return asset.category == PlatformMediaCategories.dailyCarePage ||
        asset.category == PlatformMediaCategories.appBackground;
  }

  PlatformMediaAsset? _resolved(BuildContext context) {
    if (!widget.theme.usesAppBackgroundImage) {
      return null;
    }
    final PlatformMediaAsset? override = widget.assetOverride;
    if (override != null) {
      return _usable(override) ? override : null;
    }
    final PlatformMediaAsset? scoped = PlatformMediaLibraryScope.lookup(
      context,
      widget.theme.appBackgroundAssetId,
    );
    if (_usable(scoped)) {
      return scoped;
    }
    if (_usable(_asset) &&
        _loadedId == widget.theme.appBackgroundAssetId.trim()) {
      return _asset;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;
    final Color pageColor = theme.backgroundColor;
    final PlatformMediaAsset? asset = _resolved(context);
    final bool showImage = asset != null && !_failed;
    final ImageProvider? provider = showImage
        ? widget.imageProvider ?? NetworkImage(asset.imageUrl)
        : null;
    final bool lightInk = theme.textColor.computeLuminance() > 0.6;
    final Color scrim = lightInk ? const Color(0xFF000000) : Colors.white;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: pageColor),
          if (provider != null)
            Positioned.fill(
              child: Image(
                key: ValueKey<String>(asset!.imageUrl),
                image: ResizeImage(
                  provider,
                  width: _cacheWidth(context),
                  policy: ResizeImagePolicy.fit,
                ),
                fit: theme.appBackgroundFit == ShopAppBackground.fitContain
                    ? BoxFit.contain
                    : BoxFit.cover,
                alignment: _alignment(theme.appBackgroundAlign),
                gaplessPlayback: true,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      if (!_failed) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _failed = true);
                          }
                        });
                      }
                      return const SizedBox.shrink();
                    },
              ),
            ),
          if (showImage && theme.appBackgroundScrim > 0)
            Positioned.fill(
              child: ColoredBox(
                color: scrim.withValues(alpha: theme.appBackgroundScrim),
              ),
            ),
        ],
      ),
    );
  }

  int _cacheWidth(BuildContext context) {
    final int width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    if (width < 64) {
      return 64;
    }
    if (width > 1440) {
      return 1440;
    }
    return width;
  }

  Alignment _alignment(String value) {
    switch (value) {
      case ShopAppBackground.alignTop:
        return Alignment.topCenter;
      case ShopAppBackground.alignBottom:
        return Alignment.bottomCenter;
      default:
        return Alignment.center;
    }
  }
}
