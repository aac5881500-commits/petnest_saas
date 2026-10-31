// 檔案名稱：lib/features/shop/widgets/environment/environment_gallery_manager.dart
// 功能說明：後台環境照片牆管理區塊

import 'package:flutter/material.dart';

class EnvironmentGalleryManager extends StatelessWidget {
  const EnvironmentGalleryManager({
    super.key,
    required this.images,
    required this.onDelete,
    required this.onUpload,
    this.busy = false,
    this.onMove,
    this.trashImages = const [],
    this.onRestore,
    this.onSetCover,
    this.onEditCaption,
    this.captions = const [],
  });

  final List<String> images;
  final Future<void> Function(int index) onDelete;
  final VoidCallback onUpload;
  final bool busy;
  final void Function(int index, int direction)? onMove;
  final List<String> trashImages;
  final ValueChanged<int>? onRestore, onSetCover, onEditCaption;
  final List<String> captions;

  @override
  Widget build(BuildContext context) {
    final bool canAdd = images.length < 12;
    final int itemCount = images.length + (canAdd ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '建議使用橫式照片，4:3 或 16:9 效果最佳。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const Text(
          '建議尺寸：1600 × 1200 或 1600 × 900。最低建議：1200 × 900。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const Text(
          '單張最大 5 MB，支援 JPG、PNG、WEBP。系統會自動壓縮圖片，建議上傳清晰原圖。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount == 0 ? 1 : itemCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth < 380 ? 2 : 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 4 / 3,
            ),
            itemBuilder: (BuildContext context, int index) {
              final bool isAddTile = index >= images.length;
              if (isAddTile) {
                return _AddTile(enabled: !busy && canAdd, onTap: onUpload);
              }

              final thumb = _GalleryThumb(
                imageUrl: images[index],
                enabled: !busy,
                onDelete: () => onDelete(index),
                onSetCover: onSetCover == null
                    ? null
                    : () => onSetCover!(index),
                onEditCaption: onEditCaption == null
                    ? null
                    : () => onEditCaption!(index),
                onPreview: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: InteractiveViewer(
                            child: Image.network(
                              images[index],
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stack) =>
                                  const Text('照片暫時無法載入'),
                            ),
                          ),
                        ),
                        if (index < captions.length &&
                            captions[index].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(captions[index]),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('關閉'),
                        ),
                      ],
                    ),
                  ),
                ),
                onPrevious: onMove != null && index > 0
                    ? () => onMove!(index, -1)
                    : null,
                onNext: onMove != null && index + 1 < images.length
                    ? () => onMove!(index, 1)
                    : null,
              );
              return DragTarget<int>(
                onWillAcceptWithDetails: (details) =>
                    !busy && onMove != null && details.data != index,
                onAcceptWithDetails: (details) =>
                    onMove!(details.data, index - details.data),
                builder: (context, candidates, rejected) =>
                    LongPressDraggable<int>(
                      data: index,
                      maxSimultaneousDrags: busy || onMove == null ? 0 : 1,
                      feedback: Material(
                        child: SizedBox(width: 120, height: 90, child: thumb),
                      ),
                      childWhenDragging: Opacity(opacity: .3, child: thumb),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: candidates.isEmpty
                              ? null
                              : Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                ),
                        ),
                        child: thumb,
                      ),
                    ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (trashImages.isNotEmpty) ...[
          Text(
            '照片回收區（${trashImages.length}）',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text('回收區照片不顯示在前台；儲存後仍可回來復原，圖片檔案會保留。'),
          for (var index = 0; index < trashImages.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 48,
                height: 36,
                child: Image.network(
                  trashImages[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
              title: Text('已移除照片 ${index + 1}'),
              trailing: TextButton(
                onPressed: busy || !canAdd || onRestore == null
                    ? null
                    : () => onRestore!(index),
                child: const Text('復原'),
              ),
            ),
          if (!canAdd) const Text('相簿已達 12 張，請先移除一張再復原。'),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: busy || images.length >= 12 ? null : onUpload,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(
              images.length >= 12
                  ? '已達 12 張上限'
                  : '上傳環境照片 (${images.length}/12)',
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.imageUrl,
    required this.enabled,
    required this.onDelete,
    required this.onPreview,
    this.onPrevious,
    this.onNext,
    this.onSetCover,
    this.onEditCaption,
  });

  final String imageUrl;
  final bool enabled;
  final VoidCallback onDelete, onPreview;
  final VoidCallback? onPrevious, onNext, onSetCover, onEditCaption;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFFF5EBDD),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Color(0xFFB87535),
                      ),
                    );
                  },
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPreview,
                child: Semantics(label: '放大檢視照片'),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '照片往前移',
                    color: Colors.white,
                    onPressed: enabled ? onPrevious : null,
                    icon: const Icon(Icons.arrow_back, size: 18),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '照片往後移',
                    color: Colors.white,
                    onPressed: enabled ? onNext : null,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (onSetCover != null || onEditCaption != null)
            Positioned(
              top: 0,
              left: 0,
              child: PopupMenuButton<String>(
                tooltip: '照片操作',
                iconColor: Colors.white,
                onSelected: enabled
                    ? (value) {
                        if (value == 'cover') {
                          onSetCover?.call();
                        } else {
                          onEditCaption?.call();
                        }
                      }
                    : null,
                enabled: enabled,
                itemBuilder: (_) => [
                  if (onSetCover != null)
                    const PopupMenuItem(value: 'cover', child: Text('設為封面')),
                  if (onEditCaption != null)
                    const PopupMenuItem(
                      value: 'caption',
                      child: Text('編輯照片說明'),
                    ),
                ],
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: Tooltip(
                message: '移至照片回收區',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onDelete : null,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0E0CC)),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Color(0xFFB87535)),
                SizedBox(height: 4),
                Text(
                  '新增',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6A45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
