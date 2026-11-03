import 'home_desktop_layout.dart';
import 'editorial_section_widgets.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_modern_logo.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

/// 只負責顯示店家識別。首頁與側邊欄各自建立，不共用 GlobalKey，也不讀取垂直座標。
class StoreBrandBlock extends StatelessWidget {
  const StoreBrandBlock({
    super.key,
    required this.contextKind,
    required this.style,
    required this.shopName,
    required this.subtitle,
    required this.logoUrl,
    required this.theme,
  });

  final StoreBrandDisplayContext contextKind;
  final StoreBrandStyle style;
  final String shopName;
  final String subtitle;
  final String logoUrl;
  final HomeThemeModel theme;

  Widget _subtitle(Color color, {double? fontSize}) => Transform.rotate(
    key: const ValueKey('brand-subtitle-rotation'),
    angle: style.subtitleRadians,
    child: Text(
      subtitle.trim(),
      textAlign: style.flutterTextAlign,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: style.subtitleFontFamily.isEmpty
            ? null
            : style.subtitleFontFamily,
        fontSize: fontSize ?? style.subtitleFontSize,
        height: 1.2,
        color: style.subtitleColor(color),
        shadows: style.textShadows,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final desktop = HomeDesktopLayoutScope.maybeOf(context);
    if (desktop != null &&
        style.markType == 'wordmark' &&
        contextKind == StoreBrandDisplayContext.home) {
      return Row(
        children: [
          SizedBox(
            width: 220,
            height: 60,
            child: logoUrl.trim().isEmpty
                ? Text(
                    shopName,
                    style: TextStyle(
                      fontSize: style.nameFontSize,
                      color: theme.textColor,
                    ),
                  )
                : sectionPhoto(logoUrl, fit: BoxFit.contain),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(width: 32),
            Flexible(child: _subtitle(theme.textColor, fontSize: 16)),
          ],
        ],
      );
    }
    if (style.markType == 'wordmark' &&
        contextKind == StoreBrandDisplayContext.home) {
      return LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            Expanded(
              flex: 6,
              child: SizedBox(
                height: style.logoSize == 'large'
                    ? 56
                    : style.logoSize == 'small'
                    ? 36
                    : 46,
                child: logoUrl.trim().isEmpty
                    ? Text(
                        shopName,
                        style: TextStyle(
                          fontSize: style.nameFontSize,
                          fontFamily: style.appliedNameFontFamily,
                          fontWeight: FontWeight.w800,
                          color: style.nameColor(theme.textColor),
                        ),
                      )
                    : sectionPhoto(logoUrl, fit: BoxFit.contain),
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(width: 14),
              Expanded(flex: 5, child: _subtitle(theme.textColor)),
            ],
          ],
        ),
      );
    }
    final String name = shopName.trim().isEmpty ? '店家' : shopName.trim();
    final String caption = subtitle.trim();
    final Color nameColor = style.nameColor(theme.textColor);
    final List<Shadow>? shadows = style.textShadows;
    final bool home = contextKind == StoreBrandDisplayContext.home;
    final Widget? mark = _mark();
    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: style.columnAlign,
      children: <Widget>[
        Text(
          name,
          textAlign: style.flutterTextAlign,
          maxLines: home ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          softWrap: !home,
          style: TextStyle(
            fontFamily: style.appliedNameFontFamily,
            fontSize: style.nameFontSize,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: nameColor,
            shadows: shadows,
          ),
        ),
        if (caption.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          _subtitle(theme.textColor),
        ],
      ],
    );
    final Widget row = Row(
      mainAxisSize: home ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (mark != null && style.logoPlacement != 'trailing') ...<Widget>[
          mark,
          const SizedBox(width: StoreBrandStyle.logoGap),
        ],
        Flexible(fit: home ? FlexFit.loose : FlexFit.tight, child: text),
        if (mark != null && style.logoPlacement == 'trailing') ...<Widget>[
          const SizedBox(width: StoreBrandStyle.logoGap),
          mark,
        ],
      ],
    );
    return Semantics(
      container: true,
      label: home ? '首頁店家識別' : '側邊欄店家',
      child: home ? row : SizedBox(width: double.infinity, child: row),
    );
  }

  Widget? _mark() {
    if (!style.showsMark) {
      return null;
    }
    final double size = style.logoExtent;
    if (style.markType == 'builtinIcon') {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          StoreBrandStyle.iconData(style.fallbackIcon),
          size: size * 0.72,
          color: theme.primaryColor,
        ),
      );
    }
    final String url = logoUrl.trim();
    if (url.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 88),
        child: Text(
          '請先上傳店家 Logo',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: theme.textColor,
          ),
        ),
      );
    }
    return ShopModernLogo(
      imageUrl: url,
      size: size,
      primaryColor: theme.primaryColor,
      borderRadius: size * 0.22,
    );
  }
}
