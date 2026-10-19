import '../../../core/models/shop_house_appearance.dart';
import '../../../core/models/platform_media_asset.dart';
import 'shop_house_media.dart';
// 檔案名稱：lib/features/auth/widgets/shop_entry_panel.dart
// 功能說明：我的店家木質暖心小屋；外框、屋頂、展示窗與營運內容各自獨立。

import 'package:flutter/material.dart';

import 'package:petnest_saas/features/auth/widgets/my_shop_badges.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_meta_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_qr_link_card.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_stat_row.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_scene.dart';

/// 第一套預設：暖木小屋。顏色集中在這裡，之後可整組換成平台外框。
class _WarmWoodPalette {
  const _WarmWoodPalette({
    required this.roof,
    required this.roofEdge,
    required this.wall,
    required this.base,
    required this.plaque,
    required this.glow,
    required this.wallLight,
  });

  final Color roof;
  final Color roofEdge;
  final Color wall;
  final Color base;
  final Color plaque;
  final Color glow;
  final Color wallLight;

  static _WarmWoodPalette of(ColorScheme colors) {
    final bool dark = colors.brightness == Brightness.dark;
    const Color wood = Color(0xFFC4A574);
    const Color woodDeep = Color(0xFF8C6844);
    return _WarmWoodPalette(
      roof: dark ? const Color(0xFF8D6A45) : wood,
      roofEdge: dark ? const Color(0xFF6E5134) : woodDeep,
      wall: dark
          ? Color.alphaBlend(const Color(0xFF3A3128), colors.surface)
          : const Color(0xFFFFFBF6),
      base: dark ? const Color(0xFF6B5340) : const Color(0xFFE4D0B4),
      plaque: dark ? const Color(0xFF4A3B2E) : const Color(0xFFF3E4D0),
      glow: Colors.white.withValues(alpha: dark ? 0.04 : 0.12),
      wallLight: colors.primary.withValues(alpha: dark ? 0.05 : 0.035),
    );
  }
}

class ShopEntryPanel extends StatelessWidget {
  const ShopEntryPanel({
    super.key,
    required this.shopName,
    required this.shopId,
    required this.shopCode,
    required this.businessType,
    required this.city,
    required this.district,
    required this.role,
    required this.coverUrl,
    required this.logoUrl,
    required this.isOpenNow,
    required this.isPublic,
    required this.enabledModules,
    required this.openTime,
    required this.closeTime,
    required this.licenseNumber,
    required this.taxId,
    required this.updatedAt,
    required this.onEnter,
    required this.onEditMedia,
    this.showHero = true,
    this.showDetails = true,
    this.allowPhotoHint = false,
    this.statsFuture,
    this.roofAssetId = '',
    this.houseAppearance = ShopHouseAppearance.empty,
    this.houseAssetsOverride,
    this.fallbackLogoUrl = '',
    this.fallbackCoverUrl = '',
  });

  final String shopName;
  final String shopId;
  final String shopCode;
  final String businessType;
  final String city;
  final String district;
  final String role;
  final String coverUrl;
  final String logoUrl;
  final bool isOpenNow;
  final bool isPublic;
  final List<String> enabledModules;
  final String openTime;
  final String closeTime;
  final String licenseNumber;
  final String taxId;
  final dynamic updatedAt;
  final VoidCallback onEnter;
  final VoidCallback onEditMedia;
  final bool showHero;
  final bool showDetails;
  final bool allowPhotoHint;
  final Future<Map<String, int>>? statsFuture;
  final String roofAssetId;
  final ShopHouseAppearance houseAppearance;
  final List<PlatformMediaAsset>? houseAssetsOverride;
  final String fallbackLogoUrl;
  final String fallbackCoverUrl;

  /// 標準屋頂槽高度。只看房子寬度是否有效，以及桌面／手機。
  /// 這是沒有平台素材時，Flutter 預設屋頂使用的高度。
  static double roofZoneHeight({
    required double availableWidth,
    required bool wide,
  }) {
    return ShopHouseArtwork.warmWood.roofHeight(
      availableWidth.clamp(0, double.infinity),
      wide,
    );
  }

  /// 平台屋頂在 [roofWidth] 下的完整高度。只依原圖比例，不拉寬、不裁切。
  static double platformRoofHeight({
    required double roofWidth,
    required double imageAspectRatio,
  }) {
    if (roofWidth <= 0 || imageAspectRatio <= 0 || !imageAspectRatio.isFinite) {
      return 0;
    }
    return roofWidth / imageAspectRatio;
  }

