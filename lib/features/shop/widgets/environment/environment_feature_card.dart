// lib/features/shop/widgets/environment/environment_feature_card.dart
// 🐾 環境介紹特色卡：橫向圖卡 / 上圖下文 / 重點文字卡

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentFeatureCard extends StatelessWidget {
  const EnvironmentFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.imageBuilder,
    this.theme = HomeThemeModel.classicDefault,
    this.style = const EnvironmentIntroStyle(),
    this.reverse = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String imageUrl;
  final bool reverse;
  final HomeThemeModel theme;
  final EnvironmentIntroStyle style;
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })
  imageBuilder;

  bool get _hasImage => imageUrl.trim().isNotEmpty && !style.isTextCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        style.pagePadding,
        0,
        style.pagePadding,
        style.itemGap,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: style.featurePadding,
        vertical: style.featurePaddingVertical,
      ),
      constraints: BoxConstraints(minHeight: style.featureMinHeight),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(style.cardRadius),
        border: Border.all(color: theme.cardBorderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: style.isVerticalCard ? _vertical() : _horizontalOrText(),
    );
  }

  Widget _horizontalOrText() {
    final Widget text = _textContent();
    if (!_hasImage) {
      return text;
    }

    final int imageFlex = style.horizontalImageFlex.round();
    final int textFlex = 100 - imageFlex;
    final Widget image = _roundedImage();
    final List<Widget> children = reverse
        ? <Widget>[
            Expanded(flex: imageFlex, child: image),
            SizedBox(width: style.featureTextGap + 6),
            Expanded(flex: textFlex, child: text),
          ]
        : <Widget>[
            Expanded(flex: textFlex, child: text),
            SizedBox(width: style.featureTextGap + 6),
            Expanded(flex: imageFlex, child: image),
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _vertical() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_hasImage) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(style.featureImageRadius),
            child: AspectRatio(
              aspectRatio: style.verticalImageAspect,
              child: imageBuilder(imageUrl: imageUrl, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: style.featureTextGap + 4),
        ],
        _textContent(),
      ],
    );
  }

  Widget _roundedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(style.featureImageRadius),
      child: SizedBox(
        height: style.featureImageMaxHeight,
        width: double.infinity,
        child: imageBuilder(imageUrl: imageUrl, fit: BoxFit.cover),
      ),
    );
  }

  Widget _textContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                color: theme.primaryColor,
                size: style.isHorizontalCard
                    ? style.horizontalFeatureIconSize
                    : style.featureIconSize,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: style.cardTitleSize,
                    fontWeight: FontWeight.w900,
                    color: theme.textColor,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (description.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: style.featureTextGap),
            Text(
              description,
              style: TextStyle(
                fontSize: style.cardDescriptionSize,
                height: style.isHorizontalCard ? 1.35 : 1.5,
                color: theme.textColor.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
