// 功能：關於我們照片來源與縮圖，沿用店家環境相簿、平台卡片圖庫與既有上傳。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import '../platform_media_asset_picker.dart';

class AboutMediaView extends StatefulWidget {
  const AboutMediaView({
    super.key,
    required this.media,
    required this.shop,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.empty = const Center(child: Icon(Icons.image_outlined)),
  });
  final AboutMedia media;
  final Map<String, dynamic> shop;
  final BoxFit fit;
  final Alignment alignment;
  final Widget empty;
  @override
  State<AboutMediaView> createState() => _AboutMediaViewState();
}

class _AboutMediaViewState extends State<AboutMediaView> {
  String _id = '';
  Future<PlatformMediaAsset?>? _asset;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant AboutMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind();
  }

  void _bind() {
    final id = widget.media.source == 'platform' ? widget.media.assetId : '';
    if (id == _id) return;
    _id = id;
    _asset = id.isEmpty
        ? null
        : PlatformMediaLibraryService.instance.getEnabledAssetById(id);
  }

  Widget _image(String url) => url.isEmpty
      ? widget.empty
      : Image.network(
          url,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (_, e, s) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        );
  @override
  Widget build(BuildContext context) => widget.media.source == 'platform'
      ? FutureBuilder<PlatformMediaAsset?>(
          future: _asset,
          builder: (_, s) {
            final a = s.data;
            return _image(
              a != null &&
                      a.enabled &&
                      a.category == PlatformMediaCategories.dailyCareCard
                  ? a.imageUrl
                  : '',
            );
          },
        )
      : _image(widget.media.resolveShop(widget.shop));
}

class AboutMediaField extends StatelessWidget {
  const AboutMediaField({
    super.key,
    required this.value,
    required this.shop,
    required this.onChanged,
    this.allowLibrary = true,
    this.allowFirst = true,
    this.onUpload,
  });
  final AboutMedia value;
  final Map<String, dynamic> shop;
  final ValueChanged<AboutMedia> onChanged;
  final bool allowLibrary, allowFirst;
  final Future<AboutMedia?> Function()? onUpload;
  Future<void> _pickShop(BuildContext context) async {
    final photos = {
      ...aboutShopPhotos(shop),
      if (shop['_aboutMediaPhotos'] is List)
        ...(shop['_aboutMediaPhotos'] as List).whereType<String>(),
      if ('${shop['aboutImageUrl'] ?? ''}'.isNotEmpty)
        '${shop['aboutImageUrl']}',
    }.toList();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇店家已上傳照片'),
        content: SizedBox(
          width: 580,
          height: 420,
          child: photos.isEmpty
              ? const Center(child: Text('尚無店家照片，請先上傳。'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => Navigator.pop(context, photos[i]),
                    child: Image.network(
                      photos[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (context.mounted && url != null) {
      onChanged(AboutMedia(source: 'shop', url: url));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '目前來源：${const {'none': '未選擇', 'legacy': '原有關於我們封面', 'shop': '明確選取的店家照片', 'firstGallery': '環境相簿第一張（隨排序更新）', 'platform': '平台卡片圖庫'}[value.source] ?? '未選擇'}',
      ),
      if (value.source != 'none')
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 260,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AboutMediaView(
                  media: value,
                  shop: shop,
                  fit: BoxFit.contain,
                  empty: const Center(child: Text('尚無可用圖片')),
                ),
              ),
            ),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton(
            onPressed: () => _pickShop(context),
            child: const Text('選擇店家照片'),
          ),
          if (onUpload != null)
            OutlinedButton(
              onPressed: () async {
                final image = await onUpload!();
                if (context.mounted && image != null) onChanged(image);
              },
              child: const Text('上傳真實照片'),
            ),
          if (allowFirst)
            TextButton(
              onPressed: () =>
                  onChanged(value.copyWith(source: 'firstGallery')),
              child: const Text('使用環境相簿第一張'),
            ),
          if (allowLibrary)
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('選擇圖庫卡片圖片'),
              onPressed: () async {
                final result = await showModalBottomSheet<PlatformMediaPick>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => PlatformMediaAssetPickerSheet(
                    category: PlatformMediaCategories.dailyCareCard,
                    selectedId: value.assetId,
                    confirmSelection: true,
                    title: '選擇關於我們配圖',
                  ),
                );
                final a = result?.asset;
                if (!context.mounted ||
                    a == null ||
                    !a.enabled ||
                    a.category != PlatformMediaCategories.dailyCareCard) {
                  return;
                }
                onChanged(AboutMedia(source: 'platform', assetId: a.id));
              },
            ),
          if (value.source != 'none')
            TextButton(
              onPressed: () => onChanged(const AboutMedia()),
              child: const Text('移除圖片引用'),
            ),
        ],
      ),
      if (!allowLibrary)
        const Text(
          '人物與證照請使用店主提供的真實照片，不使用圖庫人物。',
          style: TextStyle(fontSize: 12),
        ),
    ],
  );
}
