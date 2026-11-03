import 'environment_photo.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_layout_settings.dart';
import '../store/store_banner_color_field.dart';

class EnvironmentLayoutEditor extends StatelessWidget {
  const EnvironmentLayoutEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.busy,
  });
  final EnvironmentLayoutSettings value;
  final ValueChanged<EnvironmentLayoutSettings> onChanged;
  final bool busy;
  void change(String key, Object? next) =>
      onChanged(value.copyWith({key: next}));
  Widget choices(
    String label,
    String key,
    String selected,
    Map<String, String> options,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      Wrap(
        spacing: 6,
        children: [
          for (final item in options.entries)
            ChoiceChip(
              label: Text(item.value),
              selected: selected == item.key,
              onSelected: busy ? null : (_) => change(key, item.key),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );
  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('APP 排版設定', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('以手機內容為主；電腦自動調整欄數與區塊並排，不需另設桌機版。'),
        const SizedBox(height: 12),
        choices('封面呈現', 'heroLayout', value.heroLayout, {
          'overlay': '原有覆圖',
          'split': '分割圖文',
        }),
        choices('特色圖文', 'featureLayout', value.featureLayout, {
          'standard': '原有卡片',
          'photoSide': '照片橫向卡',
        }),
        choices('設備與服務', 'equipmentLayout', value.equipmentLayout, {
          'standard': '原有設備版型',
          'mediaRow': '圖文橫列',
        }),
        choices('中段橫幅', 'bannerLayout', value.bannerLayout, {
          'overlay': '原有覆圖',
          'split': '色塊與照片',
        }),
        choices('手機封面標題換行', 'heroLineBreak', value.text('heroLineBreak'), {
          '': '自動換行',
          'punctuation': '依逗號換行',
        }),
        for (final item in <(String, String, bool)>[
          ('footerTogether', '相簿與提醒自動並排', value.footerTogether),
          ('showFeatureHeading', '顯示特色區塊標題', value.showFeatureHeading),
          ('showEquipmentHeading', '顯示設備區塊標題', value.showEquipmentHeading),
          ('showGalleryHeading', '顯示相簿區塊標題', value.showGalleryHeading),
          ('showFeatureIcon', '顯示特色圖示', value.showFeatureIcon),
          ('showDivider', '特色文字分隔線', value.showDivider),
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.$2),
            value: item.$3,
            onChanged: (v) => change(item.$1, v),
          ),
        TextButton.icon(
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('選擇封面背景照片'),
          onPressed: () async {
            final url = await pickEnvironmentBuiltinPhoto(context);
            if (url != null) change('heroBackdrop', url);
          },
        ),
        TextButton(
          onPressed: () => change('heroBackdrop', null),
          child: const Text('移除封面背景照片'),
        ),
        for (final item in <(String, String, double, double, double)>[
          (
            'heroHeight',
            '封面高度',
            value.number('heroHeight', 240, 140, 420),
            140,
            420,
          ),
          (
            'heroTitleSize',
            '封面標題大小',
            value.number('heroTitleSize', 27, 18, 42),
            18,
            42,
          ),
          (
            'heroPhotoFraction',
            '封面照片占比',
            value.number('heroPhotoFraction', .62, .3, .85),
            .3,
            .85,
          ),
          (
            'bannerHeight',
            '橫幅高度',
            value.number('bannerHeight', 92, 72, 220),
            72,
            220,
          ),
          (
            'bannerTitleSize',
            '橫幅標題大小',
            value.number('bannerTitleSize', 20, 14, 34),
            14,
            34,
          ),
          (
            'bannerPhotoFraction',
            '橫幅照片占比',
            value.number('bannerPhotoFraction', .42, .25, .65),
            .25,
            .65,
          ),
          (
            'galleryAspect',
            '相簿照片寬高比',
            value.number('galleryAspect', 4 / 3, 1, 2.5),
            1,
            2.5,
          ),
          (
            'noteFontSize',
            '提醒文字大小',
            value.number('noteFontSize', 11, 9, 20),
            9,
            20,
          ),
          ('photoFraction', '特色照片占比', value.photoFraction, .25, .6),
          ('photoHeight', '特色卡片高度', value.photoHeight, 100, 240),
          ('cardRadius', '卡片圓角', value.cardRadius, 0, 28),
          ('spacing', '特色卡片間距', value.spacing, 4, 36),
          ('titleSize', '特色標題大小', value.titleSize, 13, 28),
        ]) ...[
          Text(
            '${item.$2}：${item.$3.toStringAsFixed(item.$1.toLowerCase().contains('fraction') || item.$1 == 'galleryAspect' ? 2 : 0)}',
          ),
          Slider(
            value: item.$3,
            min: item.$4,
            max: item.$5,
            onChanged: (v) => change(item.$1, v),
          ),
        ],
        for (final item in const {
          'heroEyebrow': '封面小標',
          'bannerSubtitle': '橫幅副標題',
          'noteTitle': '提醒標題',
        }.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LayoutText(
              label: item.value,
              value: value.text(item.key),
              onChanged: (v) => change(item.key, v),
            ),
          ),
        choices('橫幅字體', 'bannerFontFamily', value.text('bannerFontFamily'), {
          '': '跟隨整頁',
          'KleeOne': '日系手寫',
          'NotoSerifTC': '思源宋體',
        }),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('區塊個別配色'),
          children: [
            for (final entry in const <String, (String, int)>{
              'heroFill': ('封面底色', 0xff58452e),
              'heroTextColor': ('封面文字', 0xffffffff),
              'bannerFill': ('橫幅底色', 0xff718064),
              'bannerTextColor': ('橫幅文字', 0xffffffff),
              'featureFill': ('特色卡底色', 0xfff8f2e7),
              'equipmentFill': ('設備橫列底色', 0xffeff0e5),
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: StoreBannerColorField(
                  label: entry.value.$1,
                  argb: value
                      .color(entry.key, Color(entry.value.$2))
                      .toARGB32(),
                  onChanged: (v) => change(entry.key, v),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _LayoutText extends StatefulWidget {
  const _LayoutText({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  @override
  State<_LayoutText> createState() => _LayoutTextState();
}

class _LayoutTextState extends State<_LayoutText> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _LayoutText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: widget.label),
    onChanged: widget.onChanged,
    maxLines: null,
  );
}
