// 檔案名稱：lib/features/shop/widgets/platform_media_asset_picker.dart
// 功能說明：店主從平台圖庫選取已啟用素材，不提供上傳。

import 'package:flutter/material.dart';

import '../../../core/models/platform_media_asset.dart';
import '../../../core/services/platform_media_library_service.dart';

Future<PlatformMediaAsset?> showPlatformMediaAssetPicker({
  required BuildContext context,
  required String category,
  String? selectedId,
}) {
  return showModalBottomSheet<PlatformMediaAsset>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _PlatformMediaAssetPickerSheet(
        category: category,
        selectedId: selectedId ?? '',
      );
    },
  );
}

class _PlatformMediaAssetPickerSheet extends StatelessWidget {
  const _PlatformMediaAssetPickerSheet({
    required this.category,
    required this.selectedId,
  });

  final String category;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    PlatformMediaCategories.label(category),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '關閉',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PlatformMediaAsset>>(
              stream: PlatformMediaLibraryService.instance.streamEnabledAssets(
                category,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<PlatformMediaAsset>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('圖庫讀取失敗'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<PlatformMediaAsset> assets =
                        snapshot.data ?? const <PlatformMediaAsset>[];
                    if (assets.isEmpty) {
                      return const Center(child: Text('目前沒有可選用的圖庫圖片'));
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: assets.length,
                      itemBuilder: (BuildContext context, int index) {
                        final PlatformMediaAsset asset = assets[index];
                        final bool selected = asset.id == selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, asset),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF1565C0)
                                    : Colors.black12,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(11),
                                    ),
                                    child: Image.network(
                                      asset.thumbnailUrl.isEmpty
                                          ? asset.imageUrl
                                          : asset.thumbnailUrl,
                                      width: double.infinity,
                                      fit:
                                          category ==
                                              PlatformMediaCategories
                                                  .dailyCareIcon
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return const ColoredBox(
                                          color: Color(0xFFF3F4F6),
                                          child: Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    asset.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}
