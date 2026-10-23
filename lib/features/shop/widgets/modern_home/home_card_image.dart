// 功能：七個首頁設定分頁共用卡片圖庫、有限寬縮圖與素材解析。
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_card_image_setting.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import '../platform_media_asset_picker.dart';
import 'environment_home_image_resolver.dart';

class HomeCardImage extends StatelessWidget {
  const HomeCardImage({
    super.key,
    required this.setting,
    required this.builder,
    this.enabled = true,
  });
  final HomeCardImageSetting setting;
  final bool enabled;
  final Widget Function(BuildContext, EnvironmentHomeImage) builder;
  @override
  Widget build(BuildContext context) => EnvironmentHomeImageResolver(
    setting: HomeEnvironmentSectionSetting(
      layout: HomeEnvironmentLayouts.simpleEntry,
      simpleImageSource: enabled && setting.usesLibrary
          ? 'platformCard'
          : 'icon',
      imageAssetId: setting.assetId,
    ),
    environmentIntro: const {},
    builder: builder,
  );
}

class HomeCardImageSettings extends StatelessWidget {
  const HomeCardImageSettings({
    super.key,
    required this.setting,
    required this.onChanged,
    this.showSource = true,
    this.fallbackUrl = '',
    this.sourceLabel = '原本圖示',
    this.onManage,
  });
  final HomeCardImageSetting setting;
  final ValueChanged<HomeCardImageSetting> onChanged;
  final bool showSource;
  final String fallbackUrl, sourceLabel;
  final VoidCallback? onManage;
  Future<void> _pick(BuildContext context) async {
    final asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCareCard,
      selectedId: setting.assetId,
      title: '選擇入口卡片圖片',
    );
    if (!context.mounted ||
        asset == null ||
        !asset.enabled ||
        asset.category != PlatformMediaCategories.dailyCareCard) {
      return;
    }
    onChanged(setting.copyWith(assetId: asset.id));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showSource)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final entry in const {
              'icon': '原本圖示',
              'platformCard': '圖庫卡片圖片',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: setting.source == entry.key,
                onSelected: (_) =>
                    onChanged(setting.copyWith(source: entry.key)),
              ),
          ],
        ),
      if (setting.usesLibrary || !showSource)
        HomeCardImage(
          setting: setting,
          builder: (context, image) {
            final url = setting.usesLibrary ? image.url : fallbackUrl;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('目前來源：${setting.usesLibrary ? '圖庫卡片圖片' : sourceLabel}'),
                if (setting.usesLibrary && image.assetName.isNotEmpty)
                  Text(image.assetName),
                if (url.isEmpty)
                  Text(
                    setting.usesLibrary ? '尚未選圖或素材暫時無法使用。' : '尚無可用照片，前台保留乾淨入口。',
                  ),
                if (setting.usesLibrary)
                  OutlinedButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('選擇圖庫圖片'),
                  ),
                if (!setting.usesLibrary && onManage != null)
                  TextButton(onPressed: onManage, child: const Text('前往內容管理')),
              ],
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final thumb = SizedBox(
                    width: math.min(260, constraints.maxWidth),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        padding: const EdgeInsets.all(6),
                        clipBehavior: Clip.antiAlias,
                        child: url.isEmpty
                            ? const Center(child: Icon(Icons.image_outlined))
                            : Image.network(
                                url,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                errorBuilder: (_, error, stack) =>
                                    const Center(child: Text('圖片暫時無法顯示')),
                              ),
                      ),
                    ),
                  );
                  return constraints.maxWidth >= 540
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            thumb,
                            const SizedBox(width: 16),
                            Expanded(child: details),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            thumb,
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
