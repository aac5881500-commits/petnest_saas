import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

enum RefinedEntrySizeMode {
  /// 獨立簡約入口：一張卡使用自己的寬度，不按 2／3／4 欄切格。
  independent,

  /// 共用區已經算好格子寬度，卡片填滿父層給的寬度。
  slot,
}

/// 精緻圖片入口。只負責外觀，點擊由呼叫端決定。
///
/// [featureId] 標記這張卡屬於哪個首頁功能，之後不同功能可以排在同一列。
/// 這個元件不讀房型、訂單或圖庫。
class RefinedImageEntryCard extends StatelessWidget {
  const RefinedImageEntryCard({
    super.key,
    required this.cardKey,
    required this.featureId,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.showSubtitle,
    required this.textMode,
    required this.textAlign,
    required this.textSize,
    required this.textWeight,
    required this.textColor,
    required this.aspect,
    required this.radius,
    required this.mask,
    required this.imageUrl,
    required this.onTap,
    this.surface = HomeRoomSimpleSurfaces.filled,
    this.sizeMode = RefinedEntrySizeMode.independent,
    this.placeholderIcon = Icons.image_outlined,
    this.textColorValue,
    this.textPosition,
    this.bodySize,
    this.bodyWeight,
    this.bodyColorValue,
    this.spacing = HomeDisplaySpacings.normal,
    this.cardPadding = HomeDisplaySpacings.normal,
    this.showBorder = true,
    this.cardShadow = HomeDisplayShadows.none,
    this.contentAlign,
    this.imageFit = HomeDisplayFits.cover,
    this.showTitle = true,
    this.overlayAlignment,
    this.showTextScrim = true,
    this.bodyUsesTitleColor = true,
    this.paintMaskOffImage = false,
    this.detachImage = false,
    this.compactEmptyIcon = false,
    this.imageTextGap,
    this.contentScale = 1,
    this.maxContentWidth,
    this.iconExtent,
  });

  final Key cardKey;
  final String featureId;
  final HomeThemeModel theme;
  final String title;
  final String subtitle;
  final bool showSubtitle;
  final String textMode;
  final String textAlign;
  final String textSize;
  final String textWeight;
  final String textColor;
  final int? textColorValue;
  final String aspect;
  final String radius;
  final String mask;
  final String imageUrl;
  final VoidCallback onTap;
  final String surface;
  final RefinedEntrySizeMode sizeMode;
  final IconData placeholderIcon;
  final String? textPosition;
  final String? bodySize;
  final String? bodyWeight;
  final int? bodyColorValue;
  final String spacing;
  final String cardPadding;
  final bool showBorder;
  final String cardShadow;
  final String? contentAlign;
  final String imageFit;
  final bool showTitle;
  final Alignment? overlayAlignment;
  final bool showTextScrim;
  final bool bodyUsesTitleColor;

  /// 精緻小卡的遮罩要蓋在圖片上。其他入口維持文字在圖片上才顯示遮罩。
  final bool paintMaskOffImage;

  /// 文字在圖片外時，圖片四角獨立圓角，文字不再包進同一張底框。
  final bool detachImage;

  /// 沒有圖庫圖片時改用小圖示，不留一大塊空白圖片。
  final bool compactEmptyIcon;

  /// 圖片與外側文字的間距。空值沿用原本內距。
  final double? imageTextGap;

  /// 圖片在欄位內的寬度比例。點擊區域仍是整個欄位。
  final double contentScale;

  /// 一排一張時限制圖片最大寬度。
  final double? maxContentWidth;

  /// 固定圖示邊長。空值時跟著卡片寬度。
  final double? iconExtent;

  bool get _above => textPosition == HomeDisplayTextPositions.above;

  bool get _onImage => textPosition == null
      ? textMode != HomeRoomSimpleTextModes.below
      : textPosition == HomeDisplayTextPositions.overlay;

