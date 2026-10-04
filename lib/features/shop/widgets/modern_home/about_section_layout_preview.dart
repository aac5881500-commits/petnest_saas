import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class AboutSectionLayoutPreview extends StatelessWidget {
  const AboutSectionLayoutPreview({
    super.key,
    required this.layout,
    required this.theme,
  });

  final String layout;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: switch (HomeAboutLayouts.migrate(layout)) {
            HomeAboutLayouts.imageEntry => _image(),
            HomeAboutLayouts.brandIntro => _brand(),
            _ => _simple(),
          },
        ),
      ),
    );
  }

  Widget _chip({double width = 28}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(width: width, height: double.infinity),
    );
  }

  Widget _lines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          height: 8,
          width: 72,
          color: theme.textColor.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: 96,
          color: theme.secondaryTextColor.withValues(alpha: 0.7),
        ),
      ],
    );
  }

  Widget _simple() {
    return Row(
      children: <Widget>[
        _chip(width: 28),
        const SizedBox(width: 8),
        Expanded(child: _lines()),
        Icon(Icons.chevron_right_rounded, color: theme.primaryColor),
      ],
    );
  }

  Widget _image() {
    return Row(
      children: <Widget>[
        _chip(width: 46),
        const SizedBox(width: 8),
        Expanded(child: _lines()),
      ],
    );
  }

  Widget _brand() {
    return Row(
      children: <Widget>[
        _chip(width: 28),
        const SizedBox(width: 8),
        Expanded(child: _lines()),
        Container(
          width: 42,
          height: 16,
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}
