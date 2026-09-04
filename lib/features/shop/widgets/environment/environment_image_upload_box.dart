// lib/features/shop/widgets/environment/environment_image_upload_box.dart
// 🖼️ 後台環境介紹單張圖片：即時預覽 + 上傳 / 更換 / 移除

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';

class EnvironmentImageUploadBox extends StatelessWidget {
  const EnvironmentImageUploadBox({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.frame,
    required this.uploading,
    required this.busy,
    required this.onUpload,
    required this.onFrameChanged,
    this.onDelete,
    this.overlayTitle = '',
    this.overlaySubtitle = '',
    this.hint = '',
  });

  final String title;
  final String imageUrl;
  final EnvironmentImageFrameSetting frame;
  final bool uploading;
  final bool busy;
  final VoidCallback onUpload;
  final ValueChanged<EnvironmentImageFrameSetting> onFrameChanged;
  final VoidCallback? onDelete;
  final String overlayTitle;
  final String overlaySubtitle;
  final String hint;

  bool get _hasImage => imageUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A2A1A),
          ),
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF8A6A45),
            ),
          ),
        ],
        const SizedBox(height: 10),
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
                    const ColoredBox(color: Color(0xFFF5EBDD)),
                    if (_hasImage)
                      Image.network(
                        imageUrl,
                        fit: frame.boxFit,
                        alignment: frame.alignment,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  size: 42,
                                  color: Color(0xFFB87535),
                                ),
                              );
                            },
                      )
                    else
                      const Center(
                        child: Icon(
                          Icons.image_rounded,
                          size: 42,
                          color: Color(0xFFB87535),
                        ),
                      ),
                    if (frame.slot == EnvironmentImageSlot.hero)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0D000000), Color(0x8C000000)],
                          ),
                        ),
                      )
                    else
                      ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
                    if (overlayTitle.trim().isNotEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: frame.slot == EnvironmentImageSlot.hero
                            ? 14
                            : null,
                        top: frame.slot == EnvironmentImageSlot.middleBanner
                            ? 0
                            : null,
                        child: frame.slot == EnvironmentImageSlot.middleBanner
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  overlayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.3,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    overlayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      height: 1.25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (overlaySubtitle.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      overlaySubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
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
        const SizedBox(height: 12),
        const Text(
          '圖片高度',
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
                  frame.heightPreset ==
                  EnvironmentImageFrameSetting.heightCompact,
              onSelected: () {
                onFrameChanged(
                  frame.copyWith(
                    heightPreset: EnvironmentImageFrameSetting.heightCompact,
                  ),
                );
              },
            ),
            _chip(
              label: '標準',
              selected:
                  frame.heightPreset ==
                  EnvironmentImageFrameSetting.heightStandard,
              onSelected: () {
                onFrameChanged(
                  frame.copyWith(
                    heightPreset: EnvironmentImageFrameSetting.heightStandard,
                  ),
                );
              },
            ),
            _chip(
              label: '大型',
              selected:
                  frame.heightPreset ==
                  EnvironmentImageFrameSetting.heightLarge,
              onSelected: () {
                onFrameChanged(
                  frame.copyWith(
                    heightPreset: EnvironmentImageFrameSetting.heightLarge,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '圖片顯示方式',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        _fitOption(
          title: '填滿畫面',
          subtitle: '圖片會填滿整個區塊，邊緣可能略微裁切。',
          selected: frame.imageFit == EnvironmentImageFrameSetting.fitFill,
          onTap: () {
            onFrameChanged(
              frame.copyWith(imageFit: EnvironmentImageFrameSetting.fitFill),
            );
          },
        ),
        _fitOption(
          title: '完整顯示',
          subtitle: '完整保留圖片內容，不同比例可能出現留白。',
          selected: frame.imageFit == EnvironmentImageFrameSetting.fitContain,
          onTap: () {
            onFrameChanged(
              frame.copyWith(imageFit: EnvironmentImageFrameSetting.fitContain),
            );
          },
        ),
        if (frame.usesCoverFit) ...[
          const SizedBox(height: 4),
          const Text(
            '圖片位置',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                label: '上方',
                selected:
                    frame.imageAlignment ==
                    EnvironmentImageFrameSetting.alignTop,
                onSelected: () {
                  onFrameChanged(
                    frame.copyWith(
                      imageAlignment: EnvironmentImageFrameSetting.alignTop,
                    ),
                  );
                },
              ),
              _chip(
                label: '置中',
                selected:
                    frame.imageAlignment ==
                    EnvironmentImageFrameSetting.alignCenter,
                onSelected: () {
                  onFrameChanged(
                    frame.copyWith(
                      imageAlignment: EnvironmentImageFrameSetting.alignCenter,
                    ),
                  );
                },
              ),
              _chip(
                label: '下方',
                selected:
                    frame.imageAlignment ==
                    EnvironmentImageFrameSetting.alignBottom,
                onSelected: () {
                  onFrameChanged(
                    frame.copyWith(
                      imageAlignment: EnvironmentImageFrameSetting.alignBottom,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
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
              uploading ? '圖片處理中...' : (_hasImage ? '更換$title' : '上傳$title'),
            ),
          ),
        ),
        if (onDelete != null && _hasImage) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onDelete,
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