  bool get _showsSubtitle {
    if (!showSubtitle || subtitle.trim().isEmpty) {
      return false;
    }
    if (textPosition != null) {
      return true;
    }
    return textMode != HomeRoomSimpleTextModes.overlay;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : RefinedImageEntryMetrics.maxRowWidth;
        final double width = switch (sizeMode) {
          RefinedEntrySizeMode.slot => available,
          RefinedEntrySizeMode.independent => math.min(available, 300),
        };
        final double frame = _frameWidth(width);
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: width, child: _card(width, frame)),
        );
      },
    );
  }

  bool get _detached => detachImage && !_onImage;

  bool get _compactEmpty =>
      compactEmptyIcon && imageUrl.trim().isEmpty && _detached;

  double _frameWidth(double slot) {
    final double scaled = slot * contentScale.clamp(0.7, 1);
    final double? cap = maxContentWidth;
    if (cap == null) {
      return scaled;
    }
    return math.min(scaled, cap);
  }

  double _outsideGap() {
    return imageTextGap ?? 8;
  }

  bool get _overlayCentered {
    final Alignment align = overlayAlignment ?? _alignment;
    return align.y.abs() < 0.25;
  }

  Widget _card(double slot, double frame) {
    final double scale = RefinedImageEntryMetrics.scaleFor(frame);
    final BorderRadius radius = _radiusFor(scale);
    final bool empty = imageUrl.trim().isEmpty;
    final bool showMask = !empty;
    final bool emptyOnImage = empty && compactEmptyIcon && _onImage;
    final Widget image = ClipRRect(
      key: const Key('refined-entry-image'),
      borderRadius: _detached || _onImage ? radius : BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (imageUrl.trim().isEmpty)
            _imageFallback(scale)
          else
            Image.network(
              imageUrl,
              fit: imageFit == HomeDisplayFits.contain
                  ? BoxFit.contain
                  : BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _imageFallback(scale),
            ),
          if (showMask &&
              (_onImage || paintMaskOffImage) &&
              mask == HomeRoomSimpleMasks.light)
            const ColoredBox(
              key: Key('refined-entry-mask'),
              color: Color(0x1F000000),
            ),
          if (showMask &&
              (_onImage || paintMaskOffImage) &&
              mask == HomeRoomSimpleMasks.strong)
            const ColoredBox(
              key: Key('refined-entry-mask'),
              color: Color(0x47000000),
            ),
          if (_onImage && showTextScrim && !empty)
            DecoratedBox(
              key: const Key('refined-entry-scrim'),
              decoration: _scrim(),
            ),
          if (_onImage && !emptyOnImage)
            Align(
              alignment: overlayAlignment ?? _alignment,
              child: _copy(onImage: true, scale: scale),
            ),
        ],
      ),
    );
    final Widget photo = _photoChrome(
      _compactEmpty
          ? Align(
              alignment: Alignment.center,
              child: _iconBadge(scale, key: const Key('refined-entry-image')),
            )
          : AspectRatio(
              aspectRatio: _aspectRatio,
              child: emptyOnImage ? _emptyOnImage(scale, radius) : image,
            ),
      radius,
    );
    final double gap = _outsideGap();
    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_above) _copy(onImage: false, scale: scale, detached: _detached),
        if (_above && _detached) SizedBox(height: gap),
        photo,
        if (!_onImage && !_above && _detached) SizedBox(height: gap),
        if (!_onImage && !_above)
          _copy(onImage: false, scale: scale, detached: _detached),
      ],
    );
    final BorderRadius chromeRadius = _detached ? BorderRadius.zero : radius;
    final Widget visual = SizedBox(
      width: frame,
      child: Material(
        color: _detached ? Colors.transparent : _surfaceColor,
        elevation: _detached ? 0 : _elevation,
        shadowColor: const Color(0x14000000),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: chromeRadius,
            border: !_detached && showBorder
                ? Border.all(color: theme.cardBorderColor)
                : null,
          ),
          child: _detached
              ? column
              : ClipRRect(borderRadius: radius, child: column),
        ),
      ),
    );
    return SizedBox(
      key: ValueKey<String>('refined-entry-$featureId'),
      width: slot,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: cardKey,
          onTap: onTap,
          child: Align(alignment: Alignment.topCenter, child: visual),
        ),
      ),
    );
  }

  /// 文字在圖片外時，框線和陰影只留在圖片上。
  Widget _photoChrome(Widget child, BorderRadius radius) {
    if (!_detached) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      elevation: _elevation,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: showBorder
            ? BorderSide(color: theme.cardBorderColor)
            : BorderSide.none,
      ),
      child: child,
    );
  }

  double get _elevation {
    return switch (cardShadow) {
      HomeDisplayShadows.strong => 3,
      HomeDisplayShadows.soft => 1,
      _ => 0,
    };
  }

  /// 沒有圖庫圖片、文字又在圖上時，只放一個圖示，並和文字分開。
  /// 圖示先讓出一行標題的高度，不夠時再縮小，避免 Column 溢位。
  Widget _emptyOnImage(double scale, BorderRadius radius) {
    return ClipRRect(
      key: const Key('refined-entry-image'),
      borderRadius: radius,
      child: ColoredBox(
        color: theme.primaryColor.withValues(alpha: 0.12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double height = constraints.maxHeight;
            final double width = constraints.maxWidth;
            const double edge = 6;
            final double innerH = math.max(0, height - edge * 2);
            final double innerW = math.max(0, width - edge * 2);
            final bool hasText = _hasOnImageText;
            final double oneLine = hasText ? _titleSize(scale) * 1.2 + 4 : 0;
            const double gap = 4;
            double icon = math.min(
              _preferredIcon(scale),
              math.min(innerW, math.max(0, innerH - oneLine - gap)),
            );
            if (icon < 16) {
              icon = 0;
            }
            if (_overlayCentered) {
              return Padding(
                padding: const EdgeInsets.all(edge),
                child: _centeredEmpty(
                  scale: scale,
                  innerW: innerW,
                  innerH: innerH,
                  hasText: hasText,
                  gap: gap,
                ),
              );
            }
            final double textRoom = math.max(
              0,
              innerH - (icon > 0 ? icon + gap : 0),
            );
            final _TightTextPlan? plan = hasText && textRoom > 0
                ? _tightPlan(scale, textRoom)
                : null;
            final double textH = plan == null
                ? 0
                : math.min(plan.height, textRoom);
            final Widget? badge = icon <= 0
                ? null
                : _iconBadge(scale, extent: icon);
            final Widget text = plan == null
                ? const SizedBox.shrink()
                : SizedBox(
                    width: innerW,
                    height: textH,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _tightCopy(plan),
                    ),
                  );
            return Padding(
              padding: const EdgeInsets.all(edge),
              child: Column(children: <Widget>[?badge, const Spacer(), text]),
            );
          },
        ),
      ),
    );
  }

  /// 文字組放在圖片區正中。圖示只占用文字上方剩下的空間，不把文字往下推。
  Widget _centeredEmpty({
    required double scale,
    required double innerW,
    required double innerH,
    required bool hasText,
    required double gap,
  }) {
    const double minIcon = 16;
    final double iconBudget = minIcon + gap;
    final bool roomForIcon = hasText && innerH >= iconBudget * 2 + 12;
    final double textLimit = roomForIcon ? innerH - iconBudget * 2 : innerH;
    final _TightTextPlan? plan = hasText ? _tightPlan(scale, textLimit) : null;
    final double textH = plan == null ? 0 : math.min(plan.height, textLimit);
    final double above = math.max(0, (innerH - textH) / 2);
    double iconSize = 0;
    if (!hasText) {
      iconSize = math.min(_preferredIcon(scale), math.min(innerW, innerH));
    } else if (above >= iconBudget) {
      iconSize = math.min(_preferredIcon(scale), math.min(innerW, above - gap));
      if (iconSize < minIcon) {
        iconSize = 0;
      }
    }
    final double iconTop = hasText
        ? math.max(0, above - iconSize - gap)
        : math.max(0, (innerH - iconSize) / 2);
    return Stack(
      children: <Widget>[
        if (plan != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: innerW,
                height: textH,
                child: Align(
                  alignment: Alignment.center,
                  child: _tightCopy(plan),
                ),
              ),
            ),
          ),
        if (iconSize > 0)
          Positioned(
            top: iconTop,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: _iconBadge(scale, extent: iconSize),
            ),
          ),
      ],
    );
  }

  bool get _hasOnImageText =>
      (showTitle && title.trim().isNotEmpty) || _showsSubtitle;

  double _preferredIcon(double scale) {
    final double? requested = iconExtent;
    if (requested == null) {
      return (46 * scale).clamp(40.0, 64.0);
    }
    return requested.clamp(28.0, 72.0);
  }

  Widget _iconBadge(double scale, {Key? key, double? extent}) {
    final double? requested = extent ?? iconExtent;
    final double size = extent != null
        ? extent.clamp(0.0, 72.0)
        : requested == null
        ? (46 * scale).clamp(40.0, 64.0)
        : requested.clamp(28.0, 72.0);
    final double glyph = extent == null
        ? (size * 0.46).clamp(14.0, 34.0)
        : (size * 0.46).clamp(0.0, math.min(34.0, size * 0.7));
    return Container(
      key: key,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular((size * 0.28).clamp(8.0, 20.0)),
      ),
      child: Icon(placeholderIcon, color: theme.primaryColor, size: glyph),
    );
  }

  Widget _copy({
    required bool onImage,
    required double scale,
    bool detached = false,
  }) {
    if (!onImage) {
      return _looseCopy(scale: scale, detached: detached);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxHeight = constraints.maxHeight;
        if (!maxHeight.isFinite || _looseBlockHeight(scale) <= maxHeight) {
          return _looseCopy(scale: scale, detached: false);
        }
        return _tightCopy(_tightPlan(scale, maxHeight));
      },
    );
  }

  /// 圖片上的文字自然高度。多留幾像素，避免估太小又改回會溢位的排法。
  double _looseBlockHeight(double scale) {
    final double titleFont = _titleSize(scale);
    final double pad = (HomeDisplaySpacings.gap(cardPadding) * scale).clamp(
      4.0,
      16.0,
    );
    final int lines = scale < 0.85 ? 1 : 2;
    final bool hasTitle = showTitle && title.trim().isNotEmpty;
    final double bodyGap = (HomeDisplaySpacings.gap(spacing) * 0.35 * scale)
        .clamp(1.0, 8.0);
    double height = pad * 2;
    if (hasTitle) {
      height += lines * titleFont * 1.2;
    }
    if (_showsSubtitle) {
      height += bodyGap + _bodyFont(scale, titleFont) * 1.2;
    }
    return height + 8;
  }

  double _bodyFont(double scale, double titleSize) {
    if (bodySize == null) {
      return math.max(9, titleSize - 2 * scale);
    }
    return homeDisplayFontSize(
      bodySize!,
      fallback: math.max(11, titleSize - 2),
    );
  }

  _TightTextPlan _tightPlan(double scale, double maxHeight) {
    final bool hasTitle = showTitle && title.trim().isNotEmpty;
    double titleFont = _titleSize(scale);
    double bodyFont = _bodyFont(scale, titleFont);
    double pad = (HomeDisplaySpacings.gap(cardPadding) * scale).clamp(
      4.0,
      16.0,
    );
    int lines = scale < 0.85 ? 1 : 2;
    bool body = _showsSubtitle;
    double bodyGap = (HomeDisplaySpacings.gap(spacing) * 0.35 * scale).clamp(
      1.0,
      8.0,
    );
    const double line = 1.15;

    double used() {
      double height = pad * 2;
      if (hasTitle) {
        height += lines * titleFont * line;
      }
      if (body) {
        height += bodyGap + bodyFont * line;
      }
      return height;
    }

    if (used() > maxHeight) {
      pad = math.min(pad, 2);
    }
    if (used() > maxHeight && lines > 1) {
      lines = 1;
    }
    if (used() > maxHeight && body && hasTitle) {
      body = false;
    }
    if (used() > maxHeight) {
      pad = 0;
      bodyGap = 0;
    }
    if (used() > maxHeight && used() > 0) {
      final double factor = maxHeight / used();
      titleFont *= factor;
      bodyFont *= factor;
    }
    if (used() > maxHeight && hasTitle) {
      body = false;
      pad = 0;
      bodyGap = 0;
      lines = 1;
      titleFont = math.max(1, maxHeight / line);
    } else if (used() > maxHeight && body) {
      pad = 0;
      bodyGap = 0;
      bodyFont = math.max(1, maxHeight / line);
    }
    return _TightTextPlan(
      pad: pad,
      titleLines: hasTitle ? lines : 0,
      showBody: body,
      titleFont: titleFont,
      bodyFont: bodyFont,
      bodyGap: body ? bodyGap : 0,
      height: math.min(used(), math.max(0, maxHeight)),
    );
  }

  Widget _tightCopy(_TightTextPlan plan) {
    final Color color = _ink(true);
    const double line = 1.1;
    return Padding(
      padding: EdgeInsets.all(plan.pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: _crossAxis,
        children: <Widget>[
          if (plan.titleLines > 0)
            Text(
              title,
              maxLines: plan.titleLines,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: plan.titleFont,
                height: line,
                fontWeight: _weight,
                color: color,
              ),
              strutStyle: StrutStyle(
                fontSize: plan.titleFont,
                height: line,
                forceStrutHeight: true,
              ),
            ),
          if (plan.showBody) ...<Widget>[
            SizedBox(height: plan.bodyGap),
            Text(
              subtitle.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: plan.bodyFont,
                height: line,
                fontWeight: bodyWeight == null
                    ? FontWeight.w500
                    : homeDisplayFontWeight(bodyWeight!),
                color: _bodyInk(true, color),
              ),
              strutStyle: StrutStyle(
                fontSize: plan.bodyFont,
                height: line,
                forceStrutHeight: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _looseCopy({required double scale, required bool detached}) {
    final Color color = _ink(!detached && _onImage);
    final double titleSize = _titleSize(scale);
    final double pad = detached
        ? 0
        : (HomeDisplaySpacings.gap(cardPadding) * scale).clamp(4.0, 16.0);
    final bool onImage = !detached && _onImage;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pad,
        detached ? 0 : (onImage ? pad : pad * 0.8),
        pad,
        detached ? 0 : pad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: _crossAxis,
        children: <Widget>[
          if (showTitle && title.trim().isNotEmpty)
            Text(
              title,
              maxLines: scale < 0.85 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: titleSize,
                height: 1.2,
                fontWeight: _weight,
                color: color,
              ),
            ),
          if (_showsSubtitle) ...<Widget>[
            SizedBox(
              height: detached
                  ? 3
                  : (HomeDisplaySpacings.gap(spacing) * 0.35 * scale).clamp(
                      1.0,
                      8.0,
                    ),
            ),
            Text(
              subtitle.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: bodySize == null
                    ? math.max(9, titleSize - 2 * scale)
                    : homeDisplayFontSize(
                        bodySize!,
                        fallback: math.max(11, titleSize - 2),
                      ),
                height: 1.2,
                fontWeight: bodyWeight == null
                    ? FontWeight.w500
                    : homeDisplayFontWeight(bodyWeight!),
                color: _bodyInk(onImage, color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageFallback(double scale) {
    return ColoredBox(
      color: theme.primaryColor.withValues(alpha: 0.12),
      child: Icon(
        placeholderIcon,
        color: theme.primaryColor,
        size: (22 * scale).clamp(14.0, 28.0),
      ),
    );
  }

  Color get _surfaceColor {
    switch (surface) {
      case HomeRoomSimpleSurfaces.transparent:
        return Colors.transparent;
      case HomeRoomSimpleSurfaces.outlined:
        return theme.backgroundColor;
      default:
        return theme.cardColor;
    }
  }

  Color _ink(bool onImage) {
    switch (textColor) {
      case HomeRoomSimpleTextColors.light:
        return Colors.white;
      case HomeRoomSimpleTextColors.custom:
        final int? value = textColorValue;
        if (value == null) {
          return onImage ? Colors.white : theme.textColor;
        }
        return Color(value);
      default:
        return onImage ? const Color(0xFF3A2A20) : theme.textColor;
    }
  }

  Color _bodyInk(bool onImage, Color titleColor) {
    final int? value = bodyColorValue;
    if (value != null) {
      return Color(value);
    }
    final Color ink = bodyUsesTitleColor
        ? titleColor
        : (onImage ? const Color(0xFF3A2A20) : theme.textColor);
    return ink.withValues(alpha: onImage ? 0.92 : 0.72);
  }

  double _titleSize(double scale) {
    final double base = switch (textSize) {
      HomeRoomSimpleTextSizes.small => 12,
      HomeRoomSimpleTextSizes.large => 16,
      _ => 14,
    };
    return (base * scale).clamp(9.0, 20.0);
  }

  FontWeight get _weight {
    switch (textWeight) {
      case HomeRoomSimpleTextWeights.regular:
        return FontWeight.w400;
      case HomeRoomSimpleTextWeights.medium:
        return FontWeight.w600;
      default:
        return FontWeight.w800;
    }
  }

  double get _aspectRatio {
    switch (aspect) {
      case HomeRoomSimpleAspects.portrait:
        return 3 / 4;
      case HomeRoomSimpleAspects.landscape:
        return 4 / 3;
      default:
        return 1;
    }
  }

  BorderRadius _radiusFor(double scale) {
    final double value = switch (radius) {
      HomeRoomSimpleRadii.small => 10,
      HomeRoomSimpleRadii.large => 22,
      _ => 16,
    };
    return BorderRadius.circular((value * scale).clamp(6.0, 24.0));
  }

  Alignment get _alignment {
    switch (textAlign) {
      case HomeRoomSimpleTextAligns.center:
        return Alignment.center;
      case HomeRoomSimpleTextAligns.bottomEnd:
        return Alignment.bottomRight;
      default:
        return Alignment.bottomLeft;
    }
  }

  CrossAxisAlignment get _crossAxis {
    if (contentAlign != null) {
      return homeDisplayCrossAlign(contentAlign!);
    }
    if (!_onImage) {
      return CrossAxisAlignment.center;
    }
    switch (textAlign) {
      case HomeRoomSimpleTextAligns.center:
        return CrossAxisAlignment.center;
      case HomeRoomSimpleTextAligns.bottomEnd:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  TextAlign get _textAlign {
    if (contentAlign != null) {
      return homeDisplayTextAlign(contentAlign!);
    }
    if (!_onImage) {
      return TextAlign.center;
    }
    switch (textAlign) {
      case HomeRoomSimpleTextAligns.center:
        return TextAlign.center;
      case HomeRoomSimpleTextAligns.bottomEnd:
        return TextAlign.end;
      default:
        return TextAlign.start;
    }
  }

  BoxDecoration _scrim() {
    if (textAlign == HomeRoomSimpleTextAligns.center) {
      return const BoxDecoration(
        gradient: RadialGradient(
          colors: <Color>[Color(0x73000000), Color(0x00000000)],
          radius: 0.72,
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0x00000000),
          Color(0x00000000),
          Color(0x8C000000),
        ],
        stops: <double>[0, 0.52, 1],
      ),
    );
  }
}

class _TightTextPlan {
  const _TightTextPlan({
    required this.pad,
    required this.titleLines,
    required this.showBody,
    required this.titleFont,
    required this.bodyFont,
    required this.bodyGap,
    required this.height,
  });

  final double pad;
  final int titleLines;
  final bool showBody;
  final double titleFont;
  final double bodyFont;
  final double bodyGap;
  final double height;
}

/// 一排 2／3／4 張共用的尺寸。一張卡也只佔其中一格，不會拉滿整排。
class RefinedImageEntryMetrics {
  const RefinedImageEntryMetrics._();

  static const double maxRowWidth = 348;
  static const double gap = 8;

  /// 一排 3 張、列寬 [maxRowWidth] 時的卡片寬度。字級與圓角以它為 1 倍。
  static const double referenceSlot = (maxRowWidth - gap * 2) / 3;

  static double slotWidth({required double available, required int columns}) {
    final int count = HomeRoomSimpleColumns.migrate(columns);
    final double row = available <= 0
        ? maxRowWidth
        : math.min(available, maxRowWidth);
    return math.max(0, (row - gap * (count - 1)) / count);
  }

  static double scaleFor(double slotWidth) {
    if (referenceSlot <= 0) {
      return 1;
    }
    return slotWidth / referenceSlot;
  }
}
