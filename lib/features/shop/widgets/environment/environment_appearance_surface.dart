// 檔案：lib/features/shop/widgets/environment/environment_appearance_surface.dart
// 功能：只在環境介紹內容套用外觀；背景固定於可視區，圖庫依 ID 一次解析。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import '../shop_app_backdrop.dart';

class EnvironmentAppearanceScope extends InheritedWidget {
  const EnvironmentAppearanceScope({
    super.key,
    required this.appearance,
    required this.baseTheme,
    required super.child,
  });
  final EnvironmentPageAppearance appearance;
  final HomeThemeModel baseTheme;
  static EnvironmentAppearanceScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EnvironmentAppearanceScope>();
  static HomeThemeModel cardTheme(
    BuildContext context,
    HomeThemeModel fallback,
  ) {
    final scope = of(context);
    return scope?.appearance.resolve(scope.baseTheme, card: true) ?? fallback;
  }

  static Color secondary(
    BuildContext context,
    HomeThemeModel theme,
    double opacity,
  ) => of(context)?.appearance.hasColors == true
      ? theme.secondaryTextColor
      : theme.textColor.withValues(alpha: opacity);
  @override
  bool updateShouldNotify(EnvironmentAppearanceScope oldWidget) =>
      oldWidget.appearance != appearance || oldWidget.baseTheme != baseTheme;
}

class EnvironmentAppearanceSurface extends StatefulWidget {
  const EnvironmentAppearanceSurface({
    super.key,
    required this.appearance,
    required this.baseTheme,
    required this.contentBuilder,
    required this.actionTextSize,
  });
  final EnvironmentPageAppearance appearance;
  final HomeThemeModel baseTheme;
  final double actionTextSize;
  final Widget Function(BuildContext, HomeThemeModel) contentBuilder;
  @override
  State<EnvironmentAppearanceSurface> createState() =>
      _EnvironmentAppearanceSurfaceState();
}

class _EnvironmentAppearanceSurfaceState
    extends State<EnvironmentAppearanceSurface> {
  PlatformMediaAsset? _asset;
  String _id = '';
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EnvironmentAppearanceSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final id = widget.appearance.backgroundMode == 'image'
        ? widget.appearance.backgroundAssetId
        : '';
    if (id == _id) return;
    _id = id;
    _asset = null;
    _failed = false;
    if (id.isEmpty) return;
    PlatformMediaLibraryService.instance.getEnabledAssetById(id).then((asset) {
      if (!mounted || id != _id) return;
      if (asset != null &&
          asset.enabled &&
          const [
            PlatformMediaCategories.appBackground,
            PlatformMediaCategories.dailyCarePage,
          ].contains(asset.category)) {
        setState(() => _asset = asset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appearance = widget.appearance;
    final resolved = appearance.resolve(widget.baseTheme);
    final oldTheme = Theme.of(context);
    final font = appearance.fontFamily;
    final scheme = oldTheme.colorScheme.copyWith(
      primary: resolved.primaryColor,
      onSurface: resolved.textColor,
    );
    final local = oldTheme.copyWith(
      colorScheme: scheme,
      textTheme: oldTheme.textTheme.apply(fontFamily: font),
      primaryTextTheme: oldTheme.primaryTextTheme.apply(fontFamily: font),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: resolved.primaryColor,
          textStyle: TextStyle(
            fontFamily: font,
            fontSize: widget.actionTextSize,
          ),
        ),
      ),
    );
    return Theme(
      data: local,
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: font, color: resolved.textColor),
        child: EnvironmentAppearanceScope(
          appearance: appearance,
          baseTheme: widget.baseTheme,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: appearance.backgroundMode == 'theme'
                      ? ShopAppBackdrop(theme: resolved)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: resolved.backgroundColor),
                            if (appearance.backgroundMode == 'image' &&
                                _asset != null &&
                                !_failed) ...[
                              Opacity(
                                opacity: appearance.imageOpacity,
                                child: Image.network(
                                  _asset!.imageUrl,
                                  key: ValueKey(_asset!.id),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, error, stack) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted && !_failed) {
                                            setState(() => _failed = true);
                                          }
                                        });
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              ColoredBox(
                                color:
                                    (appearance.darkMask
                                            ? Colors.black
                                            : Colors.white)
                                        .withValues(
                                          alpha: appearance.maskOpacity,
                                        ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              Positioned.fill(
                child: Builder(
                  builder: (context) =>
                      widget.contentBuilder(context, resolved),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
