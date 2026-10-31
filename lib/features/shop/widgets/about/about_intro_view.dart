import 'package:petnest_saas/core/models/shop_service_showcase.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'about_service_showcase.dart';
// 功能：正式關於我們與草稿共用內容 renderer，只使用傳入資料，不建立店家監聽。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/environment_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_card_image_setting.dart';
import '../shop_app_backdrop.dart';
import '../modern_home/home_card_image.dart';
import 'about_shop_info_section.dart';
import 'about_media.dart';
import 'about_cover_backdrop.dart';

class AboutIntroView extends StatelessWidget {
  const AboutIntroView({
    super.key,
    required this.shop,
    required this.setting,
    required this.theme,
    this.scrollController,
    this.preview = false,
    this.contactKey,
  });
  final Map<String, dynamic> shop;
  final AboutPageSetting setting;
  final HomeThemeModel theme;
  final ScrollController? scrollController;
  final bool preview;
  final GlobalKey? contactKey;
  static const icons = {
    'pets': Icons.pets,
    'heart': Icons.favorite_outline,
    'home': Icons.home_outlined,
    'care': Icons.health_and_safety_outlined,
    'clean': Icons.cleaning_services_outlined,
  };
  @override
  Widget build(BuildContext context) {
    final resolved = setting.resolve(theme);
    final a = setting.appearance;
    final mode = setting.choice('backgroundSource', [
      'theme',
      'color',
      'library',
    ], 'theme');
    final backdrop = mode == 'theme'
        ? theme
        : theme.copyWith(
            backgroundColorValue: setting
                .color('backgroundColor', theme.backgroundColor)
                .toARGB32(),
            appBackgroundMode: mode == 'library' ? 'image' : 'color',
            appBackgroundAssetId: '${a['backgroundAssetId'] ?? ''}',
            appBackgroundFit: setting.choice('backgroundFit', [
              'cover',
              'contain',
            ], 'cover'),
            appBackgroundAlign: setting.choice('backgroundAlign', [
              'top',
              'center',
              'bottom',
            ], 'center'),
            appBackgroundScrim: setting.number(
              'backgroundMask',
              .3,
              min: 0,
              max: 1,
            ),
          );
    final old = Theme.of(context), font = setting.font;
    final local = old.copyWith(
      textTheme: old.textTheme.apply(fontFamily: font),
      primaryTextTheme: old.primaryTextTheme.apply(fontFamily: font),
      colorScheme: old.colorScheme.copyWith(
        primary: resolved.primaryColor,
        onSurface: resolved.textColor,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _color(
            'buttonColor',
            resolved.primaryColor,
            _surface(resolved),
          ),
          textStyle: TextStyle(fontFamily: font),
        ),
      ),
    );
    final image = HomeCardImageSetting.fromMap(a['cardImage']);
    return Theme(
      data: local,
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: font),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.textScalerOf(context).scale(1) * setting.textScale,
            ),
          ),
          child: ShopAppBackdrop.behind(
            theme: backdrop,
            child: HomeCardImage(
              setting: image,
              enabled: a['cardsSource'] == 'custom',
              builder: (context, asset) => LayoutBuilder(
                builder: (context, c) {
                  final width = c.maxWidth.clamp(0.0, 1240.0);
                  final order = setting.sectionOrder;
                  final raw = setting.toMap();
                  final priority = setting.layout == 'boutique'
                      ? ['contact', 'highlights']
                      : setting.layout == 'highlights'
                      ? ['highlights', 'principles']
                      : setting.layout == 'team'
                      ? ['team', 'principles']
                      : setting.layout == 'principles' ||
                            setting.layout == 'brief'
                      ? ['principles']
                      : ['stories'];
                  final sequence = raw.containsKey('sectionOrder')
                      ? order
                      : {...priority, ...order}.toList();
                  final sections = <Widget>[];
                  for (final key in sequence) {
                    if (!setting.visible(key)) continue;
                    if (key == 'services') {
                      final showcase = setting.serviceShowcase;
                      final enabled = serviceShowcaseEnabledModules(shop);
                      if (showcase.visibleModules(enabled).isNotEmpty) {
                        sections.add(
                          AboutServiceShowcaseSection(
                            value: showcase,
                            shop: shop,
                            enabledModules: enabled,
                            theme: resolved,
                            style: const EnvironmentIntroStyle(),
                          ),
                        );
                      }
                    } else if (key == 'message') {
                      final text = '${shop['aboutMessage'] ?? ''}'.trim();
                      if (text.isNotEmpty) {
                        sections.add(
                          _block(
                            '給毛孩爸媽的話',
                            _card(
                              resolved,
                              _AboutLongText(
                                text: text,
                                expandable: setting.expandable,
                                color: _color(
                                  'bodyColor',
                                  resolved.textColor,
                                  _surface(
                                    resolved,
                                    image: asset.url.isNotEmpty,
                                  ),
                                ),
                              ),
                              asset.url,
                            ),
                            resolved,
                          ),
                        );
                      }
                    } else if (key == 'contact') {
                      sections.add(
                        KeyedSubtree(
                          key: contactKey,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _card(
                              resolved,
                              AboutShopInfoSection(
                                shopId: '',
                                theme: resolved.copyWith(
                                  cardColorValue: _surface(resolved).toARGB32(),
                                  textColorValue: _color(
                                    'bodyColor',
                                    resolved.textColor,
                                    _surface(resolved),
                                  ).toARGB32(),
                                  secondaryTextColorValue: _color(
                                    'secondaryTextColor',
                                    resolved.secondaryTextColor,
                                    _surface(resolved),
                                  ).toARGB32(),
                                  primaryColorValue: _color(
                                    'iconColor',
                                    resolved.primaryColor,
                                    _surface(resolved),
                                  ).toARGB32(),
                                ),
                                shopData: shop,
                                layout: setting.contactLayout,
                                previewOnly: preview,
                                actionColor: _color(
                                  'buttonColor',
                                  resolved.primaryColor,
                                  _surface(resolved),
                                ),
                                frameless: true,
                              ),
                              '',
                            ),
                          ),
                        ),
                      );
                    } else if (key == 'highlights') {
                      final items = setting
                          .items(key)
                          .where(
                            (item) =>
                                item.visible &&
                                (item.title.trim().isNotEmpty ||
                                    item.text.trim().isNotEmpty),
                          )
                          .toList();
                      if (items.isNotEmpty) {
                        sections.add(
                          _block(
                            '店家特色',
                            _highlights(items, resolved, width),
                            resolved,
                          ),
                        );
                      }
                    } else {
                      final items = setting
                          .items(key)
                          .where(
                            (item) =>
                                item.visible &&
                                (item.title.trim().isNotEmpty ||
                                    item.text.trim().isNotEmpty ||
                                    item.role.trim().isNotEmpty ||
                                    (_hasImage(item.image) &&
                                        !(const [
                                              'team',
                                              'credentials',
                                            ].contains(key) &&
                                            item.image.source == 'platform'))),
                          )
                          .toList();
                      final license = '${shop['licenseNumber'] ?? ''}'.trim();
                      if (key == 'credentials' && license.isNotEmpty) {
                        items.insert(
                          0,
                          AboutContentItem(
                            id: 'public-license',
                            title: '特定寵物業許可字號',
                            text: license,
                          ),
                        );
                      }
                      if (items.isEmpty) continue;
                      final grid =
                          (key == 'principles' &&
                              setting.layout == 'principles') ||
                          (key == 'team' && setting.layout == 'team');
                      final count =
                          grid &&
                              width >= 640 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.3
                          ? (width / 320).floor().clamp(2, 3)
                          : 1;
                      final gap = _gap;
                      final content = Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (var i = 0; i < items.length; i++)
                            SizedBox(
                              width: (width - 40 - (count - 1) * gap) / count,
                              child: KeyedSubtree(
                                key: ValueKey('about-$key-${items[i].id}'),
                                child: _item(
                                  items[i],
                                  key,
                                  i,
                                  width,
                                  resolved,
                                  key == 'principles' ? asset.url : '',
                                ),
                              ),
                            ),
                        ],
                      );
                      sections.add(
                        _block(
                          AboutPageSetting.sectionNames[key]!,
                          content,
                          resolved,
                        ),
                      );
                    }
                  }
                  final hasHeader =
                      '${shop['aboutTitle'] ?? ''}'.trim().isNotEmpty ||
                      '${shop['aboutDescription'] ?? ''}'.trim().isNotEmpty ||
                      _hasImage(setting.cover);
                  return SingleChildScrollView(
                    controller: scrollController,
                    key: const PageStorageKey<String>(
                      'about-intro-content-scroll',
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasHeader) _hero(resolved, width),
                            for (final section in sections)
                              Padding(
                                padding: EdgeInsets.only(top: _gap),
                                child: section,
                              ),
                            if (preview && !hasHeader && sections.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('尚未填寫內容，請在右側開始介紹你的店家。'),
                              ),
                            if (hasHeader || sections.isNotEmpty)
                              SizedBox(height: _gap),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasImage(AboutMedia media) => media.source == 'platform'
      ? media.assetId.isNotEmpty
      : media.resolveShop(shop).isNotEmpty;
  Color get _background =>
      setting.appearance['backgroundSource'] == 'theme' ||
          setting.appearance['backgroundSource'] == null
      ? theme.backgroundColor
      : setting.color('backgroundColor', theme.backgroundColor);
  HomeDisplayStyle? get _frontStyle {
    final home = shop['homeAppearance'];
    if (home is! Map || home['layout'] != 'modern') return null;
    final modern = home['modern'];
    final raw = modern is Map ? modern['displayStyle'] : null;
    final value = HomeDisplayStyleSetting.fromMap(raw);
    return value.saved ? value.style : null;
  }

  double get _gap => switch (setting.sectionSpacing) {
    'compact' => 12,
    'standard' => 24,
    'relaxed' => 36,
    _ => _legacyGap,
  };
  double get _legacyGap => setting.appearance['cardsSource'] == 'custom'
      ? setting.gap
      : _frontStyle == null
      ? 24
      : HomeDisplaySpacings.gap(_frontStyle!.cardGap) + 16;
  Color _cardFill(HomeThemeModel t) {
    if (setting.appearance['cardsSource'] == 'custom') {
      return setting
          .color('cardColor', t.cardColor)
          .withValues(alpha: setting.number('cardOpacity', 1, min: 0, max: 1));
    }
    return _frontStyle?.cardBackground == HomeDisplayBackgrounds.transparent
        ? Colors.transparent
        : _frontStyle?.cardBackground == HomeDisplayBackgrounds.outlined
        ? t.cardColor.withValues(alpha: .6)
        : t.cardColor;
  }

  Color _surface(HomeThemeModel t, {bool image = false}) =>
      image && setting.appearance['cardsSource'] == 'custom'
      ? setting.color('cardColor', t.cardColor)
      : Color.alphaBlend(_cardFill(t), _background);
  double get _aspect =>
      setting.choice('imageRatio', [
            'square',
            'landscape',
            'wide',
          ], 'landscape') ==
          'square'
      ? 1
      : setting.choice('imageRatio', [
              'square',
              'landscape',
              'wide',
            ], 'landscape') ==
            'wide'
      ? 16 / 9
      : 4 / 3;
  Color _color(String key, Color fallback, Color surface) =>
      EnvironmentPageAppearance.readable(
        setting.appearance['colorsSource'] == 'custom'
            ? setting.color(key, fallback)
            : key == 'titleColor' && _frontStyle != null
            ? Color(_frontStyle!.titleColor)
            : (key == 'bodyColor' || key == 'secondaryTextColor') &&
                  _frontStyle != null
            ? Color(_frontStyle!.effectiveBodyColor)
            : fallback,
        surface,
      );
  Widget _text(
    String text,
    HomeThemeModel t, {
    bool title = false,
    bool secondary = false,
    Color? surface,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: title ? 22 : 15,
      height: 1.65,
      fontWeight: title ? FontWeight.w800 : FontWeight.normal,
      color: _color(
        title
            ? 'titleColor'
            : secondary
            ? 'secondaryTextColor'
            : 'bodyColor',
        secondary ? t.secondaryTextColor : t.textColor,
        surface ?? _surface(t),
      ),
    ),
  );
  Widget _hero(HomeThemeModel t, double width) {
    final title = '${shop['aboutTitle'] ?? ''}',
        description = '${shop['aboutDescription'] ?? ''}';
    final frame = setting.coverFrame(shop);
    final hasImage = _hasImage(setting.cover);
    Widget image() => ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio:
            setting.choice('imageRatio', [
                  'square',
                  'landscape',
                  'wide',
                ], 'landscape') ==
                'square'
            ? 1
            : setting.choice('imageRatio', [
                    'square',
                    'landscape',
                    'wide',
                  ], 'landscape') ==
                  'wide'
            ? 16 / 9
            : 4 / 3,
        child: AboutMediaView(
          media: setting.cover,
          shop: shop,
          fit: frame.boxFit,
          alignment: frame.alignment,
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.trim().isNotEmpty)
          _text(title, t, title: true, surface: _background),
        if (description.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _text(description, t, secondary: true, surface: _background),
          ),
      ],
    );
    if (setting.coverLayout != 'auto') {
      final hasCopy = title.trim().isNotEmpty || description.trim().isNotEmpty;
      final sideBySide =
          width >= 700 &&
          hasImage &&
          hasCopy &&
          setting.coverLayout != 'stacked';
      return Padding(
        key: const ValueKey('about-independent-cover'),
        padding: const EdgeInsets.all(20),
        child: sideBySide
            ? Row(
                key: const ValueKey('about-cover-row'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: setting.coverLayout == 'imageRight' ? copy : image(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: setting.coverLayout == 'imageRight' ? image() : copy,
                  ),
                ],
              )
            : Column(
                key: const ValueKey('about-cover-column'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasImage) image(),
                  if (hasImage && hasCopy) const SizedBox(height: 16),
                  if (hasCopy) copy,
                ],
              ),
      );
    }
    if (setting.layout == 'boutique') {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _card(
          t,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.storefront_outlined, color: t.primaryColor, size: 34),
              const SizedBox(height: 14),
              if (title.trim().isNotEmpty)
                Center(child: _text(title, t, title: true)),
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _text(description, t),
                ),
              if (hasImage) ...[const SizedBox(height: 18), image()],
            ],
          ),
          '',
        ),
      );
    }
    if (setting.layout == 'editorial') {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 3, color: t.primaryColor),
            const SizedBox(height: 20),
            copy,
            const SizedBox(height: 20),
            if (hasImage) image(),
            Divider(height: 32, color: t.cardBorderColor),
          ],
        ),
      );
    }
    if (setting.layout == 'classic' &&
        (hasImage || setting.cover.source == 'legacy')) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: frame.heightForWidth(width)),
        child: Stack(
          children: [
            Positioned.fill(
              child: hasImage
                  ? AboutMediaView(
                      media: setting.cover,
                      shop: shop,
                      fit: frame.boxFit,
                      alignment: frame.alignment,
                    )
                  : AboutCoverBackdrop(shopImageUrl: '', frame: frame),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: .6)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.trim().isNotEmpty)
                    _text(title, t, title: true, surface: Colors.black),
                  if (description.trim().isNotEmpty)
                    _text(
                      description,
                      t,
                      secondary: true,
                      surface: Colors.black,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child:
          ['brief', 'highlights'].contains(setting.layout) &&
              width >= 700 &&
              hasImage
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: image()),
                const SizedBox(width: 24),
                Expanded(child: copy),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasImage) ...[image(), const SizedBox(height: 16)],
                copy,
              ],
            ),
    );
  }

  Widget _highlights(
    List<AboutContentItem> items,
    HomeThemeModel t,
    double width,
  ) {
    final mode = setting.highlightLayout;
    final columns = width >= 900
        ? 3
        : width >= 620
        ? 2
        : 1;
    final gap = _gap;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var index = 0; index < items.length; index++)
          SizedBox(
            width: (width - 40 - (columns - 1) * gap) / columns,
            child: KeyedSubtree(
              key: ValueKey('about-highlights-${items[index].id}'),
              child: _card(
                t,
                mode == 'ribbon'
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            icons[items[index].icon] ?? Icons.pets,
                            color: _color(
                              'iconColor',
                              t.primaryColor,
                              _surface(t),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (items[index].title.trim().isNotEmpty)
                                  _text(items[index].title, t, title: true),
                                if (items[index].text.trim().isNotEmpty)
                                  _text(items[index].text, t),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mode == 'numbered')
                            Text(
                              '${index + 1}'.padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: _color(
                                  'iconColor',
                                  t.primaryColor,
                                  _surface(t),
                                ),
                              ),
                            )
                          else
                            Icon(
                              icons[items[index].icon] ?? Icons.pets,
                              size: 30,
                              color: _color(
                                'iconColor',
                                t.primaryColor,
                                _surface(t),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (items[index].title.trim().isNotEmpty)
                            _text(items[index].title, t, title: true),
                          if (items[index].text.trim().isNotEmpty)
                            _text(items[index].text, t),
                        ],
                      ),
                '',
              ),
            ),
          ),
      ],
    );
  }

  Widget _block(String title, Widget content, HomeThemeModel t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(title, t, title: true, surface: _background),
        const SizedBox(height: 12),
        content,
      ],
    ),
  );
  Widget _card(HomeThemeModel t, Widget content, String image) {
    final custom = setting.appearance['cardsSource'] == 'custom';
    final fill = _cardFill(t);
    final inherited = _frontStyle;
    final borderWidth = custom
        ? setting.number('borderWidth', 1, min: 0, max: 5)
        : inherited?.cardBorder == false
        ? 0.0
        : 1.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(
          custom
              ? setting.number('radius', 24, min: 0, max: 40)
              : inherited == null
              ? 26
              : HomeDisplayRadii.pixels(inherited.cardRadius),
        ),
        border: borderWidth > 0
            ? Border.all(
                color: custom
                    ? setting.color('borderColor', t.cardBorderColor)
                    : t.cardBorderColor,
                width: borderWidth,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: custom
                  ? setting.number('shadow', .04, min: 0, max: .25)
                  : inherited == null
                  ? 0.04
                  : inherited.cardShadow == HomeDisplayShadows.none
                  ? 0.0
                  : inherited.cardShadow == HomeDisplayShadows.strong
                  ? 0.12
                  : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (image.isNotEmpty && custom)
            Positioned.fill(
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => const SizedBox.shrink(),
              ),
            ),
          if (image.isNotEmpty && custom)
            Positioned.fill(
              child: ColoredBox(
                color: setting
                    .color('cardColor', t.cardColor)
                    .withValues(
                      alpha: setting.number('cardMask', .85, min: .65, max: 1),
                    ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(
              custom
                  ? setting.number('padding', 20, min: 8, max: 36)
                  : inherited == null
                  ? 22
                  : HomeDisplaySpacings.gap(inherited.cardPadding) + 8,
            ),
            child: TextButtonTheme(
              data: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: _color(
                    'buttonColor',
                    t.primaryColor,
                    _surface(t, image: image.isNotEmpty),
                  ),
                ),
              ),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    AboutContentItem item,
    String section,
    int index,
    double width,
    HomeThemeModel t,
    String image,
  ) {
    final frame = setting.coverFrame(shop);
    final photo =
        _hasImage(item.image) &&
            !(const ['team', 'credentials'].contains(section) &&
                item.image.source == 'platform')
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: _aspect,
              child: AboutMediaView(
                media: item.image,
                shop: shop,
                fit: frame.boxFit,
                alignment: frame.alignment,
              ),
            ),
          )
        : null;
    final surface = _surface(t, image: image.isNotEmpty);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section == 'principles')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Icon(
              icons[item.icon] ?? Icons.pets,
              color: _color('iconColor', t.primaryColor, surface),
            ),
          ),
        if (item.title.trim().isNotEmpty)
          _text(item.title, t, title: true, surface: surface),
        if (item.role.trim().isNotEmpty)
          _text(item.role, t, secondary: true, surface: surface),
        if (item.text.trim().isNotEmpty) _text(item.text, t, surface: surface),
        if (section == 'credentials' && item.id != 'public-license')
          Text(
            '店家自行提供',
            style: TextStyle(
              fontSize: 12,
              color: _color(
                'secondaryTextColor',
                t.secondaryTextColor,
                surface,
              ),
            ),
          ),
      ],
    );
    final alternating =
        section == 'stories' &&
        setting.layout == 'alternating' &&
        width >= 700 &&
        photo != null;
    return _card(
      t,
      alternating
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: index.isEven
                  ? [
                      Expanded(child: photo),
                      const SizedBox(width: 20),
                      Expanded(child: copy),
                    ]
                  : [
                      Expanded(child: copy),
                      const SizedBox(width: 20),
                      Expanded(child: photo),
                    ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photo != null) ...[photo, const SizedBox(height: 14)],
                copy,
              ],
            ),
      image,
    );
  }
}

class _AboutLongText extends StatefulWidget {
  const _AboutLongText({
    required this.text,
    required this.expandable,
    required this.color,
  });
  final String text;
  final bool expandable;
  final Color color;
  @override
  State<_AboutLongText> createState() => _AboutLongTextState();
}

class _AboutLongTextState extends State<_AboutLongText> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.text,
        maxLines: widget.expandable && !_open ? 5 : null,
        overflow: widget.expandable && !_open ? TextOverflow.ellipsis : null,
        style: TextStyle(color: widget.color, height: 1.8),
      ),
      if (widget.expandable)
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          child: Text(_open ? '收合介紹' : '展開閱讀'),
        ),
    ],
  );
}
