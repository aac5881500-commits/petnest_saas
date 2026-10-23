// 功能：結構以外的圖片、文字與進階外觀設定，沿用平台背景圖庫。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/room_intro_look.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import '../platform_media_asset_picker.dart';

class RoomIntroLookEditor extends StatelessWidget {
  const RoomIntroLookEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.storageId,
    this.showDimensions = true,
    this.showRadius = true,
    this.extra = const [],
  });
  final RoomIntroLook value;
  final ValueChanged<RoomIntroLook> onChanged;
  final String storageId;
  final bool showDimensions;
  final bool showRadius;
  final List<Widget> extra;
  @override
  Widget build(BuildContext context) {
    Widget choices(
      String label,
      String current,
      Map<String, String> options,
      ValueChanged<String> update,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in options.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: current == e.key,
                  onSelected: (_) => update(e.key),
                ),
            ],
          ),
        ],
      ),
    );
    return ExpansionTile(
      key: PageStorageKey<String>(storageId),
      title: const Text('進階外觀'),
      children: [
        ...extra,
        choices('文字大小', value.textSize, const {
          'small': '小',
          'standard': '標準',
          'large': '大',
        }, (v) => onChanged(value.copyWith(textSize: v))),
        choices('文字對齊', value.align, const {
          'start': '靠左',
          'center': '置中',
        }, (v) => onChanged(value.copyWith(align: v))),
        choices('資訊密度', value.density, const {
          'compact': '精簡',
          'standard': '標準',
          'wide': '寬鬆',
        }, (v) => onChanged(value.copyWith(density: v))),
        if (showDimensions)
          SwitchListTile(
            title: const Text('顯示有效尺寸'),
            value: value.showDimensions,
            onChanged: (v) => onChanged(value.copyWith(showDimensions: v)),
          ),
        SwitchListTile(
          title: const Text('卡片框線'),
          value: value.border,
          onChanged: (v) => onChanged(value.copyWith(border: v)),
        ),
        SwitchListTile(
          title: const Text('淡陰影'),
          value: value.shadow,
          onChanged: (v) => onChanged(value.copyWith(shadow: v)),
        ),
        if (showRadius)
          Row(
            children: [
              const Text('卡片圓角'),
              Expanded(
                child: Slider(
                  value: value.radius,
                  min: 0,
                  max: 32,
                  divisions: 8,
                  label: value.radius.round().toString(),
                  onChanged: (v) => onChanged(value.copyWith(radius: v)),
                ),
              ),
            ],
          ),
        choices('背景', value.background, const {
          'theme': '沿用店家主題',
          'color': '純色',
          'library': '平台圖庫',
        }, (v) => onChanged(value.copyWith(background: v))),
        if (value.background == 'color')
          Wrap(
            spacing: 8,
            children: [
              for (final color in const [
                0xfff5f3ef,
                0xffffffff,
                0xffe8edf4,
                0xffe8f1e9,
              ])
                ChoiceChip(
                  label: Container(width: 24, height: 24, color: Color(color)),
                  selected: value.backgroundColor == color,
                  onSelected: (_) =>
                      onChanged(value.copyWith(backgroundColor: color)),
                ),
            ],
          ),
        if (value.background == 'library')
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(value.backgroundAssetId.isEmpty ? '選擇背景圖庫' : '更換背景圖片'),
            onPressed: () async {
              final asset = await showPlatformMediaAssetPicker(
                context: context,
                category: PlatformMediaCategories.appBackground,
                selectedId: value.backgroundAssetId,
                title: '選擇房型介紹背景',
              );
              if (!context.mounted ||
                  asset == null ||
                  !asset.enabled ||
                  asset.category != PlatformMediaCategories.appBackground) {
                return;
              }
              onChanged(value.copyWith(backgroundAssetId: asset.id));
            },
          ),
      ],
    );
  }
}
