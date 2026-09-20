// 檔案名稱：lib/core/models/daily_care_journal_appearance.dart
// 功能說明：整頁／卡片外觀解析。客戶端、店主預覽共用，圖庫 ID 不存在時安全 fallback。

import 'package:flutter/material.dart';

import 'daily_care_journal_layout.dart';
import 'daily_care_setting_model.dart';
import 'platform_media_asset.dart';

class DailyCareResolvedPageLook {
  const DailyCareResolvedPageLook({
    required this.source,
    this.networkUrl = '',
    this.asset,
  });

  /// system / color / library / legacyImage
  final String source;
  final String networkUrl;
  final PlatformMediaAsset? asset;

  bool get hasImage {
    if (asset != null && asset!.imageUrl.trim().isNotEmpty) {
      return true;
    }
    return networkUrl.trim().isNotEmpty;
  }

  String get resolvedUrl {
    final String libraryUrl = asset?.imageUrl.trim() ?? '';
    if (libraryUrl.isNotEmpty) {
      return libraryUrl;
    }
    return networkUrl.trim();
  }
}

class DailyCareResolvedCardLook {
  const DailyCareResolvedCardLook({
    required this.mode,
    required this.fill,
    this.networkUrl = '',
    this.presetKey = '',
    this.asset,
  });

  /// solid / transparent / frosted / library / preset / image
  final String mode;
  final Color fill;
  final String networkUrl;
  final String presetKey;
  final PlatformMediaAsset? asset;

  bool get isTransparent =>
      mode == DailyCareJournalCardStyle.surfaceTransparent;
  bool get isFrosted => mode == DailyCareJournalCardStyle.surfaceFrosted;
  bool get usesLibraryImage =>
      mode == DailyCareJournalCardStyle.surfaceLibrary &&
      (asset?.imageUrl.trim().isNotEmpty ?? false);
  bool get usesLegacyNetworkImage =>
      mode == DailyCareJournalTheme.cardTypeImage &&
      networkUrl.trim().isNotEmpty;
  bool get usesPreset =>
      mode == DailyCareJournalTheme.cardTypePreset &&
      presetKey.trim().isNotEmpty;

  bool get hasImageVisual =>
      usesLibraryImage || usesLegacyNetworkImage || usesPreset;

  bool get needsPhotoTextVeil => usesLibraryImage || usesLegacyNetworkImage;

  String get resolvedUrl {
    final String libraryUrl = asset?.imageUrl.trim() ?? '';
    if (libraryUrl.isNotEmpty) {
      return libraryUrl;
    }
    return networkUrl.trim();
  }
}

class DailyCareJournalAppearance {
  DailyCareJournalAppearance._();

  static const String pageLegacyImage = 'legacyImage';

  static const double transparentWash = 0.28;
  static const double frostedWash = 0.40;
  static const double libraryPhotoWashNone = 0.18;
  static const double libraryPhotoWashLight = 0.32;
  static const double libraryPhotoWashHeavy = 0.56;
  static const double libraryTextVeilNone = 0.56;
  static const double libraryTextVeilLight = 0.52;

  /// 霧化一律嘗試 BackdropFilter（含 Web），不因 kIsWeb 預先關閉。
  static bool shouldApplyFrostedBackdrop(DailyCareResolvedCardLook look) {
    return look.isFrosted;
  }

  static double cardWashOpacity({
    required DailyCareResolvedCardLook look,
    required DailyCareSettingModel setting,
    bool longText = false,
  }) {
    if (look.isTransparent) {
      return transparentWash;
    }
    if (look.isFrosted) {
      return frostedWash;
    }
    if (look.usesLibraryImage || look.usesLegacyNetworkImage) {
      return switch (setting.cardBackgroundImageFade) {
        DailyCareJournalTheme.fadeNone => libraryPhotoWashNone,
        DailyCareJournalTheme.fadeHeavy => libraryPhotoWashHeavy,
        _ => libraryPhotoWashLight,
      };
    }
    if (look.hasImageVisual) {
      return setting.resolvedCardOverlayOpacity(longText: longText);
    }
    return 0;
  }

  /// 圖庫／舊圖片的文字區保護層；原圖模式不全卡蓋白。
  static double textReadabilityVeilOpacity({
    required DailyCareResolvedCardLook look,
    required DailyCareSettingModel setting,
  }) {
    if (!look.needsPhotoTextVeil) {
      return 0;
    }
    return switch (setting.cardBackgroundImageFade) {
      DailyCareJournalTheme.fadeHeavy => 0,
      DailyCareJournalTheme.fadeNone => libraryTextVeilNone,
      _ => libraryTextVeilLight,
    };
  }

