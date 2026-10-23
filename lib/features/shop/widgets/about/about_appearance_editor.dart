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
  });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  width: c.maxWidth >= 600 ? (c.maxWidth - 8) / 2 : c.maxWidth,
                  child: Card(
                    color: setting.layout == e.key
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: InkWell(
                      onTap: () =>
                          onChanged(setting.copyWith({'layout': e.key})),
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
                                'brief': '主照片搭配精簡介紹，接續理念',
                                'story': '大封面與分段故事照片',
                                'alternating': '桌機圖文左右交替，手機上下排列',
                                'principles': '以照護理念卡片為主要內容',
                                'team': '優先介紹店主與團隊，再接理念經歷',
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
        _chips('卡片外觀', '${a['cardsSource'] ?? 'theme'}', const {
          'theme': '跟隨前台卡片',
          'custom': '此頁自訂',
        }, (v) => _change({'cardsSource': v})),
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
        OutlinedButton(
          onPressed: () => onChanged(
            setting.withAppearance({
              'fontSource': 'theme',
              'colorsSource': 'theme',
              'cardsSource': 'theme',
              'backgroundSource': 'theme',
              'textScale': 1,
              'gap': 24,
            }),
          ),
          child: const Text('恢復跟隨前台（保留內容與照片）'),
        ),
      ],
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
