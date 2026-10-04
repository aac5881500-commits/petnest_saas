import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// 環境版型選項上的迷你示意，不使用圖片。
class EnvironmentSectionLayoutPreview extends StatelessWidget {
  const EnvironmentSectionLayoutPreview({
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
          child: switch (layout) {
            HomeEnvironmentLayouts.simpleEntry => _simple(),
            HomeEnvironmentLayouts.imageEntry => _image(),
            _ => _scroll(),
          },
        ),
      ),
    );
  }

  Widget _chip() {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.cardBorderColor),
        ),
      ),
    );
  }

  Widget _scroll() {
    return Row(
      children: <Widget>[
        _chip(),
        const SizedBox(width: 6),
        _chip(),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.42,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.cardBorderColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _simple() {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.home_outlined, size: 16, color: theme.primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _bar(width: 72, height: 8),
              const SizedBox(height: 6),
              _bar(width: 108, height: 6),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.primaryColor, size: 18),
      ],
    );
  }

  Widget _image() {
    return Column(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _bar(width: 64, height: 6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
