// 檔案：lib/features/shop/widgets/modern_home/environment_home_image_settings.dart
// 功能：環境展示圖片草稿來源與有限寬度縮圖；沿用平台卡片圖庫。
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import '../platform_media_asset_picker.dart';
import 'environment_home_image_resolver.dart';

class EnvironmentHomeImageSettings extends StatelessWidget {
  const EnvironmentHomeImageSettings({
    super.key,
    required this.setting,
    required this.environmentIntro,
    required this.onChanged,
    required this.onPickLegacy,
    this.onManage,
  });
  final HomeEnvironmentSectionSetting setting;
  final Map<String, dynamic> environmentIntro;
  final ValueChanged<HomeEnvironmentSectionSetting> onChanged;
  final VoidCallback onPickLegacy;
  final VoidCallback? onManage;
  static const legacyLabels = {
    'auto': '既有設定：自動選取環境照片',
    'hero': '既有設定：環境封面',
    'gallery': '既有設定：環境相簿手選照片',
    'features': '既有設定：環境特色照片',
  };
  Future<void> _pickLibrary(BuildContext context) async {
    final asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCareCard,
      selectedId: setting.imageAssetId,
      title: '選擇環境展示卡片圖片',
    );
    if (!context.mounted || asset == null) return;
    if (!asset.enabled ||
        asset.category != PlatformMediaCategories.dailyCareCard) {
      return;
    }
    onChanged(setting.copyWith(imageAssetId: asset.id));
  }

  @override
  Widget build(BuildContext context) {
    final simple = setting.layout == HomeEnvironmentLayouts.simpleEntry;
    final options = {
      if (legacyLabels.containsKey(setting.imageSource))
        setting.imageSource: legacyLabels[setting.imageSource]!,
      'galleryFirst': '店家環境照片第一張',
      'platformCard': '圖庫卡片圖片',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text('外觀來源', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (simple)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final choice in const {
                'icon': '原本圖示',
                'platformCard': '圖庫卡片圖片',
              }.entries)
                ChoiceChip(
                  label: Text(choice.value),
                  selected: setting.simpleImageSource == choice.key,
                  onSelected: (_) => onChanged(
                    setting.copyWith(simpleImageSource: choice.key),
                  ),
                ),
            ],
          )
        else
          DropdownButton<String>(
            isExpanded: true,
            value: setting.imageSource,
            items: options.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                onChanged(setting.copyWith(imageSource: value)),
          ),
        if (!simple || setting.usesPlatformImage)
          EnvironmentHomeImageResolver(
            setting: setting,
            environmentIntro: environmentIntro,
            builder: (context, image) {
              final library = setting.usesPlatformImage;
              final first = setting.imageSource == 'galleryFirst';
              final source = library
                  ? '圖庫卡片圖片'
                  : options[setting.imageSource] ?? '店家環境照片';
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('目前來源：$source'),
                  if (image.assetName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(image.assetName),
                    ),
                  if (image.url.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        first
                            ? '尚未設定環境照片，請先到環境介紹管理新增。'
                            : library
                            ? '尚未選取圖片，或素材暫時無法使用。'
                            : '目前沒有可用照片，前台會保留原本入口。',
                      ),
                    ),
                  if (library)
                    OutlinedButton.icon(
                      onPressed: () => _pickLibrary(context),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('選擇圖庫圖片'),
                    )
                  else ...[
                    if (!first)
                      OutlinedButton.icon(
                        onPressed: onPickLegacy,
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('選擇既有環境照片'),
                      ),
                    TextButton(
                      onPressed: onManage,
                      child: const Text('前往環境介紹管理'),
                    ),
                  ],
                ],
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    Widget thumbnail(double width) => SizedBox(
                      width: width,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: image.url.isEmpty
                                  ? const Center(
                                      child: Icon(Icons.image_outlined),
                                    )
                                  : Image.network(
                                      image.url,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, error, stack) =>
                                          const Center(child: Text('圖片暫時無法顯示')),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                    if (constraints.maxWidth >= 520) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          thumbnail(260),
                          const SizedBox(width: 16),
                          Expanded(child: details),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        thumbnail(math.min(280, constraints.maxWidth)),
                        const SizedBox(height: 12),
                        details,
                      ],
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
