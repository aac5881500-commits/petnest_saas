import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';

/// 外觀設定裡的兩張共用卡片，以及各區塊的沿用／自訂。
class HomeDisplayStyleEditor extends StatelessWidget {
  const HomeDisplayStyleEditor({
    super.key,
    required this.setting,
    required this.onChanged,
    this.storeEnabled = false,
  });

  final HomeDisplayStyleSetting setting;
  final ValueChanged<HomeDisplayStyleSetting> onChanged;
  final bool storeEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool sideBySide = constraints.maxWidth >= 760;
        final Widget textCard = _card(
          title: '圖片與文字排版',
          subtitle: '首頁展示卡的文字位置、大小、粗細、顏色與間距。',
          child: HomeDisplayTextForm(
            style: setting.style,
            onChanged: (HomeDisplayStyle style) {
              onChanged(setting.copyWith(saved: true, style: style));
            },
          ),
        );
        final Widget cardCard = _card(
          title: '展示卡片外觀',
          subtitle: '背景、圓角、邊框、圖片比例與間距。不適用的區塊會略過。',
          child: HomeDisplayCardForm(
            style: setting.style,
            onChanged: (HomeDisplayStyle style) {
              onChanged(setting.copyWith(saved: true, style: style));
            },
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: textCard),
                  const SizedBox(width: 12),
                  Expanded(child: cardCard),
                ],
              )
            else ...<Widget>[textCard, const SizedBox(height: 12), cardCard],
            const SizedBox(height: 8),
            const Text(
              '房型介紹、環境介紹、關於我們、消息與顧客評價會使用這套樣式。區塊裡原本已調整過的文字或卡片會先保留，可在該分頁按「恢復共用」。',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.black54,
              ),
            ),
            if (storeEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '精選商品標題也會沿用文字大小、粗細與顏色。商品價格與購買流程不變。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class HomeDisplaySectionModeTile extends StatelessWidget {
  const HomeDisplaySectionModeTile({
    super.key,
    required this.label,
    required this.mode,
    required this.onInherit,
    required this.onCustom,
    this.onRestore,
  });

  final String label;
  final String mode;
  final VoidCallback onInherit;
  final VoidCallback onCustom;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final bool custom = mode == HomeDisplayStyleModes.custom;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ChoiceChip(
            label: const Text('沿用'),
            selected: !custom,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => onInherit(),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('自訂'),
            selected: custom,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => onCustom(),
          ),
          if (custom && onRestore != null)
            TextButton(onPressed: onRestore, child: const Text('恢復共用')),
        ],
      ),
    );
  }
}

class HomeDisplayTextForm extends StatelessWidget {
  const HomeDisplayTextForm({
    super.key,
    required this.style,
    required this.onChanged,
  });

