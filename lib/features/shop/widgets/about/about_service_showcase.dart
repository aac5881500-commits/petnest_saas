import 'service_builtin_artwork.dart';
import 'about_media.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:petnest_saas/core/models/shop_service_showcase.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import '../environment/environment_section_title.dart';

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
      const Text('選擇關於我們頁要展示的服務。只有已在「模組設定」開啟的模板才能加入。'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in ShopServiceShowcase.layouts.entries)
            ChoiceChip(
              key: ValueKey('module-showcase-layout-${entry.key}'),
              avatar: Icon(switch (entry.key) {
                'photoGrid' => Icons.photo_library_outlined,
                'editorial' => Icons.view_list_outlined,
                'overlay' => Icons.photo_outlined,
                'compact' => Icons.label_outline,
                'cards' => Icons.view_agenda_outlined,
                'icons' => Icons.grid_view_outlined,
                _ => Icons.visibility_off_outlined,
              }, size: 18),
              label: Text(entry.value),
              selected: value.layout == entry.key,
              onSelected: busy
                  ? null
                  : (_) => onChanged(value.copyWith(layout: entry.key)),
            ),
        ],
      ),
      if (value.layout != 'hidden') ...[
        const SizedBox(height: 12),
        const Text('內建卡片風格（不需上傳圖片）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in ShopServiceShowcase.artworkStyles.entries)
              SizedBox(
                width: 136,
                child: Material(
                  color: value.artworkStyle == preset.key
                      ? const Color(0xFFEFF1FF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('service-artwork-${preset.key}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: busy
                        ? null
                        : () => onChanged(
                            value.copyWith(artworkStyle: preset.key),
                          ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: value.artworkStyle == preset.key
                              ? const Color(0xFF5965A3)
                              : const Color(0xFFE1E3EA),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 72,
                            child: ServiceBuiltinArtwork(
                              serviceId: 'cat_hotel',
                              variant: preset.key,
                              accent: Theme.of(context).colorScheme.primary,
                              fallbackIcon: serviceShowcaseIcon('cat_hotel'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (preset.key == 'postcard')
                            const Text(
                              '推薦：溫暖旅宿風',
                              style: TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '內建風格不會覆蓋已選的圖庫圖片；可在各服務下方切回內建。',
          style: TextStyle(fontSize: 12),
        ),
        const Text('卡片造型'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final shape in ShopServiceShowcase.shapes.entries)
              ChoiceChip(
                label: Text(shape.value),
                selected: value.shape == shape.key,
                onSelected: busy
                    ? null
                    : (_) => onChanged(value.copyWith(shape: shape.key)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('圖片顯示方式（各服務可在下方分別換圖）'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final fit in const {
              'cover': '填滿裁切',
              'contain': '完整顯示',
            }.entries)
              ChoiceChip(
                label: Text(fit.value),
                selected: value.imageFit == fit.key,
                onSelected: busy
                    ? null
                    : (_) => onChanged(value.copyWith(imageFit: fit.key)),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final align in const {
              'top': '焦點靠上',
              'center': '焦點置中',
              'bottom': '焦點靠下',
            }.entries)
              ChoiceChip(
                label: Text(align.value),
                selected: value.imagePosition == align.key,
                onSelected: busy
                    ? null
                    : (_) =>
                          onChanged(value.copyWith(imagePosition: align.key)),
              ),
          ],
        ),
        const Text(
          '未選照片時沿用原有服務圖示；更換與移除圖片只調整引用，不刪除原圖。',
          style: TextStyle(fontSize: 12),
        ),
      ],
      const SizedBox(height: 16),
      for (final entry in ShopServiceShowcase.labels.entries) ...[
        CheckboxListTile(
          key: ValueKey('module-showcase-select-${entry.key}'),
          contentPadding: EdgeInsets.zero,
          secondary: Icon(serviceShowcaseIcon(entry.key)),
          title: Text(entry.value),
          subtitle: Text(
            enabledModules.contains(entry.key)
                ? ShopServiceShowcase.descriptions[entry.key]!
                : '尚未開啟此模組，請先至「模組設定」開啟',
          ),
          value:
              enabledModules.contains(entry.key) &&
              value.selected.contains(entry.key),
          onChanged: busy || !enabledModules.contains(entry.key)
              ? null
              : (checked) {
                  final ids = [...value.selected];
                  if (checked == true) {
                    if (!ids.contains(entry.key)) ids.add(entry.key);
                  } else {
                    ids.remove(entry.key);
                  }
                  onChanged(value.copyWith(selected: ids));
                },
        ),
        if (value.layout != 'hidden' &&
            value.selected.contains(entry.key) &&
            enabledModules.contains(entry.key))
          ExpansionTile(
            key: PageStorageKey('service-image-${entry.key}'),
            title: Text('${entry.value}：圖片設定'),
            subtitle: Text(
              AboutMedia.fromMap(value.imageFor(entry.key)).source == 'none'
                  ? '使用整組內建風格'
                  : '已選擇圖片，可更換或移除',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: IgnorePointer(
                  ignoring: busy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('跟隨整組風格'),
                            selected:
                                value.imageFor(entry.key)['source'] == null ||
                                value.imageFor(entry.key)['source'] == 'none',
                            onSelected: busy
                                ? null
                                : (_) => onChanged(
                                    value.withImage(entry.key, const {
                                      'source': 'none',
                                    }),
                                  ),
                          ),
                          for (final preset
                              in ShopServiceShowcase.artworkStyles.entries)
                            ChoiceChip(
                              label: Text(preset.value),
                              selected:
                                  value.imageFor(entry.key)['source'] ==
                                      'builtin' &&
                                  value.imageFor(entry.key)['variant'] ==
                                      preset.key,
                              onSelected: busy
                                  ? null
                                  : (_) => onChanged(
                                      value.withImage(entry.key, {
                                        'source': 'builtin',
                                        'variant': preset.key,
                                      }),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (const [
                        'shop',
                        'legacy',
                        'firstGallery',
                      ].contains(value.imageFor(entry.key)['source']))
                        const Text(
                          '原有照片引用已保留；可改選內建插畫或平台圖庫，不會刪除原照片。',
                          style: TextStyle(fontSize: 12),
                        ),
                      AboutMediaField(
                        value: AboutMedia.fromMap(value.imageFor(entry.key)),
                        shop: shop,
                        allowShop: false,
                        allowFirst: false,
                        onChanged: (image) {
                          if (!busy) {
                            onChanged(
                              value.withImage(entry.key, image.toMap()),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
      if (value.layout != 'hidden' &&
          value.visibleModules(enabledModules).isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('請至少勾選一項已開啟的服務，前台才會出現這個區塊。'),
        ),
      const SizedBox(height: 8),
      const Text('此區僅展示服務介紹，預約仍統一從「我要預約」進入。關閉模組後會自動隱藏該項目；原有展示選擇會保留。'),
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
              final icons =
                  value.layout == 'icons' || value.layout == 'compact';
              final columns = icons
                  ? (box.maxWidth >= 720
                        ? 5
                        : box.maxWidth >= 300
                        ? 3
                        : 2)
                  : (value.layout == 'photoGrid'
                        ? (box.maxWidth >= 620
                              ? 3
                              : box.maxWidth >= 300
                              ? 2
                              : 1)
                        : (box.maxWidth >= 620 ? 2 : 1));
              final width =
                  (box.maxWidth - style.itemGap * (columns - 1)) / columns;
              return Wrap(
                spacing: style.itemGap,
                runSpacing: style.itemGap,
                children: [
                  for (final id in ids)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        container: true,
                        label: ShopServiceShowcase.labels[id],
                        excludeSemantics: true,
                        child: _tile(id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _builtin(String id) {
    final image = value.imageFor(id);
    final raw = image['source'] == 'builtin'
        ? image['variant']
        : value.artworkStyle;
    final variant = ShopServiceShowcase.artworkStyles.containsKey(raw)
        ? raw as String
        : value.artworkStyle;
    return ServiceBuiltinArtwork(
      serviceId: id,
      variant: variant,
      accent: theme.primaryColor,
      fallbackIcon: serviceShowcaseIcon(id),
    );
  }

  Widget _visual(String id) => value.imageFor(id)['source'] == 'builtin'
      ? _builtin(id)
      : AboutMediaView(
          key: ValueKey('service-photo-$id'),
          media: AboutMedia.fromMap(value.imageFor(id)),
          shop: shop,
          fit: value.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover,
          alignment: switch (value.imagePosition) {
            'top' => Alignment.topCenter,
            'bottom' => Alignment.bottomCenter,
            _ => Alignment.center,
          },
          empty: _builtin(id),
        );

  Widget _copy(String id, {bool onImage = false, bool compact = false}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ShopServiceShowcase.labels[id]!,
            style: TextStyle(
              color: onImage ? Colors.white : theme.textColor,
              fontWeight: FontWeight.w700,
              fontSize: style.bottomNoteSize + (compact ? 0 : 2),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              ShopServiceShowcase.descriptions[id]!,
              style: TextStyle(
                color: onImage ? Colors.white : theme.secondaryTextColor,
                fontSize: style.bottomNoteSize,
              ),
            ),
          ],
        ],
      );
  Widget _tile(String id) {
    final radius = value.shape == 'rounded' ? 28.0 : style.cardRadius;
    final shape = BorderRadius.circular(radius);
    Widget image(double width, double height) => ClipRRect(
      borderRadius: BorderRadius.circular(value.shape == 'rounded' ? 24 : 10),
      child: SizedBox(width: width, height: height, child: _visual(id)),
    );
    final content = switch (value.layout) {
      'photoGrid' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 4 / 3, child: _visual(id)),
          Padding(padding: const EdgeInsets.all(14), child: _copy(id)),
        ],
      ),
      'overlay' => SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _visual(id),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _copy(id, onImage: true),
            ),
          ],
        ),
      ),
      'editorial' => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            image(96, 112),
            const SizedBox(width: 14),
            Expanded(child: _copy(id)),
          ],
        ),
      ),
      'compact' => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            image(36, 36),
            const SizedBox(height: 6),
            _copy(id, compact: true),
          ],
        ),
      ),
      'icons' => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            image(44, 44),
            const SizedBox(height: 10),
            Text(
              ShopServiceShowcase.labels[id]!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: style.bottomNoteSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _ => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            image(52, 52),
            const SizedBox(width: 14),
            Expanded(child: _copy(id)),
          ],
        ),
      ),
    };
    return Container(
      key: ValueKey('about-service-module-$id'),
      decoration: BoxDecoration(
        color: value.shape == 'soft'
            ? Color.alphaBlend(
                theme.primaryColor.withValues(alpha: .09),
                theme.cardColor,
              )
            : theme.cardColor,
        borderRadius: shape,
        border: Border.all(
          color: value.shape == 'outline'
              ? theme.primaryColor.withValues(alpha: .6)
              : theme.primaryColor.withValues(alpha: .18),
        ),
      ),
      child: ClipRRect(borderRadius: shape, child: content),
    );
  }
}
