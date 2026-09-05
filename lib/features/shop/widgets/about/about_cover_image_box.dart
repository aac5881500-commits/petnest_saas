// 檔案名稱：lib/features/shop/widgets/about/about_cover_image_box.dart
// 功能說明：後台關於我們封面：即時預覽 + 高度 / 顯示方式 + 上傳 / 更換 / 移除

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_cover_backdrop.dart';

class AboutCoverImageBox extends StatelessWidget {
  const AboutCoverImageBox({
    super.key,
    required this.imageUrl,
    required this.frame,
    required this.uploading,
    required this.busy,
    required this.onUpload,
    required this.onFrameChanged,
    this.onDelete,
    this.overlayTitle = '',
    this.overlaySubtitle = '',
  });

  final String imageUrl;
  final AboutCoverFrameSetting frame;
  final bool uploading;
  final bool busy;
  final VoidCallback onUpload;
  final ValueChanged<AboutCoverFrameSetting> onFrameChanged;
  final VoidCallback? onDelete;
  final String overlayTitle;
  final String overlaySubtitle;

  bool get _hasShopImage => imageUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FixedImageSpec.aboutCover.hintText,
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF8A6A45)),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double height = frame.heightForWidth(constraints.maxWidth);
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF2A1B12)),
                    AboutCoverBackdrop(shopImageUrl: imageUrl, frame: frame),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xB82A1B12),
                            Color(0x572A1B12),
                            Color(0x002A1B12),
                          ],
                        ),
                      ),
                    ),
                    if (overlayTitle.trim().isNotEmpty)
                      Positioned(
                        left: 14,
                        right: 14,
                        top: height <= 240 ? 16 : 22,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              overlayTitle,
                              maxLines: height <= 240 ? 2 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: height <= 240 ? 16 : 18,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (overlaySubtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                overlaySubtitle,
                                maxLines: height <= 240 ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (!_hasShopImage) ...[
          const SizedBox(height: 6),
          const Text(
            '目前使用系統預設封面\n上傳自己的圖片後將自動取代。',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF8A6A45),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          '封面顯示大小',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              label: '精簡',
              selected:
                  frame.heightPreset == AboutCoverFrameSetting.heightCompact,
              onSelected: () {
                onFrameChanged(
                  frame.copyWith(
                    heightPreset: AboutCoverFrameSetting.heightCompact,
                  ),
                );
              },
            ),
            _chip(
              label: '標準',
              selected:
                  frame.heightPreset == AboutCoverFrameSetting.heightStandard,
              onSelected: () {
                onFrameChanged(
                  frame.copyWith(
                    heightPreset: AboutCoverFrameSetting.heightStandard,
                  ),
                );
              },
            ),
            _chip(
              label: '大型',
              selected:
                  frame.heightPreset == AboutCoverFrameSetting.heightLarge,
              onSelected: () {
                onFrameChanged(
                  frame.copyWith(
                    heightPreset: AboutCoverFrameSetting.heightLarge,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '圖片顯示方式',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        _fitOption(
          title: '填滿畫面',
          subtitle: '圖片會填滿封面區域，邊緣可能略微裁切。',
          selected: frame.imageFit == AboutCoverFrameSetting.fitFill,
          onTap: () {
            onFrameChanged(
              frame.copyWith(imageFit: AboutCoverFrameSetting.fitFill),
            );
          },
        ),
        _fitOption(
          title: '完整顯示',
          subtitle: '完整保留圖片內容，不同比例時可能出現留白。',
          selected: frame.imageFit == AboutCoverFrameSetting.fitContain,
          onTap: () {
            onFrameChanged(
              frame.copyWith(imageFit: AboutCoverFrameSetting.fitContain),
            );
          },
        ),
        if (frame.usesCoverFit) ...[
          const Text(
            '圖片位置',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                label: '上方',
                selected:
                    frame.imageAlignment == AboutCoverFrameSetting.alignTop,
                onSelected: () {
                  onFrameChanged(
                    frame.copyWith(
                      imageAlignment: AboutCoverFrameSetting.alignTop,
                    ),
                  );
                },
              ),
              _chip(
                label: '置中',
                selected:
                    frame.imageAlignment == AboutCoverFrameSetting.alignCenter,
                onSelected: () {
                  onFrameChanged(
                    frame.copyWith(
                      imageAlignment: AboutCoverFrameSetting.alignCenter,
                    ),
                  );
                },
              ),
              _chip(
                label: '下方',
                selected:
                    frame.imageAlignment == AboutCoverFrameSetting.alignBottom,
                onSelected: () {
                  onFrameChanged(
                    frame.copyWith(
                      imageAlignment: AboutCoverFrameSetting.alignBottom,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded),
            label: Text(
              uploading ? '圖片處理中...' : (_hasShopImage ? '更換封面圖' : '上傳自己的封面圖'),
            ),
          ),
        ),
        if (onDelete != null && _hasShopImage) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onDelete,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC45C4A),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('移除圖片'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _fitOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: const Color(0xFFB87535),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A6A45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: busy
          ? null
          : (bool value) {
              if (value) {
                onSelected();
              }
            },
    );
  }
}
