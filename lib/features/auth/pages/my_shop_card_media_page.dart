import '../../../core/models/shop_house_local_assets.dart';
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
import '../widgets/shop_house_mode_selector.dart';

class MyShopCardMediaPage extends StatefulWidget {
  const MyShopCardMediaPage({
    super.key,
    required this.shopId,
    this.coverUrl = '',
    this.logoUrl = '',
    this.houseAppearance,
    this.houseAssetsOverride,
    this.saveHouseAppearance,
  });

  final String shopId;
  final String coverUrl;
  final String logoUrl;
  final Object? houseAppearance;
  @visibleForTesting
  final List<PlatformMediaAsset>? houseAssetsOverride;
  @visibleForTesting
  final Future<void> Function(ShopHouseAppearance)? saveHouseAppearance;

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
  final Map<String, PlatformMediaAsset> _assets = {};
  bool _namesReady = false;
  String _savingPlacement = '';
  bool _savingMode = false;
  late String _modeDraft;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.coverUrl;
    _logoUrl = widget.logoUrl;
    _house = ShopHouseAppearance.fromMap(widget.houseAppearance);
    _modeDraft = _house.mode;
    _resolveHouseNames();
  }

  Future<void> _resolveHouseNames() async {
    final Map<String, String> names = <String, String>{};
    for (final String id in _house.selectedIds.toSet()) {
      final PlatformMediaAsset? asset = widget.houseAssetsOverride != null
          ? widget.houseAssetsOverride!
                .where((asset) => asset.id == id && asset.enabled)
                .firstOrNull
          : await PlatformMediaLibraryService.instance.getEnabledAssetById(
              id,
              refresh: true,
            );
      if (asset != null && asset.name.trim().isNotEmpty) {
        names[id] = asset.name.trim();
        _assets[id] = asset;
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

  Future<void> _changePlacement(
    String placement, {
    bool phone = false,
    bool reset = false,
  }) async {
    if (_savingPlacement.isNotEmpty || _savingMode) {
      return;
    }
    final PlatformMediaPick? picked = reset
        ? const PlatformMediaPick.platformDefault()
        : await showShopHouseAssetPicker(
            context: context,
            placement: placement,
            // 僅轉送測試注入；正式環境為 null，沿用既有 Firebase 選擇器。
            // ignore: invalid_use_of_visible_for_testing_member
            assetsOverride: widget.houseAssetsOverride,
            title: '選擇${ShopHousePlacements.shortLabel(placement)}',
            selectedId: phone
                ? _house.roofPhoneAssetId
                : _house.idFor(placement),
            device: placement == ShopHousePlacements.roof
                ? (phone ? 'phone' : 'desktop')
                : 'any',
          );
    if (picked == null || !mounted) {
      return;
    }
    final String nextId = picked.usePlatformDefault
        ? ''
        : (picked.asset?.id ?? '');
    final ShopHouseAppearance next = phone
        ? _house.copyWith(roofPhoneAssetId: nextId)
        : _house.withPlacement(placement, nextId);
    setState(() {
      _savingPlacement = placement;
    });
    try {
      if (widget.saveHouseAppearance != null) {
        await widget.saveHouseAppearance!(next);
      } else {
        await ShopProfileService.instance.updateShop(
          shopId: widget.shopId,
          data: <String, dynamic>{
            ShopHouseAppearance.fieldName: next.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
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
          _assets[nextId] = picked.asset!;
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

  Future<void> _saveMode() async {
    if (_savingMode || _savingPlacement.isNotEmpty) return;
    final next = _house.copyWith(mode: _modeDraft);
    setState(() => _savingMode = true);
    try {
      if (widget.saveHouseAppearance != null) {
        await widget.saveHouseAppearance!(next);
      } else {
        // 只改模式，不覆蓋先前或同時更新的圖片 ID。
        await ShopProfileService.instance.updateShop(
          shopId: widget.shopId,
          data: {
            '${ShopHouseAppearance.fieldName}.mode': next.mode,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      if (!mounted) return;
      setState(() => _house = next);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('外觀模式已儲存')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('外觀模式儲存失敗，請重試')));
      }
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  String _placementStatus(String placement, {bool phone = false}) {
    final String id = phone ? _house.roofPhoneAssetId : _house.idFor(placement);
    if (id.isEmpty) {
      return ShopHousePlacements.defaultLabel(placement);
    }
    if (!_namesReady) {
      return '讀取中';
    }
    final asset = _assets[id];
    return asset != null &&
            asset.enabled &&
            asset.hasUsableUrl &&
            asset.allowsPlacement(placement)
        ? (_assetNames[id] ?? asset.name)
        : '素材無法使用，顯示 PetNest 預設';
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
              ShopHouseModeSelector(
                mode: _modeDraft,
                saving: _savingMode,
                onChanged: _savingMode || _savingPlacement.isNotEmpty
                    ? null
                    : (mode) => setState(() => _modeDraft = mode),
                onApply:
                    _savingMode ||
                        _savingPlacement.isNotEmpty ||
                        _modeDraft == _house.mode
                    ? null
                    : _saveMode,
              ),
              const SizedBox(height: 24),
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
                statusFor: (placement, phone) =>
                    _placementStatus(placement, phone: phone),
                previewFor: (placement, phone) {
                  final id = phone
                      ? _house.roofPhoneAssetId
                      : _house.idFor(placement);
                  final asset = _assets[id];
                  final local = ShopHouseLocalAsset.defaultPath(placement);
                  Widget fallback() => local == null
                      ? const Icon(Icons.home_outlined)
                      : Image.asset(
                          local,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.home_outlined),
                        );
                  return asset != null &&
                          asset.enabled &&
                          asset.hasUsableUrl &&
                          asset.allowsPlacement(placement)
                      ? Image.network(
                          asset.houseThumbnailUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => fallback(),
                        )
                      : fallback();
                },
                savingPlacement: _savingMode ? 'mode' : _savingPlacement,
                onChange: (placement, phone, reset) =>
                    _changePlacement(placement, phone: phone, reset: reset),
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
    required this.previewFor,
    required this.savingPlacement,
    required this.onChange,
  });

  final String Function(String placement, bool phone) statusFor;
  final Widget Function(String placement, bool phone) previewFor;
  final String savingPlacement;
  final void Function(String placement, bool phone, bool reset) onChange;

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
          for (final (placement, phone) in [
            for (final placement in ShopHousePlacements.known) ...[
              (placement, false),
              if (placement == ShopHousePlacements.roof) (placement, true),
            ],
          ]) ...<Widget>[
            const Divider(height: 16),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 52,
                  height: 52,
                  child: previewFor(placement, phone),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${ShopHousePlacements.shortLabel(placement)}${placement == ShopHousePlacements.roof ? (phone ? '（手機）' : '（桌機）') : ''}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '目前：${statusFor(placement, phone)}',
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
                      ? () => onChange(placement, phone, false)
                      : null,
                  child: Text(savingPlacement == placement ? '儲存中' : '更換'),
                ),
                IconButton(
                  tooltip: '恢復預設',
                  icon: const Icon(Icons.restart_alt),
                  onPressed: savingPlacement.isEmpty
                      ? () => onChange(placement, phone, true)
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
