// lib/features/shop/widgets/store/store_home_settings_section.dart
// 🛒 後台：商城活動海報清單與輪播

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';

class StoreHomeSettingsDraft {
  StoreHomeSettingsDraft({
    required this.showBanners,
    required this.banners,
    this.bannerAutoPlay = true,
    this.bannerAutoPlaySeconds = 5,
  });

  bool showBanners;
  List<StoreBannerModel> banners;
  bool bannerAutoPlay;
  int bannerAutoPlaySeconds;
}

class StoreHomeSettingsSection extends StatefulWidget {
  const StoreHomeSettingsSection({
    super.key,
    required this.shopId,
    required this.canManage,
    required this.draft,
    required this.onChanged,
  });

  final String shopId;
  final bool canManage;
  final StoreHomeSettingsDraft draft;
  final VoidCallback onChanged;

  @override
  State<StoreHomeSettingsSection> createState() =>
      _StoreHomeSettingsSectionState();
}

class _StoreHomeSettingsSectionState extends State<StoreHomeSettingsSection> {
  void _notify() {
    widget.onChanged();
    setState(() {});
  }

  Future<void> _persistBanners() async {
    await StoreSettingsService.instance.saveBanners(
      shopId: widget.shopId,
      banners: widget.draft.banners,
      showBanners: widget.draft.showBanners,
      bannerAutoPlay: widget.draft.bannerAutoPlay,
      bannerAutoPlaySeconds: widget.draft.bannerAutoPlaySeconds,
    );
  }

