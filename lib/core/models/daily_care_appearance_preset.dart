import 'dart:convert';
import 'package:flutter/material.dart';
import 'daily_care_journal_layout.dart';
import 'daily_care_setting_model.dart';

/// A preset composes existing appearance fields only. No rule/content migration.
class DailyCareAppearancePreset {
  const DailyCareAppearancePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.pageColor,
    required this.tint,
    required this.colors,
    this.fullCards = const [],
    this.radius = 16,
    this.padding = 12,
    this.gap = 12,
    this.border = true,
  });
  final String id, name, description, pageColor;
  final Color tint;
  final List<String> colors, fullCards;
  final double radius, padding, gap;
  final bool border;

  DailyCareSettingModel apply(DailyCareSettingModel current) {
    final cards = current.resolvedJournalCards;
    return current.copyWith(
      cardRadius: radius,
      cardPadding: padding,
      cardGap: gap,
      showCardBorder: border,
      backgroundType: DailyCareJournalTheme.typeColor,
      backgroundColorKey: pageColor,
      pageBackgroundSource: DailyCareJournalTheme.pageSourceColor,
      pageBackgroundAssetId: '',
      backgroundImageUrl: '',
      backgroundImagePath: '',
      backgroundImageFit: DailyCareJournalTheme.fitCover,
      backgroundImageFade: DailyCareJournalTheme.fadeLight,
      cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceSolid,
      cardDefaultBackgroundAssetId: '',
      cardBackgroundType: DailyCareJournalTheme.cardTypeSolid,
      cardBackgroundPreset: DailyCareJournalTheme.cardPresetNone,
      cardBackgroundImageUrl: '',
      cardBackgroundImagePath: '',
      cardBackgroundImageFit: DailyCareJournalTheme.fitCover,
      cardBackgroundImageFade: DailyCareJournalTheme.fadeLight,
      journalHeader: current.journalHeader.copyWith(
        inkMode: DailyCareJournalCardStyle.inkCustom,
        inkColorArgb: tint.toARGB32(),
        useCardBackground: false,
      ),
      journalCards: {
        for (final (i, key) in DailyCareJournalCardKeys.ordered.indexed)
          key: cards[key]!.copyWith(
            width: DailyCareJournalCardKeys.isPinned(key)
                ? DailyCareJournalCardStyle.widthHalf
                : fullCards.contains(key) ||
                      key == 'photos' ||
                      key == 'generalNote'
                ? DailyCareJournalCardStyle.widthFull
                : DailyCareJournalCardStyle.widthHalf,
            colorKey: colors[i % colors.length],
            surfaceMode: DailyCareJournalCardStyle.surfaceFollow,
            backgroundSource: DailyCareJournalCardStyle.backgroundFollow,
            backgroundPreset: '',
            backgroundAssetId: '',
            inkMode: DailyCareJournalCardStyle.inkAuto,
            inkColorArgb: 0,
            // Keep visibility, icon library IDs and custom ordering intact.
          ),
      },
    );
  }

  bool matches(DailyCareSettingModel current) =>
      appearanceSignature(apply(current)) == appearanceSignature(current);

  /// Same persisted fields as the existing appearance-section save contract.
  static const appearanceKeys = [
    'logoVisible',
    'textColorKey',
    'accentColorKey',
    'iconSize',
    'iconColorKey',
    'categoryIcons',
    'cardRadius',
    'cardPadding',
    'cardGap',
    'showCardBorder',
    'photoRadius',
    'backgroundType',
    'backgroundColorKey',
    'backgroundImageUrl',
    'backgroundImagePath',
    'backgroundImageFit',
    'backgroundImageFade',
    'cardBackgroundType',
    'cardBackgroundPreset',
    'cardBackgroundImageUrl',
    'cardBackgroundImagePath',
    'cardBackgroundImageFit',
    'cardBackgroundImageFade',
    'pageBackgroundSource',
    'pageBackgroundAssetId',
    'cardDefaultSurfaceMode',
    'cardDefaultBackgroundAssetId',
    'journalDisplay',
    'journalCards',
    'journalHeader',
  ];
  static Map<String, dynamic> appearanceMap(DailyCareSettingModel setting) {
    final map = setting.toMap();
    return {
      for (final key in appearanceKeys)
        key: switch (key) {
          'pageBackgroundSource' => setting.resolvedPageBackgroundSource,
          'cardDefaultSurfaceMode' => setting.resolvedCardDefaultSurfaceMode,
          'journalCards' => DailyCareJournalCardLayout.mapToFirestore(
            setting.resolvedJournalCards,
          ),
          _ => map[key],
        },
    };
  }

  static String appearanceSignature(DailyCareSettingModel setting) =>
      jsonEncode(appearanceMap(setting));
}

const dailyCareAppearancePresets = [
  DailyCareAppearancePreset(
    id: 'classic',
    name: '經典分區',
    description: '暖米底色，分類色塊與雙欄卡片。',
    pageColor: 'warm',
    tint: Color(0xFF2F5D50),
    colors: ['mint', 'cream', 'blue', 'mint', 'blue', 'pink', 'theme'],
    fullCards: ['relax'],
  ),
  DailyCareAppearancePreset(
    id: 'blue',
    name: '清爽藍白',
    description: '藍白留白，生活紀錄滿寬閱讀。',
    pageColor: 'blue',
    tint: Color(0xFF3D6F9F),
    colors: ['theme'],
    fullCards: ['food'],
    radius: 12,
    padding: 14,
    gap: 12,
  ),
  DailyCareAppearancePreset(
    id: 'mint',
    name: '薄荷照護',
    description: '柔綠與奶油搭配，卡片更圓潤。',
    pageColor: 'green',
    tint: Color(0xFF2F5D50),
    colors: ['mint', 'cream', 'mint', 'cream', 'mint', 'cream', 'theme'],
    fullCards: ['relax'],
    radius: 22,
    padding: 14,
    gap: 14,
  ),
  DailyCareAppearancePreset(
    id: 'journal',
    name: '奶油日誌',
    description: '暖色滿寬卡片，依序閱讀每段日常。',
    pageColor: 'warm',
    tint: Color(0xFF79513A),
    colors: ['cream', 'orange', 'cream', 'cream', 'orange', 'cream', 'theme'],
    fullCards: ['food', 'activity', 'relax'],
    radius: 20,
    padding: 16,
    gap: 16,
    border: false,
  ),
  DailyCareAppearancePreset(
    id: 'rose',
    name: '暖粉陪伴',
    description: '柔粉與奶油雙欄，輕盈溫暖。',
    pageColor: 'pink',
    tint: Color(0xFF855165),
    colors: ['cream', 'pink', 'pink', 'cream', 'pink', 'cream', 'theme'],
    radius: 24,
    padding: 12,
    gap: 12,
    border: false,
  ),
  DailyCareAppearancePreset(
    id: 'minimal',
    name: '極簡清單',
    description: '白色滿寬清單，緊湊清楚地查看。',
    pageColor: 'default',
    tint: Color(0xFF3A4D5D),
    colors: ['theme'],
    fullCards: ['food', 'activity', 'relax'],
    radius: 8,
    padding: 10,
    gap: 8,
  ),
];

DailyCareAppearancePreset? matchingDailyCareAppearance(
  DailyCareSettingModel setting,
) {
  for (final preset in dailyCareAppearancePresets) {
    if (preset.matches(setting)) return preset;
  }
  return null;
}
