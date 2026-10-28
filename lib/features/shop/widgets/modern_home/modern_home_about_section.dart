import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
import 'home_card_image.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_bridge.dart';
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
    this.displayStyle,
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
  final HomeDisplayStyle? displayStyle;

  String get _surfaceStyle {
    final HomeDisplayStyle? style = displayStyle;
    if (style == null) {
      return setting.surfaceStyle;
    }
    return aboutSurfaceForDisplay(style.cardBackground);
  }

  @override
  Widget build(BuildContext context) {
    if (!setting.showsOnHome || (!preview && !ShopIntroContent.about(shop))) {
      return const SizedBox.shrink();
    }
    final simple = setting.layout == HomeAboutLayouts.simpleEntry;
    return HomeCardImage(
      setting: setting.cardImage.copyWith(
        source: simple
            ? setting.cardImage.source
            : setting.imageSource == 'platformCard'
            ? 'platformCard'
            : 'icon',
      ),
      enabled: simple || setting.showImage,
      builder: (context, image) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview && !ShopIntroContent.about(shop))
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '僅供外觀預覽：尚未設定關於我們內容，正式前台暫不顯示。',
                style: TextStyle(fontSize: 12),
              ),
            ),
          _body(image.url),
        ],
      ),
    );
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
    if (setting.summarySource == 'shop') {
      return (shop['aboutDescription'] ?? '').toString().trim();
    }
    final String custom = setting.subtitle.trim();
    if (setting.summarySource == 'custom') return custom;
    if (custom.isNotEmpty) {
      return custom;
    }
    final String about = (shop['aboutDescription'] ?? '').toString().trim();
    if (about.isEmpty) {
      return '認識我們的照顧理念';
    }
    return about.length <= 48 ? about : about.substring(0, 48);
  }

  String _photoUrl(String libraryUrl) {
    if (!setting.showImage) {
      return '';
    }
    if (setting.imageSource == 'platformCard') return libraryUrl;
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

  Widget _body(String imageUrl) {
    switch (HomeAboutLayouts.migrate(setting.layout)) {
      case HomeAboutLayouts.imageEntry:
        return _imageCard(imageUrl);
      case HomeAboutLayouts.brandIntro:
        return _brandCard(imageUrl);
      default:
        return _simple(imageUrl);
    }
  }

  TextStyle _titleLook(double fallback) {
    return TextStyle(
      fontSize: homeDisplayFontSize(
        displayStyle?.titleSize ?? HomeDisplaySizes.medium,
        fallback: fallback,
      ),
      height: 1.2,
      fontWeight: homeDisplayFontWeight(
        displayStyle?.titleWeight ?? HomeDisplayWeights.bold,
      ),
      color: displayStyle == null
          ? theme.textColor
          : Color(displayStyle!.titleColor),
    );
  }

  TextStyle _bodyLook(double fallback) {
    return TextStyle(
      fontSize: homeDisplayFontSize(
        displayStyle?.bodySize ?? HomeDisplaySizes.small,
        fallback: fallback,
      ),
      height: 1.35,
      fontWeight: homeDisplayFontWeight(
        displayStyle?.bodyWeight ?? HomeDisplayWeights.medium,
      ),
      color: displayStyle == null
          ? theme.secondaryTextColor
          : Color(displayStyle!.effectiveBodyColor),
    );
  }

  TextAlign get _textAlign {
    if (displayStyle != null) {
      return homeDisplayTextAlign(displayStyle!.titleAlign);
    }
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

  Widget _simple(String imageUrl) {
    final String size = HomeAboutCardSizes.entryCardSize(setting.cardSize);
    final bool small = size == 'small';
    final bool wide = size == 'wide';
    return ModernHomeEntryCard(
      displayStyle: displayStyle,
      cardKey: const Key('home-about-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: _summary,
      showSubtitle: setting.showSubtitle && _summary.isNotEmpty,
      cardSize: size,
      surface: HomeAboutSurfaces.entrySurface(_surfaceStyle),
      icon: Icons.favorite_border_rounded,
      backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      mark: imageUrl.isEmpty ? _logoMark : null,
      showArrow: small ? false : setting.showArrow,
      textAlign: _textAlign,
      actionLabel: !small && !wide && setting.showButton
          ? setting.entryButton
          : '',
      onTap: _open,
    );
  }

  Widget _imageCard(String imageUrl) {
    final String url = _photoUrl(imageUrl);
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

  Widget _brandCard(String imageUrl) {
    final String url = _photoUrl(imageUrl);
    final String name = _brandTitle;
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (url.isNotEmpty) _photoBox(url: url, height: 148, expand: true),
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
                  style: _titleLook(18),
                ),
                if (setting.showSubtitle) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    _summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: displayStyle == null
                        ? _textAlign
                        : homeDisplayTextAlign(displayStyle!.bodyAlign),
                    style: _bodyLook(13),
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
            style: _titleLook(16),
          ),
          if (setting.showSubtitle) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _summary,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: displayStyle == null
                  ? _textAlign
                  : homeDisplayTextAlign(displayStyle!.bodyAlign),
              style: _bodyLook(13),
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
    final Color fill = switch (HomeAboutSurfaces.migrate(_surfaceStyle)) {
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
            border: _surfaceStyle == HomeAboutSurfaces.transparent
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
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.favorite_border_rounded, color: theme.primaryColor),
      ),
    );
  }
}