  Future<void> _addBanner() async {
    if (widget.draft.banners.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多 5 張活動海報')));
      return;
    }
    try {
      final String id = 'banner_${DateTime.now().millisecondsSinceEpoch}';
      final result = await FixedImagePickFlow.pickCropAndUpload(
        context: context,
        spec: FixedImageSpec.storeBanner,
        title: '裁切商城活動海報',
        shopId: widget.shopId,
        itemId: '$id/p_${DateTime.now().millisecondsSinceEpoch}',
        folder: StoreConstants.bannerImageFolder,
        imageType: 'store_banner',
        idMetadataKey: 'bannerId',
      );
      if (result == null) {
        return;
      }
      final StoreBannerModel created = StoreBannerModel(
        id: id,
        imageUrl: result.imageUrl,
        imageStoragePath: result.imageStoragePath,
        sortOrder: widget.draft.banners.length,
        createdAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      await _openEditor(created, isNew: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StoreBannerModel.imageUserMessage(error))),
      );
    }
  }

  Future<void> _openEditor(
    StoreBannerModel banner, {
    required bool isNew,
  }) async {
    final List<StoreBannerModel>? saved =
        await Navigator.push<List<StoreBannerModel>>(
          context,
          MaterialPageRoute<List<StoreBannerModel>>(
            builder: (_) => PetNestBannerEditorPage(
              shopId: widget.shopId,
              banner: banner,
              existingBanners: List<StoreBannerModel>.from(
                widget.draft.banners,
              ),
              isNew: isNew,
              scope: PetNestBannerScope.store,
            ),
          ),
        );
    if (saved == null) {
      return;
    }
    widget.draft.banners
      ..clear()
      ..addAll(saved);
    _notify();
  }

  Future<void> _deleteBanner(int index) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除海報'),
          content: const Text('確定刪除此商城海報？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    final StoreBannerModel banner = widget.draft.banners[index];
    final List<StoreBannerModel> next = List<StoreBannerModel>.from(
      widget.draft.banners,
    )..removeAt(index);
    for (int i = 0; i < next.length; i++) {
      next[i] = next[i].copyWith(sortOrder: i);
    }
    try {
      await StoreSettingsService.instance.saveBanners(
        shopId: widget.shopId,
        banners: next,
        showBanners: widget.draft.showBanners,
        bannerAutoPlay: widget.draft.bannerAutoPlay,
        bannerAutoPlaySeconds: widget.draft.bannerAutoPlaySeconds,
      );
      await InventoryImageService.instance.tryDeleteImage(
        imageUrl: banner.imageUrl,
        imageStoragePath: banner.imageStoragePath,
      );
      widget.draft.banners
        ..clear()
        ..addAll(next);
      _notify();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗，海報與圖片都未更動：$error')));
    }
  }

  Future<void> _toggleEnabled(int index) async {
    final StoreBannerModel banner = widget.draft.banners[index];
    widget.draft.banners[index] = banner.copyWith(enabled: !banner.enabled);
    _notify();
    try {
      await _persistBanners();
    } catch (error) {
      widget.draft.banners[index] = banner;
      _notify();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$error')));
    }
  }

  Future<void> _moveUp(int index) async {
    if (index <= 0) {
      return;
    }
    final StoreBannerModel current = widget.draft.banners[index];
    final StoreBannerModel prev = widget.draft.banners[index - 1];
    widget.draft.banners[index - 1] = current.copyWith(
      sortOrder: prev.sortOrder,
    );
    widget.draft.banners[index] = prev.copyWith(sortOrder: current.sortOrder);
    _notify();
    try {
      await _persistBanners();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('顯示活動海報'),
          value: widget.draft.showBanners,
          onChanged: widget.canManage
              ? (bool value) async {
                  widget.draft.showBanners = value;
                  _notify();
                  try {
                    await _persistBanners();
                  } catch (_) {}
                }
              : null,
        ),
        Text(
          '最多 5 張。建議 1600 × 800 px（2:1），最低 1200 × 600 px，單張不可超過 5 MB。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自動輪播'),
          value: widget.draft.bannerAutoPlay,
          onChanged: widget.canManage
              ? (bool value) async {
                  widget.draft.bannerAutoPlay = value;
                  _notify();
                  try {
                    await _persistBanners();
                  } catch (_) {}
                }
              : null,
        ),
        if (widget.draft.bannerAutoPlay) ...<Widget>[
          const Text('輪播秒數'),
          Wrap(
            spacing: 8,
            children: <int>[3, 5, 8].map((int seconds) {
              return ChoiceChip(
                label: Text('$seconds 秒'),
                selected: widget.draft.bannerAutoPlaySeconds == seconds,
                onSelected: widget.canManage
                    ? (_) async {
                        widget.draft.bannerAutoPlaySeconds = seconds;
                        _notify();
                        try {
                          await _persistBanners();
                        } catch (_) {}
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        ...widget.draft.banners.asMap().entries.map((
          MapEntry<int, StoreBannerModel> entry,
        ) {
          final StoreBannerModel banner = entry.value;
          final String resolved = banner.listTitle;
          final String title = resolved.isNotEmpty
              ? resolved
              : '海報 ${entry.key + 1}';
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: banner.hasImage
                        ? Image.network(
                            banner.imageUrl,
                            width: 72,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return const SizedBox(
                                width: 72,
                                height: 40,
                                child: Icon(Icons.image_outlined),
                              );
                            },
                          )
                        : const SizedBox(
                            width: 72,
                            height: 40,
                            child: Icon(Icons.image_outlined),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${banner.enabled ? '啟用' : '停用'}　'
                          '排序 ${entry.key + 1}　'
                          '前往：${StoreBannerActionTypes.label(banner.actionType)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (widget.canManage)
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: () {
                                  _openEditor(banner, isNew: false);
                                },
                                child: const Text('編輯'),
                              ),
                              TextButton(
                                onPressed: () => _deleteBanner(entry.key),
                                child: const Text('刪除'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (widget.canManage)
                    Column(
                      children: <Widget>[
                        Switch(
                          value: banner.enabled,
                          onChanged: (_) => _toggleEnabled(entry.key),
                        ),
                        IconButton(
                          tooltip: '往前排序',
                          onPressed: entry.key > 0
                              ? () => _moveUp(entry.key)
                              : null,
                          icon: const Icon(Icons.arrow_upward, size: 18),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }),
        if (widget.canManage)
          TextButton.icon(
            onPressed: widget.draft.banners.length >= 5 ? null : _addBanner,
            icon: const Icon(Icons.add),
            label: const Text('＋ 新增海報'),
          ),
      ],
    );
  }
}