  final HomeDisplayStyle style;
  final ValueChanged<HomeDisplayStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool separate = style.colorMode == HomeDisplayColorModes.separate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '文字位置',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayTextPositions.above, '圖片上方'),
            (HomeDisplayTextPositions.overlay, '圖片中央'),
            (HomeDisplayTextPositions.below, '圖片下方'),
          ],
          selected: style.textPosition,
          onChanged: (String value) =>
              onChanged(style.copyWith(textPosition: value)),
        ),
        const SizedBox(height: 10),
        const Text(
          '標題',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplaySizes.small, '標題小'),
            (HomeDisplaySizes.medium, '標題中'),
            (HomeDisplaySizes.large, '標題大'),
          ],
          selected: style.titleSize,
          onChanged: (String value) =>
              onChanged(style.copyWith(titleSize: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayWeights.regular, '標題一般'),
            (HomeDisplayWeights.medium, '標題中等'),
            (HomeDisplayWeights.bold, '標題粗體'),
          ],
          selected: style.titleWeight,
          onChanged: (String value) =>
              onChanged(style.copyWith(titleWeight: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayAligns.start, '標題靠左'),
            (HomeDisplayAligns.center, '標題置中'),
            (HomeDisplayAligns.end, '標題靠右'),
          ],
          selected: style.titleAlign,
          onChanged: (String value) =>
              onChanged(style.copyWith(titleAlign: value)),
        ),
        const SizedBox(height: 10),
        const Text(
          '說明',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplaySizes.small, '說明小'),
            (HomeDisplaySizes.medium, '說明中'),
            (HomeDisplaySizes.large, '說明大'),
          ],
          selected: style.bodySize,
          onChanged: (String value) =>
              onChanged(style.copyWith(bodySize: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayWeights.regular, '說明一般'),
            (HomeDisplayWeights.medium, '說明中等'),
            (HomeDisplayWeights.bold, '說明粗體'),
          ],
          selected: style.bodyWeight,
          onChanged: (String value) =>
              onChanged(style.copyWith(bodyWeight: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayAligns.start, '說明靠左'),
            (HomeDisplayAligns.center, '說明置中'),
            (HomeDisplayAligns.end, '說明靠右'),
          ],
          selected: style.bodyAlign,
          onChanged: (String value) =>
              onChanged(style.copyWith(bodyAlign: value)),
        ),
        const SizedBox(height: 10),
        const Text(
          '文字顏色',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayColorModes.unified, '統一顏色'),
            (HomeDisplayColorModes.separate, '分別設定'),
          ],
          selected: style.colorMode,
          onChanged: (String value) =>
              onChanged(style.copyWith(colorMode: value)),
        ),
        const SizedBox(height: 8),
        _palette(
          label: separate ? '標題顏色' : '文字顏色',
          color: style.titleColor,
          onChanged: (int color) =>
              onChanged(style.copyWith(titleColor: color)),
        ),
        if (separate) ...<Widget>[
          const SizedBox(height: 8),
          _palette(
            label: '說明顏色',
            color: style.bodyColor,
            onChanged: (int color) =>
                onChanged(style.copyWith(bodyColor: color)),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          '圖片與文字間距',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplaySpacings.compact, '緊湊'),
            (HomeDisplaySpacings.normal, '一般'),
            (HomeDisplaySpacings.relaxed, '寬鬆'),
          ],
          selected: style.spacing,
          onChanged: (String value) =>
              onChanged(style.copyWith(spacing: value)),
        ),
      ],
    );
  }
}

class HomeDisplayCardForm extends StatelessWidget {
  const HomeDisplayCardForm({
    super.key,
    required this.style,
    required this.onChanged,
  });

  final HomeDisplayStyle style;
  final ValueChanged<HomeDisplayStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _chips(
          options: const <(String, String)>[
            (HomeDisplayBackgrounds.filled, '淡色底'),
            (HomeDisplayBackgrounds.outlined, '只有框線'),
            (HomeDisplayBackgrounds.transparent, '透明'),
          ],
          selected: style.cardBackground,
          onChanged: (String value) =>
              onChanged(style.copyWith(cardBackground: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayRadii.small, '圓角小'),
            (HomeDisplayRadii.medium, '圓角中'),
            (HomeDisplayRadii.large, '圓角大'),
          ],
          selected: style.cardRadius,
          onChanged: (String value) =>
              onChanged(style.copyWith(cardRadius: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            ('border', '顯示邊框'),
            ('none', '無邊框'),
          ],
          selected: style.cardBorder ? 'border' : 'none',
          onChanged: (String value) {
            onChanged(style.copyWith(cardBorder: value == 'border'));
          },
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayShadows.none, '無陰影'),
            (HomeDisplayShadows.soft, '淡陰影'),
          ],
          selected: style.cardShadow,
          onChanged: (String value) =>
              onChanged(style.copyWith(cardShadow: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            ('square', '圖片正方形'),
            ('portrait', '圖片直式'),
            ('landscape', '圖片橫式'),
          ],
          selected: style.imageAspect,
          onChanged: (String value) =>
              onChanged(style.copyWith(imageAspect: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayFits.cover, '裁切填滿'),
            (HomeDisplayFits.contain, '完整顯示'),
          ],
          selected: style.imageFit,
          onChanged: (String value) =>
              onChanged(style.copyWith(imageFit: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplayMasks.none, '遮罩無'),
            (HomeDisplayMasks.light, '遮罩淡'),
            (HomeDisplayMasks.strong, '遮罩深'),
          ],
          selected: style.imageMask,
          onChanged: (String value) =>
              onChanged(style.copyWith(imageMask: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplaySpacings.compact, '內距緊湊'),
            (HomeDisplaySpacings.normal, '內距一般'),
            (HomeDisplaySpacings.relaxed, '內距寬鬆'),
          ],
          selected: style.cardPadding,
          onChanged: (String value) =>
              onChanged(style.copyWith(cardPadding: value)),
        ),
        const SizedBox(height: 6),
        _chips(
          options: const <(String, String)>[
            (HomeDisplaySpacings.compact, '卡片間距緊湊'),
            (HomeDisplaySpacings.normal, '卡片間距一般'),
            (HomeDisplaySpacings.relaxed, '卡片間距寬鬆'),
          ],
          selected: style.cardGap,
          onChanged: (String value) =>
              onChanged(style.copyWith(cardGap: value)),
        ),
      ],
    );
  }
}

