// 檔案名稱：lib/features/auth/pages/my_shop_card_media_page.dart
// 功能說明：管理「我的店家」小屋的門面照片與 Logo。
// 🖼️ 我的店家外觀
// 注意：欄位仍是 platformHomeCoverUrl / platformHomeLogoUrl，不影響店家前台封面。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/models/shop_house_appearance.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import 'package:petnest_saas/core/services/shop_card_media_service.dart';
import 'package:petnest_saas/core/services/shop_profile_service.dart';
import 'package:petnest_saas/features/shop/widgets/platform_media_asset_picker.dart';

class MyShopCardMediaPage extends StatefulWidget {
  const MyShopCardMediaPage({
    super.key,
    required this.shopId,
    this.coverUrl = '',
    this.logoUrl = '',
    this.houseAppearance,
  });

  final String shopId;
  final String coverUrl;
  final String logoUrl;
  final Object? houseAppearance;

  @override
  State<MyShopCardMediaPage> createState() => _MyShopCardMediaPageState();
}

class _MyShopCardMediaPageState extends State<MyShopCardMediaPage> {
  bool _uploadingCover = false;
  bool _uploadingLogo = false;
  late String _coverUrl;
  late String _logoUrl;
  late ShopHouseAppearance _house;
  final Map<String, String> _assetNames = <String, String>{};
  bool _namesReady = false;
  String _savingPlacement = '';

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.coverUrl;
    _logoUrl = widget.logoUrl;
    _house = ShopHouseAppearance.fromMap(widget.houseAppearance);
    _resolveHouseNames();
  }

  Future<void> _resolveHouseNames() async {
    final Map<String, String> names = <String, String>{};
    for (final String id in _house.selectedIds.toSet()) {
      final PlatformMediaAsset? asset = await PlatformMediaLibraryService
          .instance
          .getEnabledAssetById(id);
      if (asset != null && asset.name.trim().isNotEmpty) {
        names[id] = asset.name.trim();
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _assetNames
        ..clear()
        ..addAll(names);
      _namesReady = true;
    });
  }

  Future<void> _changePlacement(String placement) async {
    if (_savingPlacement.isNotEmpty) {
      return;
    }
    final PlatformMediaPick? picked = await showShopHouseAssetPicker(
      context: context,
      placement: placement,
      title: '選擇${ShopHousePlacements.shortLabel(placement)}',
      selectedId: _house.idFor(placement),
    );
    if (picked == null || !mounted) {
      return;
    }
    final String nextId = picked.usePlatformDefault
        ? ''
        : (picked.asset?.id ?? '');
    final ShopHouseAppearance next = _house.withPlacement(placement, nextId);
    setState(() {
      _savingPlacement = placement;
    });
    try {
      await ShopProfileService.instance.updateShop(
        shopId: widget.shopId,
        data: <String, dynamic>{
          ShopHouseAppearance.fieldName: next.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _house = next;
        if (nextId.isEmpty) {
          return;
        }
        final String name = picked.asset?.name.trim() ?? '';
        if (name.isNotEmpty) {
          _assetNames[nextId] = name;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('小屋外觀已更新')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _savingPlacement = '';
        });
      }
    }
  }

  String _placementStatus(String placement) {
    final String id = _house.idFor(placement);
    if (id.isEmpty) {
      return ShopHousePlacements.defaultLabel(placement);
    }
    if (!_namesReady) {
      return '讀取中';
    }
    return _assetNames[id] ?? ShopHousePlacements.defaultLabel(placement);
  }

  Future<void> _pickAndUploadCover() async {
    await _pickAndUpload(isCover: true);
  }

  Future<void> _pickAndUploadLogo() async {
    await _pickAndUpload(isCover: false);
  }

  Future<void> _pickAndUpload({required bool isCover}) async {
    try {
      final picker = ImagePicker();

      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isCover ? 1600 : 600,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes > ShopCardMediaService.maxImageBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('圖片不可超過 5MB')));
        return;
      }

      setState(() {
        if (isCover) {
          _uploadingCover = true;
        } else {
          _uploadingLogo = true;
        }
      });

      final String url;
      if (isCover) {
        url = await ShopCardMediaService.instance.uploadPlatformHomeCover(
          shopId: widget.shopId,
          bytes: bytes,
        );
      } else {
        url = await ShopCardMediaService.instance.uploadPlatformHomeLogo(
          shopId: widget.shopId,
          bytes: bytes,
        );
      }

      if (!mounted) return;

      setState(() {
        if (isCover) {
          _coverUrl = url;
        } else {
          _logoUrl = url;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isCover ? '店家門面照片已更新' : '店家 Logo 已更新')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          if (isCover) {
            _uploadingCover = false;
          } else {
            _uploadingLogo = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasCover = _coverUrl.trim().isNotEmpty;
    final bool hasLogo = _logoUrl.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('我的店家外觀')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: <Widget>[
              Text(
                '管理這間店在 PetNest 中顯示的照片與 Logo',
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _AppearanceBlock(
                title: '店家門面照片',
                description: '這張照片會顯示在「我的店家」小屋中，代表這間店的主要門面。',
                usage: '我的店家 ＞ PetNest 小屋',
                hint: '建議使用明亮、清楚的店內環境或店家門面照片。',
                imageUrl: _coverUrl,
                widePreview: true,
                uploading: _uploadingCover,
                actionLabel: hasCover ? '更換照片' : '上傳店家照片',
                showAddIcon: !hasCover,
                onPressed: _pickAndUploadCover,
              ),
              const SizedBox(height: 16),
              _AppearanceBlock(
                title: '店家 Logo',
                description: '用於顯示店家的品牌識別。',
                usage: 'PetNest 店家識別',
                imageUrl: _logoUrl,
                widePreview: false,
                uploading: _uploadingLogo,
                actionLabel: hasLogo ? '更換 Logo' : '上傳 Logo',
                showAddIcon: !hasLogo,
                onPressed: _pickAndUploadLogo,
              ),
              const SizedBox(height: 12),
              Text(
                '單張不可超過 5MB。上傳新圖後，系統會自動刪除舊圖並更新資料。',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _HouseAppearanceSection(
                statusFor: _placementStatus,
                savingPlacement: _savingPlacement,
                onChange: _changePlacement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceBlock extends StatelessWidget {
  const _AppearanceBlock({
    required this.title,
    required this.description,
    required this.usage,
    required this.imageUrl,
    required this.widePreview,
    required this.uploading,
    required this.actionLabel,
    required this.showAddIcon,
    required this.onPressed,
    this.hint,
  });

  final String title;
  final String description;
  final String usage;
  final String? hint;
  final String imageUrl;
  final bool widePreview;
  final bool uploading;
  final String actionLabel;
  final bool showAddIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget preview = _ImagePreview(
      imageUrl: imageUrl,
      wide: widePreview,
      emptyIcon: widePreview
          ? Icons.storefront_outlined
          : Icons.account_circle_outlined,
    );
    final Widget explanation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(description, style: text.bodyMedium),
        const SizedBox(height: 8),
        Text(
          '使用位置',
          style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        Text(
          usage,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
    final Widget action = FilledButton.icon(
      onPressed: uploading ? null : onPressed,
      icon: uploading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(showAddIcon ? Icons.add : Icons.photo_outlined, size: 18),
      label: Text(actionLabel),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool sideBySide = widePreview && constraints.maxWidth >= 640;
          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                explanation,
                const SizedBox(height: 12),
                preview,
                const SizedBox(height: 12),
                action,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 5, child: preview),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    explanation,
                    const SizedBox(height: 12),
                    action,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.imageUrl,
    required this.wide,
    required this.emptyIcon,
  });

  final String imageUrl;
  final bool wide;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool hasImage = imageUrl.trim().isNotEmpty;
    final double height = wide ? 180 : 96;
    final double width = wide ? double.infinity : 96;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: height,
        color: colors.surfaceContainerHighest,
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(emptyIcon, color: colors.onSurfaceVariant),
              )
            : Icon(emptyIcon, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _HouseAppearanceSection extends StatelessWidget {
  const _HouseAppearanceSection({
    required this.statusFor,
    required this.savingPlacement,
    required this.onChange,
  });

  final String Function(String placement) statusFor;
  final String savingPlacement;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '小屋外觀',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '打造屬於這間店的小天地',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final String placement in ShopHousePlacements.known) ...<Widget>[
            const Divider(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ShopHousePlacements.shortLabel(placement),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '目前：${statusFor(placement)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: savingPlacement.isEmpty
                      ? () => onChange(placement)
                      : null,
                  child: Text(savingPlacement == placement ? '儲存中' : '更換'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
