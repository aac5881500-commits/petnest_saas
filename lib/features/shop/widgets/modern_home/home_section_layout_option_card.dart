import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class HomeSectionLayoutChoice {
  const HomeSectionLayoutChoice({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.preview,
  });

  final String id;
  final String title;
  final String description;
  final String badge;
  final Widget preview;
}

/// 版型選擇卡。寬度由外層計算，不跟文字縮成中間小框。
class HomeSectionLayoutPicker extends StatelessWidget {
  const HomeSectionLayoutPicker({
    super.key,
    required this.theme,
    required this.choices,
    required this.selectedId,
    required this.onSelected,
  });

  final HomeThemeModel theme;
  final List<HomeSectionLayoutChoice> choices;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 10;
        final int columns = constraints.maxWidth >= 560 ? 2 : 1;
        final double width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final HomeSectionLayoutChoice choice in choices)
              SizedBox(
                width: width,
                height: 168,
                child: HomeSectionLayoutOptionCard(
                  key: Key('info-layout-${choice.id}'),
                  theme: theme,
                  title: choice.title,
                  description: choice.description,
                  badge: choice.badge,
                  selected: selectedId == choice.id,
                  preview: choice.preview,
                  onTap: () => onSelected(choice.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class HomeSectionLayoutOptionCard extends StatelessWidget {
  const HomeSectionLayoutOptionCard({
    super.key,
    required this.theme,
    required this.title,
    required this.description,
    required this.badge,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final HomeThemeModel theme;
  final String title;
  final String description;
  final String badge;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? theme.primaryColor.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? theme.primaryColor : const Color(0xFFE6E8EC),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: 56, child: preview),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: theme.secondaryTextColor,
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeDraftSwitch extends StatelessWidget {
  const HomeDraftSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class HomeDraftCountChips extends StatelessWidget {
  const HomeDraftCountChips({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<int> values;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final int value in values)
              ChoiceChip(
                label: Text('$value'),
                selected: selected == value,
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}