  static DailyCareResolvedPageLook pageLook(
    DailyCareSettingModel setting, {
    PlatformMediaAsset? Function(String id)? assetLookup,
  }) {
    final String source = setting.resolvedPageBackgroundSource;
    if (source == DailyCareJournalTheme.pageSourceLibrary) {
      final String id = setting.pageBackgroundAssetId.trim();
      final PlatformMediaAsset? asset = id.isEmpty
          ? null
          : assetLookup?.call(id);
      if (asset != null && asset.enabled && asset.imageUrl.trim().isNotEmpty) {
        return DailyCareResolvedPageLook(
          source: DailyCareJournalTheme.pageSourceLibrary,
          asset: asset,
        );
      }
      return DailyCareResolvedPageLook(
        source: DailyCareJournalTheme.pageSourceSystem,
      );
    }
    if (setting.backgroundType == DailyCareJournalTheme.typeImage &&
        setting.backgroundImageUrl.trim().isNotEmpty) {
      return DailyCareResolvedPageLook(
        source: pageLegacyImage,
        networkUrl: setting.backgroundImageUrl,
      );
    }
    if (source == DailyCareJournalTheme.pageSourceColor ||
        setting.backgroundType == DailyCareJournalTheme.typeColor) {
      return const DailyCareResolvedPageLook(
        source: DailyCareJournalTheme.pageSourceColor,
      );
    }
    return const DailyCareResolvedPageLook(
      source: DailyCareJournalTheme.pageSourceSystem,
    );
  }

  static DailyCareResolvedCardLook cardLook(
    DailyCareSettingModel setting,
    DailyCareJournalCardLayout layout, {
    required Color fill,
    PlatformMediaAsset? Function(String id)? assetLookup,
  }) {
    final String mode = layout.resolvedSurfaceMode;
    if (mode == DailyCareJournalCardStyle.surfaceFollow) {
      return _defaultLook(setting, fill: fill, assetLookup: assetLookup);
    }
    return _lookForMode(
      setting,
      mode: mode,
      fill: fill,
      assetId: layout.backgroundAssetId,
      presetKey: layout.backgroundPreset,
      assetLookup: assetLookup,
    );
  }

  static DailyCareResolvedCardLook defaultLook(
    DailyCareSettingModel setting, {
    required Color fill,
    PlatformMediaAsset? Function(String id)? assetLookup,
  }) {
    return _defaultLook(setting, fill: fill, assetLookup: assetLookup);
  }

  static DailyCareResolvedCardLook _defaultLook(
    DailyCareSettingModel setting, {
    required Color fill,
    PlatformMediaAsset? Function(String id)? assetLookup,
  }) {
    final String mode = setting.resolvedCardDefaultSurfaceMode;
    return _lookForMode(
      setting,
      mode: mode,
      fill: fill,
      assetId: setting.cardDefaultBackgroundAssetId,
      presetKey: setting.cardBackgroundPreset,
      assetLookup: assetLookup,
    );
  }

  /// 標題小圖示：須為啟用中的 dailyCareIcon；否則回空字串，由 UI 改用內建 SVG。
  static String titleIconUrl(
    DailyCareJournalCardLayout layout, {
    PlatformMediaAsset? Function(String id)? assetLookup,
  }) {
    final String id = layout.iconAssetId.trim();
    if (id.isEmpty) {
      return '';
    }
    final PlatformMediaAsset? asset = assetLookup?.call(id);
    if (asset == null ||
        !asset.enabled ||
        asset.category != PlatformMediaCategories.dailyCareIcon) {
      return '';
    }
    final String imageUrl = asset.imageUrl.trim();
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }
    return asset.thumbnailUrl.trim();
  }

  static DailyCareResolvedCardLook _lookForMode(
    DailyCareSettingModel setting, {
    required String mode,
    required Color fill,
    required String assetId,
    required String presetKey,
    PlatformMediaAsset? Function(String id)? assetLookup,
  }) {
    if (mode == DailyCareJournalCardStyle.surfaceTransparent) {
      return DailyCareResolvedCardLook(
        mode: DailyCareJournalCardStyle.surfaceTransparent,
        fill: fill,
      );
    }
    if (mode == DailyCareJournalCardStyle.surfaceFrosted) {
      return DailyCareResolvedCardLook(
        mode: DailyCareJournalCardStyle.surfaceFrosted,
        fill: fill,
      );
    }
    if (mode == DailyCareJournalCardStyle.surfaceLibrary) {
      final String id = assetId.trim();
      final PlatformMediaAsset? asset = id.isEmpty
          ? null
          : assetLookup?.call(id);
      if (asset != null && asset.enabled && asset.imageUrl.trim().isNotEmpty) {
        return DailyCareResolvedCardLook(
          mode: DailyCareJournalCardStyle.surfaceLibrary,
          fill: fill,
          asset: asset,
        );
      }
      return DailyCareResolvedCardLook(
        mode: DailyCareJournalCardStyle.surfaceSolid,
        fill: fill,
      );
    }
    if (mode == DailyCareJournalTheme.cardTypeImage &&
        setting.cardBackgroundImageUrl.trim().isNotEmpty) {
      return DailyCareResolvedCardLook(
        mode: DailyCareJournalTheme.cardTypeImage,
        fill: fill,
        networkUrl: setting.cardBackgroundImageUrl,
      );
    }
    if (mode == DailyCareJournalTheme.cardTypePreset) {
      final String key = presetKey.trim().isEmpty
          ? setting.cardBackgroundPreset
          : presetKey;
      if (key.isNotEmpty && key != DailyCareJournalTheme.cardPresetNone) {
        return DailyCareResolvedCardLook(
          mode: DailyCareJournalTheme.cardTypePreset,
          fill: fill,
          presetKey: key,
        );
      }
    }
    return DailyCareResolvedCardLook(
      mode: DailyCareJournalCardStyle.surfaceSolid,
      fill: fill,
    );
  }
}
