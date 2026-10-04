import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class NewsSectionLayoutPreview extends StatelessWidget {
  const NewsSectionLayoutPreview({
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
          child: switch (HomeNewsLayouts.migrate(layout)) {
            HomeNewsLayouts.compactCard => _compact(),
            HomeNewsLayouts.multiLine => _multi(),
            _ => _single(),
          },
        ),
      ),
    );
  }

  Widget _bar({double width = 36, double height = 8}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: SizedBox(width: width, height: height),
    );
  }

  Widget _compact() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _bar(width: 18, height: 18),
            const SizedBox(height: 6),
            _bar(width: 64),
            const SizedBox(height: 4),
            _bar(width: 48, height: 6),
          ],
        ),
      ),
    );
  }

  Widget _single() {
    return Row(
      children: <Widget>[
        _bar(width: 22, height: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _bar(width: 72),
              const SizedBox(height: 6),
              _bar(width: 120, height: 6),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.primaryColor, size: 18),
      ],
    );
  }

  Widget _multi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _bar(width: 64),
        const SizedBox(height: 8),
        _bar(width: double.infinity, height: 8),
        const SizedBox(height: 6),
        _bar(width: double.infinity, height: 8),
        const SizedBox(height: 6),
        _bar(width: 160, height: 8),
      ],
    );
  }
}