class HomeDisplaySectionOverride extends StatelessWidget {
  const HomeDisplaySectionOverride({
    super.key,
    required this.label,
    required this.mode,
    required this.effective,
    required this.shared,
    required this.onInherit,
    required this.onCustom,
    required this.onEdit,
  });

  final String label;
  final String mode;
  final HomeDisplayStyle effective;
  final HomeDisplayStyle shared;
  final VoidCallback onInherit;
  final VoidCallback onCustom;
  final ValueChanged<HomeDisplayStyle> onEdit;

  @override
  Widget build(BuildContext context) {
    final bool custom = mode == HomeDisplayStyleModes.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('卡片外觀', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          custom ? '只覆蓋這張有改過的項目，其餘仍跟共用樣式。' : '目前沿用外觀設定裡的首頁共用樣式。',
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        HomeDisplaySectionModeTile(
          label: label,
          mode: mode,
          onInherit: onInherit,
          onCustom: onCustom,
          onRestore: custom ? onInherit : null,
        ),
        if (custom) ...<Widget>[
          const Divider(height: 20),
          HomeDisplayTextForm(style: effective, onChanged: onEdit),
          const SizedBox(height: 8),
          HomeDisplayCardForm(style: effective, onChanged: onEdit),
        ],
      ],
    );
  }
}

Widget _chips({
  required List<(String, String)> options,
  required String selected,
  required ValueChanged<String> onChanged,
}) {
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: <Widget>[
      for (final (String value, String label) in options)
        ChoiceChip(
          label: Text(label),
          selected: selected == value,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => onChanged(value),
        ),
    ],
  );
}

Widget _palette({
  required String label,
  required int color,
  required ValueChanged<int> onChanged,
}) {
  const List<int> swatches = <int>[
    0xFF3A2A20,
    0xFFFFFFFF,
    0xFFA56B45,
    0xFF5E84A6,
    0xFF2F6B4F,
    0xFFE06B84,
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final int swatch in swatches)
            InkWell(
              key: Key('display-color-$label-${swatch.toRadixString(16)}'),
              customBorder: const CircleBorder(),
              onTap: () => onChanged(swatch),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(swatch),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == swatch
                        ? const Color(0xFF3A2A20)
                        : const Color(0xFFE6E8EC),
                    width: color == swatch ? 2 : 1,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 120,
            child: TextFormField(
              key: ValueKey<String>('$label-$color'),
              initialValue:
                  '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              decoration: const InputDecoration(
                labelText: '色碼',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (String raw) {
                String hex = raw.trim().replaceAll('#', '');
                if (hex.length == 6) {
                  hex = 'FF$hex';
                }
                final int? next = int.tryParse(hex, radix: 16);
                if (next != null && hex.length == 8) {
                  onChanged(next);
                }
              },
            ),
          ),
        ],
      ),
    ],
  );
}
