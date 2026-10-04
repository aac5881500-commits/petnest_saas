import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

const double kModernHomeSmallCardHeight = 104;
const double kModernHomeWideCardHeight = 68;
const double kModernHomeSingleCardMinHeight = 112;

/// 房型、環境、關於我們共用的入口卡。外框尺寸由 [cardSize] 決定，不跟文案長短改變。
class ModernHomeEntryCard extends StatelessWidget {
  const ModernHomeEntryCard({
    super.key,
    required this.cardKey,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.showSubtitle,
    required this.cardSize,
    required this.surface,
    required this.icon,
    required this.onTap,
    this.actionLabel = '',
    this.showArrow = true,
    this.mark,
    this.textAlign = TextAlign.start,
  });

  final Key cardKey;
  final HomeThemeModel theme;
  final String title;
  final String subtitle;
  final bool showSubtitle;
  final String cardSize;
  final String surface;
  final IconData icon;
  final VoidCallback onTap;
  final String actionLabel;
  final bool showArrow;
  final ImageProvider<Object>? mark;
  final TextAlign textAlign;

  String get _size {
    switch (cardSize.trim()) {
      case 'small':
      case 'single':
      case 'wide':
        return cardSize.trim();
      default:
        return 'wide';
    }
  }

  CrossAxisAlignment get _crossAlign {
    return textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
  }

  MainAxisAlignment get _mainAlign {
    return textAlign == TextAlign.center
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = _shell(
      child: _size == 'small'
          ? _small()
          : _size == 'single'
          ? _single()
          : _wide(),
    );
    if (_size == 'small') {
      return SizedBox(
        key: cardKey,
        height: kModernHomeSmallCardHeight,
        width: double.infinity,
        child: card,
      );
    }
    if (_size == 'wide') {
      return SizedBox(
        key: cardKey,
        height: kModernHomeWideCardHeight,
        width: double.infinity,
        child: card,
      );
    }
    return ConstrainedBox(
      key: cardKey,
      constraints: const BoxConstraints(
        minHeight: kModernHomeSingleCardMinHeight,
      ),
      child: card,
    );
  }

  Widget _shell({required Widget child}) {
    final Color fill = switch (surface) {
      'transparent' => Colors.transparent,
      'outlined' => theme.backgroundColor,
      'translucent' => theme.cardColor.withValues(alpha: 0.55),
      _ => theme.cardColor,
    };
    final Border? border = surface == 'transparent'
        ? null
        : Border.all(color: theme.cardBorderColor);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _iconBox({double box = 40, double iconSize = 22}) {
    final ImageProvider<Object>? image = mark;
    return Container(
      width: box,
      height: box,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: image == null
          ? Icon(icon, color: theme.primaryColor, size: iconSize)
          : Image(
              image: image,
              width: box,
              height: box,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(icon, color: theme.primaryColor, size: iconSize),
            ),
    );
  }

  Widget _titleText({
    int maxLines = 2,
    double fontSize = 15,
    double height = 1.2,
  }) {
    return Text(
      title.trim().isEmpty ? '未命名' : title.trim(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        height: height,
        fontWeight: FontWeight.w800,
        color: theme.textColor,
      ),
    );
  }

  Widget _subtitleText({
    required int maxLines,
    double fontSize = 12,
    double height = 1.2,
  }) {
    if (!showSubtitle || subtitle.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      subtitle,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        height: height,
        color: theme.secondaryTextColor,
      ),
    );
  }

  Widget _small() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Column(
        crossAxisAlignment: _crossAlign,
        children: <Widget>[
          _iconBox(box: 32, iconSize: 18),
          const SizedBox(height: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: _crossAlign,
              children: <Widget>[
                _titleText(maxLines: 2, fontSize: 12, height: 1),
                if (showSubtitle && subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  _subtitleText(maxLines: 2, fontSize: 11, height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _single() {
    final String action = actionLabel.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: _crossAlign,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _iconBox(),
              const SizedBox(width: 12),
              Expanded(child: _titleText()),
            ],
          ),
          if (showSubtitle && subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _subtitleText(maxLines: 2),
          ],
          if (action.isNotEmpty || showArrow) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: _mainAlign,
                children: <Widget>[
                  if (action.isNotEmpty)
                    Flexible(
                      child: Text(
                        action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  if (showArrow)
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

  Widget _wide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          _iconBox(box: 32, iconSize: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: _crossAlign,
              children: <Widget>[
                _titleText(maxLines: 1, fontSize: 14, height: 1.15),
                if (showSubtitle && subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  _subtitleText(maxLines: 1, fontSize: 12, height: 1.15),
                ],
              ],
            ),
          ),
          if (showArrow)
            Icon(Icons.chevron_right_rounded, color: theme.primaryColor),
        ],
      ),
    );
  }
}
