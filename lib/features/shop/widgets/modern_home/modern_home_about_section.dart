import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁關於我們。正式前台與外觀預覽共用。
class ModernHomeAboutSection extends StatelessWidget {
  const ModernHomeAboutSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.shop,
    required this.environmentIntro,
    required this.shopName,
    required this.logoUrl,
    required this.preview,
    required this.onOpen,
    this.imageProvider,
  });

  final HomeThemeModel theme;
  final HomeAboutSectionSetting setting;
  final Map<String, dynamic> shop;
  final Map<String, dynamic> environmentIntro;
  final String shopName;
  final String logoUrl;
  final bool preview;
  final VoidCallback onOpen;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    if (!setting.showsOnHome) {
      return const SizedBox.shrink();
    }
    return _body();
  }

  void _open() {
    if (preview) {
      return;
    }
    onOpen();
  }

  String get _summary {
    if (!setting.showSubtitle) {
      return '';
    }
    final String custom = setting.subtitle.trim();
    if (custom.isNotEmpty) {
      return custom;
    }
    final String about = (shop['aboutDescription'] ?? '').toString().trim();
    if (about.isEmpty) {
      return '認識我們的照顧理念';
    }
    return about.length <= 48 ? about : about.substring(0, 48);
  }

  String get _photoUrl {
    if (!setting.showImage) {
      return '';
    }
    if (imageProvider != null) {
      return 'preview';
    }
    return HomeAboutSectionSetting.resolveImageUrl(
      setting: setting,
      shop: shop,
      environmentIntro: environmentIntro,
    );
  }

  ImageProvider<Object>? get _logoMark {
    if (!setting.showLogo || logoUrl.trim().isEmpty) {
      return null;
    }
    return NetworkImage(logoUrl.trim());
  }

  Widget _body() {
    switch (HomeAboutLayouts.migrate(setting.layout)) {
      case HomeAboutLayouts.imageEntry:
        return _imageCard();
      case HomeAboutLayouts.brandIntro:
        return _brandCard();
      default:
        return _simple();
    }
  }

  TextAlign get _textAlign {
    return setting.textAlign == HomeAboutTextAligns.center
        ? TextAlign.center
        : TextAlign.start;
  }

  CrossAxisAlignment get _crossAlign {
    return _textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
  }

  String get _brandTitle {
    if (setting.useShopNameAsTitle) {
      final String name = shopName.trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return setting.entryTitle;
  }

  Widget _simple() {
    final String size = HomeAboutCardSizes.entryCardSize(setting.cardSize);
    final bool small = size == 'small';
    final bool wide = size == 'wide';
    return ModernHomeEntryCard(
      cardKey: const Key('home-about-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: _summary,
      showSubtitle: setting.showSubtitle && _summary.isNotEmpty,
      cardSize: size,
      surface: HomeAboutSurfaces.entrySurface(setting.surfaceStyle),
      icon: Icons.favorite_border_rounded,
      mark: _logoMark,
      showArrow: small ? false : setting.showArrow,
      textAlign: _textAlign,
      actionLabel: !small && !wide && setting.showButton
          ? setting.entryButton
          : '',
      onTap: _open,
    );
  }

  Widget _imageCard() {
    final String url = _photoUrl;
    final bool side =
        HomeAboutImagePositions.migrate(setting.imagePosition) !=
        HomeAboutImagePositions.top;
    final bool imageRight =
        setting.imagePosition == HomeAboutImagePositions.right;
    final Widget photo = _photoBox(
      url: url,
      height: side ? 112 : 148,
      expand: !side,
    );
    final Widget copy = _copy(maxLines: 3);
    return _shell(
      child: side
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: imageRight
                  ? <Widget>[Expanded(child: copy), photo]
                  : <Widget>[photo, Expanded(child: copy)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[photo, copy],
            ),
    );
  }

  Widget _brandCard() {
    final String url = _photoUrl;
    final String name = _brandTitle;
    final double scrim = switch (HomeAboutSurfaces.migrate(
      setting.surfaceStyle,
    )) {
      HomeAboutSurfaces.transparent => 0,
      HomeAboutSurfaces.translucent => 0.45,
      _ => 0.88,
    };
    return _shell(
      child: Stack(
        children: <Widget>[
          if (url.isNotEmpty)
            Positioned.fill(child: _photo(url, _fit, _alignment)),
          if (url.isNotEmpty && scrim > 0)
            Positioned.fill(
              child: ColoredBox(
                color: theme.cardColor.withValues(alpha: scrim),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: _crossAlign,
              children: <Widget>[
                if (setting.showLogo)
                  _logoMark == null
                      ? Icon(
                          Icons.favorite_border_rounded,
                          color: theme.primaryColor,
                        )
                      : _mark(36),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: _textAlign,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                if (setting.showSubtitle) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    _summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: _textAlign,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ],
                if (setting.showButton) ...<Widget>[
                  const SizedBox(height: 12),
                  _button(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _copy({required int maxLines}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: _crossAlign,
        children: <Widget>[
          Text(
            setting.entryTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: _textAlign,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          if (setting.showSubtitle) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _summary,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: theme.secondaryTextColor,
              ),
            ),
          ],
          if (setting.showButton || setting.showArrow) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: _textAlign == TextAlign.center
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: <Widget>[
                  if (setting.showButton)
                    Flexible(
                      child: Text(
                        setting.entryButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: _textAlign,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  if (setting.showArrow)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _button() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        setting.entryButton,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: _textAlign,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _shell({required Widget child}) {
    final Color fill = switch (HomeAboutSurfaces.migrate(
      setting.surfaceStyle,
    )) {
      HomeAboutSurfaces.transparent => Colors.transparent,
      HomeAboutSurfaces.translucent => theme.cardColor.withValues(alpha: 0.55),
      _ => theme.cardColor,
    };
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home-about-card'),
        borderRadius: BorderRadius.circular(14),
        onTap: _open,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: setting.surfaceStyle == HomeAboutSurfaces.transparent
                ? null
                : Border.all(color: theme.cardBorderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _photoBox({
    required String url,
    required double height,
    required bool expand,
  }) {
    final Widget box = SizedBox(
      key: const Key('home-about-photo'),
      width: expand ? double.infinity : 108,
      height: height,
      child: url.isEmpty ? _iconFallback() : _photo(url, _fit, _alignment),
    );
    return box;
  }

  BoxFit get _fit {
    return setting.imageFit == HomeAboutImageFits.contain
        ? BoxFit.contain
        : BoxFit.cover;
  }

  Alignment get _alignment {
    switch (HomeAboutImageAligns.migrate(setting.imageAlign)) {
      case HomeAboutImageAligns.top:
        return Alignment.topCenter;
      case HomeAboutImageAligns.bottom:
        return Alignment.bottomCenter;
      default:
        return Alignment.center;
    }
  }

  Widget _photo(String url, BoxFit fit, Alignment alignment) {
    final ImageProvider<Object>? provider = imageProvider;
    final Widget image = provider != null
        ? Image(
            image: provider,
            fit: fit,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _iconFallback(),
          )
        : Image.network(
            url,
            fit: fit,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _iconFallback(),
          );
    return ColoredBox(
      color: theme.primaryColor.withValues(alpha: 0.08),
      child: image,
    );
  }

  Widget _iconFallback() {
    return ColoredBox(
      key: const Key('home-about-icon'),
      color: theme.primaryColor.withValues(alpha: 0.12),
      child: Icon(Icons.favorite_border_rounded, color: theme.primaryColor),
    );
  }

  Widget _mark(double size) {
    final ImageProvider<Object>? mark = _logoMark;
    if (mark == null) {
      return _iconFallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: mark,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.favorite_border_rounded, color: theme.primaryColor),
      ),
    );
  }
}
