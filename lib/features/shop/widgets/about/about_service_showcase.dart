// 檔案名稱：lib/features/shop/widgets/about/about_service_showcase.dart
// 功能說明：服務卡片整組切換視覺與共用排版；不提供單項換圖。
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:petnest_saas/core/models/shop_service_showcase.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import '../environment/environment_section_title.dart';
import 'service_builtin_artwork.dart';

IconData serviceShowcaseIcon(String id) => switch (id) {
  'cat_hotel' => FontAwesomeIcons.cat.data,
  'dog_hotel' => FontAwesomeIcons.dog.data,
  'grooming' => Icons.content_cut,
  'hospital' => Icons.local_hospital_outlined,
  'store' => Icons.shopping_bag_outlined,
  _ => Icons.grid_view_outlined,
};

class AboutServiceShowcaseEditor extends StatelessWidget {
  const AboutServiceShowcaseEditor({
    super.key,
    required this.value,
    required this.enabledModules,
    required this.onChanged,
    this.busy = false,
    this.shop = const {},
  });
  final ShopServiceShowcase value;
  final List<String> enabledModules;
  final ValueChanged<ShopServiceShowcase> onChanged;
  final bool busy;
  final Map<String, dynamic> shop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('顯示服務項目'),
        value: value.layout != 'hidden',
        onChanged: busy
            ? null
            : (show) =>
                  onChanged(value.copyWith(layout: show ? 'cards' : 'hidden')),
      ),
      const Text('圖片風格（整組一起切換）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in ShopServiceShowcase.artworkStyles.entries)
            ChoiceChip(
              key: ValueKey('service-visual-${choice.key}'),
              label: Text(choice.value),
              selected: value.artworkStyle == choice.key,
              onSelected: busy
                  ? null
                  : (_) => onChanged(value.copyWith(artworkStyle: choice.key)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('卡片排版'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in ShopServiceShowcase.cardLayouts.entries)
            ChoiceChip(
              key: ValueKey('service-layout-${choice.key}'),
              label: Text(choice.value),
              selected: value.cardLayout == choice.key,
              onSelected: busy
                  ? null
                  : (_) => onChanged(value.copyWith(cardLayout: choice.key)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('卡片大小（整組套用）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in ShopServiceShowcase.cardSizes.entries)
            ChoiceChip(
              key: ValueKey('service-size-${choice.key}'),
              label: Text(choice.value),
              selected: value.cardSize == choice.key,
              onSelected: busy
                  ? null
                  : (_) => onChanged(value.copyWith(cardSize: choice.key)),
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('四種風格共用相同排版，切換時只更換整組圖片。', style: TextStyle(fontSize: 12)),
      ),
      for (final entry in ShopServiceShowcase.labels.entries)
        CheckboxListTile(
          key: ValueKey('module-showcase-select-${entry.key}'),
          contentPadding: EdgeInsets.zero,
          secondary: Icon(serviceShowcaseIcon(entry.key)),
          title: Text(entry.value),
          subtitle: Text(
            enabledModules.contains(entry.key)
                ? ShopServiceShowcase.descriptions[entry.key]!
                : '尚未開啟此模組',
          ),
          value:
              enabledModules.contains(entry.key) &&
              value.selected.contains(entry.key),
          onChanged: busy || !enabledModules.contains(entry.key)
              ? null
              : (checked) {
                  final selected = [...value.selected];
                  if (checked == true) {
                    if (!selected.contains(entry.key)) selected.add(entry.key);
                  } else {
                    selected.remove(entry.key);
                  }
                  onChanged(value.copyWith(selected: selected));
                },
        ),
      if (value.layout != 'hidden' &&
          value.visibleModules(enabledModules).isEmpty)
        const Text('請至少勾選一項已開啟的服務。'),
      const SizedBox(height: 8),
      const Text(
        '這裡只介紹服務，不改變預約入口。內建圖片為示意素材，非店家實景。',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}

class AboutServiceShowcaseSection extends StatelessWidget {
  const AboutServiceShowcaseSection({
    super.key,
    required this.value,
    required this.enabledModules,
    required this.theme,
    required this.style,
    this.shop = const {},
  });
  final ShopServiceShowcase value;
  final List<String> enabledModules;
  final HomeThemeModel theme;
  final EnvironmentIntroStyle style;
  final Map<String, dynamic> shop;
  Widget _visual(String id) => ColoredBox(
    color: theme.primaryColor.withValues(alpha: .06),
    child: ServiceBuiltinArtwork(
      key: ValueKey('service-visual-image-$id'),
      serviceId: id,
      variant: value.artworkStyle,
      accent: theme.primaryColor,
      fallbackIcon: serviceShowcaseIcon(id),
    ),
  );
  Widget _copy(String id) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ShopServiceShowcase.labels[id]!,
          style: TextStyle(
            color: theme.textColor,
            fontSize: style.bottomNoteSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ShopServiceShowcase.descriptions[id]!,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: style.bottomNoteSize - 1,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
  double get _listImageSize => switch (value.cardSize) {
    'small' => 72,
    'large' => 136,
    _ => 104,
  };
  double get _horizontalWidth => switch (value.cardSize) {
    'small' => 160,
    'large' => 280,
    _ => 220,
  };
  Widget _card(String id, {bool list = false}) => Container(
    key: ValueKey('about-service-module-$id'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.cardBorderColor),
    ),
    child: list
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: ValueKey('service-image-slot-$id'),
                width: _listImageSize,
                height: _listImageSize,
                child: _visual(id),
              ),
              Expanded(child: _copy(id)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                key: ValueKey('service-image-slot-$id'),
                aspectRatio: 4 / 3,
                child: _visual(id),
              ),
              _copy(id),
            ],
          ),
  );
  @override
  Widget build(BuildContext context) {
    final ids = value.visibleModules(enabledModules);
    if (ids.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: style.sectionGap),
        EnvironmentSectionTitle(
          icon: Icons.grid_view_outlined,
          title: '服務項目',
          theme: theme,
          fontSize: style.sectionTitleSize,
          iconSize: style.sectionIconSize,
          horizontalPadding: style.pagePadding,
        ),
        SizedBox(height: style.itemGap),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: style.pagePadding),
          child: LayoutBuilder(
            builder: (context, box) {
              if (value.cardLayout == 'horizontal') {
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: SingleChildScrollView(
                    key: const PageStorageKey('service-horizontal-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final id in ids)
                          Padding(
                            padding: EdgeInsets.only(
                              right: id == ids.last ? 0 : style.itemGap,
                            ),
                            child: SizedBox(
                              width: box.maxWidth.clamp(0.0, _horizontalWidth),
                              child: _card(id),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }
              if (value.cardLayout == 'list') {
                return Column(
                  children: [
                    for (final id in ids)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: id == ids.last ? 0 : style.itemGap,
                        ),
                        child: _card(id, list: true),
                      ),
                  ],
                );
              }
              final mediumColumns = box.maxWidth >= 720
                  ? 3
                  : box.maxWidth >= 300
                  ? 2
                  : 1;
              final columns = switch (value.cardSize) {
                'small' =>
                  ((box.maxWidth + style.itemGap) / (130 + style.itemGap))
                      .floor()
                      .clamp(1, 6),
                'large' =>
                  ((box.maxWidth + style.itemGap) / (280 + style.itemGap))
                      .floor()
                      .clamp(1, 3),
                _ => mediumColumns,
              };
              final width =
                  (box.maxWidth - style.itemGap * (columns - 1)) / columns;
              return Wrap(
                spacing: style.itemGap,
                runSpacing: style.itemGap,
                children: [
                  for (final id in ids)
                    SizedBox(width: width, child: _card(id)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
