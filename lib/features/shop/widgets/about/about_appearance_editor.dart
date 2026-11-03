import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import '../modern_home/shop_info_template_preview.dart';
import 'about_quick_template_card.dart';
import 'package:petnest_saas/core/models/about_page_template.dart';
// 功能：完整介紹頁的獨立字體、配色、卡片與背景覆寫，圖庫只保存素材 ID。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/environment_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_card_image_setting.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import '../platform_media_asset_picker.dart';
import '../modern_home/home_card_image.dart';
import '../store/store_banner_color_field.dart';
import '../shop_app_backdrop.dart';

class AboutAppearanceEditor extends StatelessWidget {
  const AboutAppearanceEditor({
    super.key,
    required this.setting,
    required this.theme,
    required this.onChanged,
    this.shop = const {},
    this.onApplyTemplate,
    this.section = 'all',
  });
  final String section;
  final Map<String, dynamic> shop;
  final ValueChanged<bool>? onApplyTemplate;
  final AboutPageSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<AboutPageSetting> onChanged;
  void _change(Map<String, dynamic> values) =>
      onChanged(setting.withAppearance(values));
  Widget _chips(
    String label,
    String selected,
    Map<String, String> choices,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final e in choices.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: e.key == selected,
                onSelected: (_) => change(e.key),
              ),
          ],
        ),
      ],
    ),
  );
  Widget _layoutOptions(
    String label,
    String selected,
    Map<String, String> choices,
    String field,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in choices.entries)
            SizedBox(
              width: 144,
              child: Semantics(
                selected: selected == choice.key,
                child: OutlinedButton(
                  onPressed: () => _change({field: choice.key}),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected == choice.key
                        ? theme.primaryColor.withValues(alpha: .1)
                        : null,
                    padding: const EdgeInsets.all(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 48,
                        child: CustomPaint(
                          painter: _BlockLayoutSketch(
                            '$field:${choice.key}',
                            theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selected == choice.key ? '✓ ' : ''}${choice.value}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
  Widget _slider(
    String label,
    String key,
    double value,
    double min,
    double max,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(
        value: value,
        min: min,
        max: max,
        label: value.toStringAsFixed(2),
        onChanged: (v) => _change({key: v}),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final a = setting.appearance;
    final customColors = a['colorsSource'] == 'custom',
        customCards = a['cardsSource'] == 'custom';
    final colors = {
      'accentColor': ('主要強調色', theme.primaryColor),
      'titleColor': ('標題', theme.textColor),
      'bodyColor': ('內文', theme.textColor),
      'secondaryTextColor': ('次要文字', theme.secondaryTextColor),
      'iconColor': ('圖示', theme.primaryColor),
      'buttonColor': ('按鈕文字', theme.primaryColor),
    };
    final groups = <String, List<Widget>>{
      'templates': [
        AboutQuickTemplateCard(
          setting: setting,
          theme: theme,
          shop: shop,
          onApply: (fillEmpty) {
            if (onApplyTemplate != null) {
              onApplyTemplate!(fillEmpty);
            } else {
              onChanged(
                AboutPageTemplate.apply(
                  setting,
                  shop: shop,
                  fillEmpty: fillEmpty,
                ),
              );
            }
          },
        ),
        ExpansionTile(
          key: const PageStorageKey<String>('about-other-layouts'),
          title: const Text('其他整頁版型'),
          subtitle: const Text('保留既有版型；選好後仍可分區微調'),
          children: [
            const Text(
              '排版選擇',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in AboutPageSetting.layouts.entries)
                    SizedBox(
                      width: c.maxWidth >= 600
                          ? (c.maxWidth - 8) / 2
                          : c.maxWidth,
                      child: Card(
                        color: setting.layout == e.key
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          onTap: () {
                            if (e.key == 'daylight') {
                              if (onApplyTemplate != null) {
                                onApplyTemplate!(false);
                              } else {
                                onChanged(
                                  AboutPageTemplate.apply(setting, shop: shop),
                                );
                              }
                            } else {
                              onChanged(setting.copyWith({'layout': e.key}));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 60,
                                  width: 180,
                                  child: CustomPaint(
                                    painter: _AboutLayoutSketch(
                                      e.key,
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  e.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  const {
                                    'classic': '封面標題、理念與完整介紹',
                                    'daylight': '大圖置中介紹、右圖理念卡、圖文故事與橫列資訊',
                                    'brief': '主照片搭配精簡介紹，接續理念',
                                    'story': '大封面與分段故事照片',
                                    'alternating': '桌機圖文左右交替，手機上下排列',
                                    'principles': '以照護理念卡片為主要內容',
                                    'team': '優先介紹店主與團隊，再接理念經歷',
                                    'boutique': '置中品牌抬頭，優先展示店家資訊與特色',
                                    'highlights': '圖文簡介搭配橫向服務亮點',
                                    'editorial': '專欄抬頭、編號特色與到店資訊',
                                  }[e.key]!,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
      'cover': [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('店家資訊固定顯示'),
          subtitle: Text('自動引用店家基本資料與營業資訊；所有版型都會保留。'),
        ),
        _layoutOptions(
          '封面排列',
          setting.coverLayout,
          AboutPageSetting.coverLayouts,
          'coverLayout',
        ),
      ],
      'principles': [
        _layoutOptions(
          '照護理念排列',
          setting.principleLayout,
          AboutPageSetting.principleLayouts,
          'principleLayout',
        ),
      ],
      'stories': [
        _layoutOptions(
          '品牌故事排列',
          setting.storyLayout,
          AboutPageSetting.storyLayouts,
          'storyLayout',
        ),
      ],
      'contact': [
        const Text(
          '底部店家資訊快速選擇',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text('只修改關於我們的底部資訊；沿用真實店家資料與照片，不改首頁資訊卡。'),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in shopInfoPresets)
                SizedBox(
                  width: c.maxWidth >= 600
                      ? (c.maxWidth - 20) / 3
                      : c.maxWidth >= 340
                      ? (c.maxWidth - 10) / 2
                      : c.maxWidth,
                  child: Semantics(
                    selected:
                        setting.contactLayout == 'footer' &&
                        setting.contactFooter.preset == preset.id,
                    child: Card(
                      color:
                          setting.contactLayout == 'footer' &&
                              setting.contactFooter.preset == preset.id
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: InkWell(
                        onTap: () => _change({
                          'contactLayout': 'footer',
                          'contactFooter': preset
                              .apply(setting.contactFooter)
                              .copyWith(mode: 'expanded')
                              .toMap(),
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 85,
                                width: double.infinity,
                                child: ShopInfoTemplatePreview(preset: preset),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${setting.contactLayout == 'footer' && setting.contactFooter.preset == preset.id ? '✓ ' : ''}${preset.label}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (setting.contactLayout == 'footer') ...[
          _chips(
            '資訊卡照片來源',
            setting.contactFooter.imageSource,
            const {'none': '不放照片', 'logo': '店家 Logo', 'photo': '沿用店家照片'},
            (value) => _change({
              'contactFooter': setting.contactFooter
                  .copyWith(imageSource: value)
                  .toMap(),
            }),
          ),
          const Text(
            '照片沿用本店既有素材，不會加入範本示意照片。電話、地圖與 LINE 只在資料有效時顯示。',
            style: TextStyle(fontSize: 12),
          ),
        ],

        _layoutOptions(
          '店家資訊呈現',
          setting.contactLayout,
          AboutPageSetting.contactLayouts,
          'contactLayout',
        ),
      ],
      'highlights': [
        _layoutOptions(
          '特色展示方式',
          setting.highlightLayout,
          AboutPageSetting.highlightLayouts,
          'highlightLayout',
        ),
      ],
      'advanced': [
        _chips(
          '區塊間距',
          setting.sectionSpacing,
          AboutPageSetting.sectionSpacings,
          (value) => _change({'sectionSpacing': value}),
        ),
        const Text('各區塊可獨立調整，切換不會清空內容、照片或顯示設定。'),
        ExpansionTile(
          key: const PageStorageKey<String>('about-section-backgrounds'),
          title: const Text('各區塊背景色'),
          subtitle: const Text('分別調整封面、理念、故事、服務與底部資訊的底色'),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            for (final section in {
              'cover': '封面與介紹',
              ...AboutPageSetting.sectionNames,
            }.entries) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${section.value}：獨立底色'),
                value: setting.sectionBackground(section.key) != null,
                onChanged: (custom) => onChanged(
                  setting.withSectionBackground(
                    section.key,
                    custom ? theme.backgroundColor : null,
                  ),
                ),
              ),
              if (setting.sectionBackground(section.key) != null)
                StoreBannerColorField(
                  label: '${section.value}底色',
                  argb: setting.sectionBackground(section.key)!.toARGB32(),
                  onChanged: (value) => onChanged(
                    setting.withSectionBackground(section.key, Color(value)),
                  ),
                ),
            ],
            const Text(
              '關閉獨立底色會沿用整體頁面背景；卡片本身的底色在「卡片外觀」調整。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),

        ExpansionTile(
          key: const PageStorageKey<String>('about-advanced-0'),
          title: const Text('字體與文字大小'),
          children: [
            _chips(
              '字體來源',
              '${a['fontSource'] ?? 'theme'}',
              const {'theme': '跟隨前台設定', 'custom': '此頁自訂'},
              (v) => _change({
                'fontSource': v,
                if (v == 'custom' && a['fontFamily'] == null)
                  'fontFamily': 'NotoSansTC',
              }),
            ),
            if (a['fontSource'] == 'custom')
              RadioGroup<String>(
                groupValue: '${a['fontFamily'] ?? 'NotoSansTC'}',
                onChanged: (v) => _change({'fontFamily': v}),
                child: Column(
                  children: [
                    for (final font in {
                      ...EnvironmentPageAppearance.fonts,
                      'KleeOne': 'Klee One 手寫楷書',
                    }.entries.where((e) => e.key.isNotEmpty))
                      RadioListTile<String>(
                        value: font.key,
                        title: Text(font.value),
                        subtitle: Text(
                          '安心照護，每一隻貓咪都是家人。',
                          style: TextStyle(fontFamily: font.key),
                        ),
                      ),
                  ],
                ),
              ),
            _slider('整頁文字大小', 'textScale', setting.textScale, .85, 1.4),
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey<String>('about-advanced-1'),
          title: const Text('整頁顏色'),
          children: [
            _chips(
              '顏色來源',
              '${a['colorsSource'] ?? 'theme'}',
              const {'theme': '跟隨前台設定', 'custom': '此頁自訂'},
              (v) => _change({'colorsSource': v}),
            ),
            if (customColors) ...[
              const Text('對比不足時會自動調整文字以維持可讀性。'),
              for (final e in colors.entries)
                StoreBannerColorField(
                  label: e.value.$1,
                  argb: setting.color(e.key, e.value.$2).toARGB32(),
                  onChanged: (v) => _change({e.key: v}),
                ),
            ],
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey<String>('about-advanced-2'),
          title: const Text('卡片外觀'),
          children: [
            _chips(
              '卡片外觀',
              '${a['cardsSource'] ?? 'theme'}',
              const {'theme': '跟隨前台卡片', 'custom': '此頁自訂'},
              (v) => _change({'cardsSource': v}),
            ),
            if (customCards) ...[
              StoreBannerColorField(
                label: '卡片底色',
                argb: setting.color('cardColor', theme.cardColor).toARGB32(),
                onChanged: (v) => _change({'cardColor': v}),
              ),
              _slider(
                '卡片底色透明度',
                'cardOpacity',
                setting.number('cardOpacity', 1, min: 0, max: 1),
                0,
                1,
              ),
              _slider(
                '圓角',
                'radius',
                setting.number('radius', 24, min: 0, max: 40),
                0,
                40,
              ),
              StoreBannerColorField(
                label: '邊框色',
                argb: setting
                    .color('borderColor', theme.cardBorderColor)
                    .toARGB32(),
                onChanged: (v) => _change({'borderColor': v}),
              ),
              _slider(
                '邊框粗細',
                'borderWidth',
                setting.number('borderWidth', 1, min: 0, max: 5),
                0,
                5,
              ),
              _slider(
                '陰影強度',
                'shadow',
                setting.number('shadow', .04, min: 0, max: .25),
                0,
                .25,
              ),
              _slider(
                '卡片內距／資訊密度',
                'padding',
                setting.number('padding', 20, min: 8, max: 36),
                8,
                36,
              ),
              _slider('區塊間距', 'gap', setting.gap, 8, 48),
              _chips(
                '理念卡片背景',
                HomeCardImageSetting.fromMap(a['cardImage']).source,
                const {'icon': '純色卡片', 'platformCard': '圖庫卡片圖片'},
                (v) => _change({
                  'cardImage': HomeCardImageSetting.fromMap(
                    a['cardImage'],
                  ).copyWith(source: v).toMap(),
                }),
              ),
              if (HomeCardImageSetting.fromMap(a['cardImage']).usesLibrary) ...[
                HomeCardImageSettings(
                  setting: HomeCardImageSetting.fromMap(a['cardImage']),
                  showSource: false,
                  onChanged: (v) => _change({'cardImage': v.toMap()}),
                ),
                _slider(
                  '圖片文字底層遮罩',
                  'cardMask',
                  setting.number('cardMask', .85, min: .65, max: 1),
                  .65,
                  1,
                ),
              ],
            ],
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey<String>('about-advanced-3'),
          title: const Text('整體頁面背景'),
          children: [
            _chips(
              '頁面背景',
              '${a['backgroundSource'] ?? 'theme'}',
              const {'theme': '跟隨前台背景', 'color': '此頁純色', 'library': '平台背景圖庫'},
              (v) => _change({'backgroundSource': v}),
            ),
            if (a['backgroundSource'] == 'color')
              StoreBannerColorField(
                label: '背景色',
                argb: setting
                    .color('backgroundColor', theme.backgroundColor)
                    .toARGB32(),
                onChanged: (v) => _change({'backgroundColor': v}),
              ),
            if (a['backgroundSource'] == 'library') ...[
              if ('${a['backgroundAssetId'] ?? ''}'.isNotEmpty)
                SizedBox(
                  width: 260,
                  height: 180,
                  child: ShopAppBackdrop(
                    theme: theme.copyWith(
                      appBackgroundMode: 'image',
                      appBackgroundAssetId: '${a['backgroundAssetId']}',
                      appBackgroundScrim: setting.number(
                        'backgroundMask',
                        .3,
                        min: 0,
                        max: 1,
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('選擇背景圖庫'),
                onPressed: () async {
                  final result = await showModalBottomSheet<PlatformMediaPick>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (context) => PlatformMediaAssetPickerSheet(
                      category: PlatformMediaCategories.appBackground,
                      selectedId: '${a['backgroundAssetId'] ?? ''}',
                      confirmSelection: true,
                      title: '選擇關於我們背景',
                    ),
                  );
                  final asset = result?.asset;
                  if (!context.mounted ||
                      asset == null ||
                      !asset.enabled ||
                      asset.category != PlatformMediaCategories.appBackground) {
                    return;
                  }
                  _change({'backgroundAssetId': asset.id});
                },
              ),
              _chips(
                '背景圖片顯示',
                '${a['backgroundFit'] ?? 'cover'}',
                const {'cover': '填滿裁切', 'contain': '完整顯示'},
                (v) => _change({'backgroundFit': v}),
              ),
              _chips(
                '背景位置',
                '${a['backgroundAlign'] ?? 'center'}',
                const {'top': '靠上', 'center': '置中', 'bottom': '靠下'},
                (v) => _change({'backgroundAlign': v}),
              ),
              _slider(
                '背景遮罩',
                'backgroundMask',
                setting.number('backgroundMask', .3, min: 0, max: 1),
                0,
                1,
              ),
            ],
          ],
        ),
        OutlinedButton(
          onPressed: () => onChanged(
            setting.withAppearance({
              'fontSource': 'theme',
              'colorsSource': 'theme',
              'cardsSource': 'theme',
              'backgroundSource': 'theme',
              'textScale': 1,
              'sectionBackgrounds': <String, dynamic>{},
              'gap': 24,
            }),
          ),
          child: const Text('恢復跟隨前台（保留內容與照片）'),
        ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: section == 'all'
          ? groups.values.expand((children) => children).toList()
          : (groups[section] ?? const <Widget>[]),
    );
  }
}

class _AboutLayoutSketch extends CustomPainter {
  _AboutLayoutSketch(this.layout, this.color);
  final String layout;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    void box(double x, double y, double w, double h) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(3),
      ),
      Paint()..color = color.withValues(alpha: .3),
    );
    switch (layout) {
      case 'daylight':
        box(0, 0, 170, 18);
        box(55, 22, 60, 6);
        for (var i = 0; i < 3; i++) {
          box(i * 58, 33, 50, 12);
        }
        box(0, 50, 60, 10);
        box(70, 50, 100, 8);
        break;
      case 'boutique':
        box(55, 0, 60, 12);
        box(25, 20, 120, 6);
        box(0, 35, 170, 25);
        break;
      case 'highlights':
        box(0, 0, 70, 28);
        box(80, 0, 90, 8);
        box(80, 16, 80, 6);
        for (var i = 0; i < 3; i++) {
          box(i * 58, 38, 50, 20);
        }
        break;
      case 'editorial':
        box(0, 0, 170, 3);
        box(0, 10, 140, 10);
        box(0, 28, 170, 16);
        box(0, 50, 170, 8);
        break;
      case 'brief':
        box(0, 0, 65, 45);
        box(75, 4, 95, 7);
        box(75, 18, 80, 5);
        box(0, 51, 170, 7);
        break;
      case 'story':
        box(0, 0, 170, 20);
        box(0, 25, 170, 5);
        box(0, 36, 80, 24);
        box(90, 36, 80, 24);
        break;
      case 'alternating':
        box(0, 0, 70, 25);
        box(80, 0, 90, 8);
        box(0, 35, 90, 8);
        box(100, 35, 70, 25);
        break;
      case 'principles':
        box(0, 0, 170, 10);
        for (var i = 0; i < 3; i++) {
          box(i * 58, 18, 50, 40);
        }
        break;
      case 'team':
        box(0, 0, 170, 10);
        for (var i = 0; i < 2; i++) {
          box(i * 88, 18, 76, 26);
          box(i * 88, 49, 76, 8);
        }
        break;
      default:
        box(0, 0, 170, 28);
        box(0, 35, 170, 8);
        box(0, 49, 170, 8);
    }
  }

  @override
  bool shouldRepaint(covariant _AboutLayoutSketch old) =>
      old.layout != layout || old.color != color;
}

// 專用排列示意，只畫照片與文字位置，不加入裝飾素材。
class _BlockLayoutSketch extends CustomPainter {
  const _BlockLayoutSketch(this.mode, this.color);
  final String mode;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    void box(double x, double y, double w, double h, [bool image = false]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: image ? .25 : .65),
      );
    }

    if (mode.endsWith(':imageLeft') || mode.endsWith(':imageRight')) {
      final left = mode.endsWith(':imageLeft');
      box(left ? 0 : 64, 2, 46, 44, true);
      box(left ? 54 : 0, 12, 46, 5);
      box(left ? 54 : 0, 24, 46, 4);
    } else if (mode.endsWith(':stacked') ||
        mode.endsWith(':centered') ||
        mode.endsWith(':auto')) {
      box(0, 0, 110, 28, true);
      box(0, 34, 70, 4);
      box(0, 43, 100, 3);
    } else if (mode.endsWith(':photoSide')) {
      box(0, 6, 50, 6);
      box(0, 20, 50, 4);
      box(0, 31, 50, 4);
      box(60, 0, 50, 48, true);
    } else if (mode.endsWith(':strip')) {
      for (var i = 0; i < 3; i++) {
        box(i * 37.0, 12, 30, 7);
        box(i * 37.0, 26, 30, 4);
      }
    } else if (mode.endsWith(':tiles') || mode.endsWith(':cards')) {
      for (var i = 0; i < 4; i++) {
        box((i % 2) * 57.0, (i ~/ 2) * 25.0, 50, 20, true);
      }
    } else if (mode.endsWith(':brand')) {
      box(42, 0, 24, 20, true);
      box(24, 26, 62, 5);
      box(10, 38, 90, 4);
    } else if (mode.endsWith(':visit')) {
      box(0, 0, 40, 48, true);
      box(50, 7, 60, 6);
      box(50, 22, 48, 4);
      box(50, 36, 60, 8, true);
    } else if (mode.endsWith(':ribbon')) {
      for (var i = 0; i < 3; i++) {
        box(i * 38.0, 4, 32, 38, true);
      }
    } else {
      for (var i = 0; i < 3; i++) {
        box(0, i * 16.0, 10, 10, true);
        box(18, i * 16.0 + 2, 88, 4);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlockLayoutSketch old) =>
      old.mode != mode || old.color != color;
}

// 套用範本時同步外部草稿，打字時保留游標與焦點。
class AboutCoverSubtitleField extends StatefulWidget {
  const AboutCoverSubtitleField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<AboutCoverSubtitleField> createState() =>
      AboutCoverSubtitleFieldState();
}

class AboutCoverSubtitleFieldState extends State<AboutCoverSubtitleField> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant AboutCoverSubtitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const PageStorageKey<String>('about-input-cover-subtitle'),
    child: TextField(
      key: const ValueKey('about-cover-subtitle-field'),
      controller: controller,
      decoration: const InputDecoration(
        labelText: '封面副標題（選填）',
        hintText: '例如：安心入住，細心陪伴',
      ),
      onChanged: widget.onChanged,
    ),
  );
}