  /// PageView 需要明確高度。對齊整棟小屋，避免窄螢幕 overflow。
  static double heroHeightFor(double width, {double textScale = 1}) {
    final double scale = textScale < 1 ? 1 : textScale;
    final double extra = scale <= 1 ? 0 : (scale - 1) * 140;
    final wide = width >= 1000;
    return roofZoneHeight(availableWidth: width, wide: wide) * .95 +
        (wide ? 480 : 800) +
        width / 15 +
        (wide ? 40 : 32) +
        extra;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool wide = width >= 1000;
        final Widget house = ShopHouseMediaBuilder(
          appearance:
              houseAppearance.roofAssetId.isEmpty && roofAssetId.isNotEmpty
              ? houseAppearance.copyWith(roofAssetId: roofAssetId)
              : houseAppearance,
          assetsOverride: houseAssetsOverride,
          builder: (media) => ShopHouseCourtyard(
            media: media,
            wide: wide,
            child: ShopHouseScene(
              media: media,
              shopName: shopName,
              wide: wide,
              child: _HouseInterior(
                media: media,
                fallbackLogoUrl: fallbackLogoUrl,
                fallbackCoverUrl: fallbackCoverUrl,
                shopName: shopName,
                shopId: shopId,
                shopCode: shopCode,
                businessType: businessType,
                enabledModules: enabledModules,
                city: city,
                district: district,
                role: role,
                coverUrl: coverUrl,
                logoUrl: logoUrl,
                isOpenNow: isOpenNow,
                isPublic: isPublic,
                wide: wide,
                allowPhotoHint: allowPhotoHint,
                statsFuture: statsFuture,
                onEnter: onEnter,
                onEditMedia: onEditMedia,
              ),
            ),
          ),
        );
        final Widget file = _FileNest(
          child: MyShopMetaInfo(
            enabledModules: enabledModules,
            openTime: openTime,
            closeTime: closeTime,
            isPublic: isPublic,
            licenseNumber: licenseNumber,
            taxId: taxId,
            updatedAt: updatedAt,
            city: city,
            district: district,
            shopId: shopId,
            businessType: businessType,
          ),
        );
        if (!showHero) {
          return file;
        }
        if (!showDetails) {
          return Align(alignment: Alignment.topCenter, child: house);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[house, const SizedBox(height: 16), file],
        );
      },
    );
  }
}

class _FileNest extends StatelessWidget {
  const _FileNest({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? const Color(0xFF342F28)
            : const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC4A574).withValues(alpha: 0.50),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12866A40),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4A574).withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pets_outlined,
                  size: 20,
                  color: Color(0xFF8C6844),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '我的店家小檔案',
                  style: text.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.eco_outlined,
                size: 24,
                color: Color(0xFF9AA783),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HouseInterior extends StatelessWidget {
  const _HouseInterior({
    required this.media,
    required this.fallbackLogoUrl,
    required this.fallbackCoverUrl,
    required this.shopName,
    required this.shopId,
    required this.shopCode,
    required this.businessType,
    required this.enabledModules,
    required this.city,
    required this.district,
    required this.role,
    required this.coverUrl,
    required this.logoUrl,
    required this.isOpenNow,
    required this.isPublic,
    required this.wide,
    required this.allowPhotoHint,
    required this.statsFuture,
    required this.onEnter,
    required this.onEditMedia,
  });

  final ShopHouseMedia media;
  final String fallbackLogoUrl;
  final String fallbackCoverUrl;
  final String shopName;
  final String shopId;
  final String shopCode;
  final String businessType;
  final List<String> enabledModules;
  final String city;
  final String district;
  final String role;
  final String coverUrl;
  final String logoUrl;
  final bool isOpenNow;
  final bool isPublic;
  final bool wide;
  final bool allowPhotoHint;
  final Future<Map<String, int>>? statsFuture;
  final VoidCallback onEnter;
  final VoidCallback onEditMedia;

  @override
  Widget build(BuildContext context) {
    final Widget identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MyShopInfo(
          shopName: shopName,
          city: city,
          district: district,
          nameFontSize: wide ? 35 : 24,
          addressFontSize: wide ? 16 : 14,
        ),
        const SizedBox(height: 10),
        _ShopPlaque(shopId: shopId),
        if (_serviceText.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            '服務項目 · $_serviceText',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: wide ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        MyShopBadges(
          role: role,
          isPublic: isPublic,
          isOpenNow: isOpenNow,
          large: wide,
        ),
      ],
    );
    final Widget story = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        identity,
        SizedBox(height: wide ? 24 : 18),
        Container(
          padding: EdgeInsets.all(wide ? 18 : 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3E352B)
                : const Color(0xFFFFF6E6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFCFB58A).withValues(alpha: .24),
            ),
          ),
          child: _HouseToday(statsFuture: statsFuture, prominent: wide),
        ),
        SizedBox(height: wide ? 22 : 16),
        _ShopActions(shopCode: shopCode, stacked: !wide, onEnter: onEnter),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320;
        final double photoWidth = wide
            ? ((maxWidth - 28) * 0.40).clamp(0, 500).toDouble()
            : maxWidth.clamp(0, 260).toDouble();
        final Widget window = SizedBox(
          width: photoWidth,
          child: ShopHouseDisplayWindow(
            media: media,
            fallbackLogoUrl: fallbackLogoUrl,
            fallbackCoverUrl: fallbackCoverUrl,
            coverUrl: coverUrl,
            logoUrl: logoUrl,
            allowPhotoHint: allowPhotoHint,
            onEditMedia: onEditMedia,
          ),
        );
        if (!wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                children: [
                  Center(child: window),
                  Positioned(
                    left: 0,
                    bottom: 3,
                    width: 38,
                    child: IgnorePointer(
                      child: ShopHouseDecoration(
                        asset: ShopHouseArtwork.warmWood.plants,
                        media: media,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              story,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            window,
            const SizedBox(width: 28),
            Expanded(child: story),
          ],
        );
      },
    );
  }

  String get _serviceText {
    const labels = <String, String>{
      'cat_hotel': '貓咪旅館',
      'dog_hotel': '狗狗旅館',
      'grooming': '寵物美容',
      'hospital': '動物醫院',
      'store': '寵物賣場',
      'daycare': '安親',
    };
    return <String>{
      if (businessType.trim().isNotEmpty) businessType.trim(),
      ...enabledModules
          .where(labels.containsKey)
          .map((module) => labels[module]!),
    }.join('・');
  }
}

