import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class PolicySectionLayoutPreview extends StatelessWidget {
  const PolicySectionLayoutPreview({
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
        child: switch (HomePolicyLayouts.migrate(layout)) {
          HomePolicyLayouts.singleLine => _line(),
          HomePolicyLayouts.summary => _summary(),
          HomePolicyLayouts.serviceSplit => _split(),
          _ => _compact(),
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
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _bar(width: 16, height: 16),
            const SizedBox(height: 4),
            _bar(),
          ],
        ),
      ),
    );
  }

  Widget _line() {
    return Row(
      children: <Widget>[
        _bar(width: 18, height: 18),
        const SizedBox(width: 8),
        Expanded(child: _bar(width: 72)),
        Icon(Icons.chevron_right, size: 16, color: theme.primaryColor),
      ],
    );
  }

  Widget _summary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _bar(width: 64),
        const SizedBox(height: 6),
        _bar(width: 96, height: 6),
        const SizedBox(height: 4),
        _bar(width: 72, height: 6),
      ],
    );
  }

  Widget _split() {
    return Row(
      children: <Widget>[
        Expanded(child: _bar(width: 48, height: 28)),
        const SizedBox(width: 6),
        Expanded(child: _bar(width: 48, height: 28)),
      ],
    );
  }
}
