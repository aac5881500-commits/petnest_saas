import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class ReviewSectionLayoutPreview extends StatelessWidget {
  const ReviewSectionLayoutPreview({
    super.key,
    required this.layout,
    required this.theme,
  });

  final String layout;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: switch (HomeReviewLayouts.migrate(layout)) {
          HomeReviewLayouts.scoreCompact => _compact(),
          HomeReviewLayouts.featured => _featured(),
          HomeReviewLayouts.scoreOverview => _overview(),
          HomeReviewLayouts.scoreAndLatest => _split(),
          _ => _carousel(),
        },
      ),
    );
  }

  Widget _bar({double width = 48, double height = 8}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
      ),
      child: SizedBox(width: width, height: height),
    );
  }

  Widget _compact() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.star_rounded, size: 16, color: theme.primaryColor),
          const SizedBox(height: 4),
          _bar(width: 36),
        ],
      ),
    );
  }

  Widget _carousel() {
    return Row(
      children: <Widget>[
        _bar(width: 46, height: 28),
        const SizedBox(width: 6),
        _bar(width: 46, height: 28),
        const SizedBox(width: 6),
        _bar(width: 24, height: 28),
      ],
    );
  }

  Widget _featured() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _bar(width: 52),
        const SizedBox(height: 6),
        _bar(width: 96, height: 6),
        const SizedBox(height: 4),
        _bar(width: 72, height: 6),
      ],
    );
  }

  Widget _overview() {
    return Row(
      children: <Widget>[
        _bar(width: 28, height: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _bar(width: 72, height: 5),
              const SizedBox(height: 4),
              _bar(width: 64, height: 5),
              const SizedBox(height: 4),
              _bar(width: 56, height: 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _split() {
    return Row(
      children: <Widget>[
        _bar(width: 28, height: 28),
        const SizedBox(width: 8),
        Expanded(child: _bar(width: 72, height: 28)),
      ],
    );
  }
}