class _ShopPlaque extends StatelessWidget {
  const _ShopPlaque({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final _WarmWoodPalette wood = _WarmWoodPalette.of(
      Theme.of(context).colorScheme,
    );
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: wood.plaque,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: wood.roofEdge.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: wood.roofEdge.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.storefront_outlined, size: 14, color: wood.roofEdge),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '店家編號 $shopId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF3E4D0)
                    : const Color(0xFF5C4A38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseToday extends StatelessWidget {
  const _HouseToday({required this.statsFuture, this.prominent = false});

  final Future<Map<String, int>>? statsFuture;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Future<Map<String, int>>? future = statsFuture;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '今天店裡',
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: prominent ? 22 : 18,
          ),
        ),
        const SizedBox(height: 4),
        if (future == null)
          Text(
            '今天的店務還在整理。',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          )
        else
          FutureBuilder<Map<String, int>>(
            future: future,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Map<String, int>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Text(
                      '店務數字暫時無法讀取',
                      style: text.bodyMedium?.copyWith(color: colors.error),
                    );
                  }
                  final bool waiting =
                      snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;
                  if (waiting) {
                    return const SizedBox(height: 36);
                  }
                  final int pending = snapshot.data?['pendingOrders'] ?? 0;
                  final int transfers =
                      snapshot.data?['transferUploadedOrders'] ?? 0;
                  final bool calm = pending + transfers <= 0;
                  final Color accent = calm
                      ? const Color(0xFF3E7A4A)
                      : const Color(0xFFC47A3A);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            calm
                                ? Icons.check_circle_outline
                                : Icons.notifications_none,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shopTodayHeadline(pending, transfers),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: calm ? null : accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        shopTodaySubline(pending, transfers),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
          ),
        const SizedBox(height: 8),
        MyShopStatRow(
          prominent: prominent,
          shopId: 'house',
          statsFuture:
              future ??
              Future<Map<String, int>>.value(const <String, int>{
                'pendingOrders': 0,
                'transferUploadedOrders': 0,
                'memberCount': 0,
              }),
        ),
      ],
    );
  }
}

class _ShopActions extends StatelessWidget {
  const _ShopActions({
    required this.shopCode,
    required this.stacked,
    required this.onEnter,
  });

  final String shopCode;
  final bool stacked;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final _WarmWoodPalette wood = _WarmWoodPalette.of(
      Theme.of(context).colorScheme,
    );
    final Widget doorway = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: wood.plaque,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wood.roofEdge.withValues(alpha: 0.38)),
      ),
      child: FilledButton.icon(
        onPressed: onEnter,
        icon: const Icon(Icons.door_front_door_outlined, size: 18),
        label: const Text('進入我的店'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF57C18),
          foregroundColor: const Color(0xFFFFFBF6),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          doorway,
          const SizedBox(height: 8),
          MyShopQrLinkCard(shopCode: shopCode),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: doorway),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 60,
            child: MyShopQrLinkCard(shopCode: shopCode),
          ),
        ),
      ],
    );
  }
}
