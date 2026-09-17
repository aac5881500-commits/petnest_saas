// 檔案名稱：test/daily_care_journal_layout_test.dart
// 功能說明：舊店家缺欄套用預設編排；welcomeText 不讀不寫

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_journal_layout.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/widgets/daily_care_illustrations.dart';

void main() {
  test('舊資料沒有 journalCards 時套用預設半寬與色彩', () {
    final DailyCareSettingModel setting = DailyCareSettingModel.fromMap(
      <String, dynamic>{'enabled': true, 'welcomeText': '舊歡迎'},
    );
    final Map<String, DailyCareJournalCardLayout> cards =
        setting.resolvedJournalCards;
    expect(cards[DailyCareJournalCardKeys.environment]!.isHalf, isTrue);
    expect(
      cards[DailyCareJournalCardKeys.environment]!.colorKey,
      DailyCareJournalCardStyle.colorMint,
    );
    expect(cards[DailyCareJournalCardKeys.relax]!.isHalf, isFalse);
    expect(setting.journalDisplay.showShopName, isTrue);
    expect(setting.journalDisplay.showTemperature, isTrue);
    expect(setting.toMap().containsKey('welcomeText'), isFalse);
    expect(
      (setting.toMap()['journalDisplay'] as Map).containsKey('showShopName'),
      isFalse,
    );
    expect(
      (setting.toMap()['journalDisplay'] as Map).containsKey('showTemperature'),
      isFalse,
    );
    expect(setting.toMap().containsKey('logoAlign'), isFalse);
    expect(setting.toMap().containsKey('titleFontSize'), isFalse);
    expect(setting.isCareFieldEnabled('stool'), isTrue);
    expect(setting.isCareFieldEnabled('urine'), isTrue);
    expect(setting.enabledFields.contains('stool'), isFalse);
  });

  test('舊 welcomeText 讀取不失敗且不會寫回 toMap', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{'welcomeText': '請放心'},
    );
    expect(parsed.toMap().containsKey('welcomeText'), isFalse);
  });

  test('寵物名稱最多兩隻並顯示其餘隻數', () {
    expect(
      DailyCareStayInfo.formatPetNames(const <DailyCareStayPet>[
        DailyCareStayPet(name: '小米', photoUrl: ''),
      ]),
      '小米',
    );
    expect(
      DailyCareStayInfo.formatPetNames(const <DailyCareStayPet>[
        DailyCareStayPet(name: '小米', photoUrl: ''),
        DailyCareStayPet(name: '奶茶', photoUrl: ''),
        DailyCareStayPet(name: '歐蕾', photoUrl: ''),
        DailyCareStayPet(name: '黑糖', photoUrl: ''),
      ]),
      '小米、奶茶 等 4 隻',
    );
  });

  test('可隱藏卡片並寫回 Firestore 純 map', () {
    final DailyCareSettingModel setting = const DailyCareSettingModel().copyWith(
          journalDisplay: const DailyCareJournalDisplayFlags(
            showShopName: false,
            showTemperature: false,
            showRoomOrOffer: false,
            showPhotoSection: false,
          ),
          journalCards: DailyCareJournalCardLayout.mapFrom(<String, dynamic>{
            'food': <String, dynamic>{
              'visible': false,
              'width': 'full',
              'colorKey': 'orange',
              'order': 0,
            },
          }),
        );
    final Map<String, dynamic> map = setting.toMap();
    expect(map['journalDisplay'], isA<Map>());
    expect(map['journalCards'], isA<Map>());
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(map);
    expect(parsed.journalDisplay.showShopName, isTrue);
    expect(parsed.journalDisplay.showTemperature, isTrue);
    expect(parsed.journalDisplay.showPhotoSection, isFalse);
    expect(
      (map['journalDisplay'] as Map).containsKey('showRoomOrOffer'),
      isFalse,
    );
    expect(
      (map['journalDisplay'] as Map).containsKey('showPetNames'),
      isFalse,
    );
    expect(parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!.visible, isFalse);
    expect(
      parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!.colorKey,
      DailyCareJournalCardStyle.colorOrange,
    );
    final List<DailyCareJournalCardLayout> display =
        DailyCareJournalCardLayout.displaySorted(parsed.resolvedJournalCards);
    expect(display.first.key, DailyCareJournalCardKeys.environment);
    expect(display[1].key, DailyCareJournalCardKeys.toilet);
  });

  test('舊關閉溫濕度、店名與大小便仍一律顯示且不寫回開關', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{
        'enabledFields': <String>['water'],
        'journalDisplay': <String, dynamic>{
          'showShopName': false,
          'showTemperature': false,
          'showHumidity': false,
        },
        'logoAlign': 'center',
        'logoSize': 48,
        'titleFontSize': 22,
        'bodyFontSize': 16,
      },
    );
    expect(parsed.journalDisplay.showShopName, isTrue);
    expect(parsed.journalDisplay.showTemperature, isTrue);
    expect(parsed.journalDisplay.showHumidity, isTrue);
    expect(parsed.isCareFieldEnabled('stool'), isTrue);
    expect(parsed.isCareFieldEnabled('urine'), isTrue);
    expect(parsed.enabledFields, <String>['water']);
    final Map<String, dynamic> map = parsed.toMap();
    expect(map.containsKey('logoAlign'), isFalse);
    expect(map.containsKey('logoSize'), isFalse);
    expect(map.containsKey('titleFontSize'), isFalse);
    expect(map.containsKey('bodyFontSize'), isFalse);
    expect(
      (map['journalDisplay'] as Map).containsKey('showShopName'),
      isFalse,
    );
    expect(
      (map['enabledFields'] as List<dynamic>),
      isNot(contains('stool')),
    );
    expect(
      DailyCareReportFormat.hintOf(DailyCareReportFormat.yesNo),
      '回報格式：有／無',
    );
    expect(
      DailyCareReportFormat.hintOf(DailyCareReportFormat.amount),
      '回報格式：無／少／一般／多',
    );
    expect(
      DailyCareReportFormat.hintOf(DailyCareReportFormat.condition),
      '回報格式：正常／偏少／偏多／異常',
    );
    expect(
      DailyCareReportFormat.hintOf(DailyCareReportFormat.text),
      '回報格式：自由文字',
    );
  });

  test('固定卡忽略關閉、滿寬與順序，缺 ink 時使用自動', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{
        'journalCards': <String, dynamic>{
          'environment': <String, dynamic>{
            'visible': false,
            'width': 'full',
            'colorKey': 'orange',
            'order': 9,
          },
          'toilet': <String, dynamic>{
            'visible': false,
            'width': 'full',
            'order': 8,
          },
          'food': <String, dynamic>{
            'visible': true,
            'width': 'half',
            'order': 0,
            'inkMode': 'light',
            'inkColorArgb': 0xFFF6F0E6,
          },
        },
      },
    );
    final DailyCareJournalCardLayout env =
        parsed.resolvedJournalCards[DailyCareJournalCardKeys.environment]!;
    final DailyCareJournalCardLayout toilet =
        parsed.resolvedJournalCards[DailyCareJournalCardKeys.toilet]!;
    final DailyCareJournalCardLayout food =
        parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!;
    expect(env.visible, isTrue);
    expect(env.isHalf, isTrue);
    expect(env.order, 0);
    expect(env.inkMode, DailyCareJournalCardStyle.inkAuto);
    expect(env.colorKey, DailyCareJournalCardStyle.colorOrange);
    expect(toilet.visible, isTrue);
    expect(toilet.isHalf, isTrue);
    expect(toilet.order, 1);
    expect(food.inkMode, DailyCareJournalCardStyle.inkLight);
    expect(food.inkColorArgb, 0xFFF6F0E6);
    final Map<String, dynamic> envMap =
        (parsed.toMap()['journalCards'] as Map)['environment'] as Map<String, dynamic>;
    expect(envMap['inkMode'], DailyCareJournalCardStyle.inkAuto);
    expect(envMap['inkColorArgb'], 0);
    final List<DailyCareJournalCardLayout> display =
        DailyCareJournalCardLayout.displaySorted(parsed.resolvedJournalCards);
    expect(display[0].key, DailyCareJournalCardKeys.environment);
    expect(display[1].key, DailyCareJournalCardKeys.toilet);
  });

  test('舊資料沒有 journalHeader 時使用純色頁首與自動文字色', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{'enabled': true},
    );
    expect(parsed.journalHeader.useCardBackground, isFalse);
    expect(parsed.journalHeader.inkMode, DailyCareJournalCardStyle.inkAuto);
    expect(parsed.journalHeader.inkColorArgb, 0);
    final Map<String, dynamic> header =
        parsed.toMap()['journalHeader'] as Map<String, dynamic>;
    expect(header['useCardBackground'], isFalse);
    expect(header['inkMode'], DailyCareJournalCardStyle.inkAuto);
  });

  test('頁首卡可切換文字色與卡片背景圖', () {
    final DailyCareSettingModel setting = const DailyCareSettingModel().copyWith(
      journalHeader: const DailyCareJournalHeaderStyle(
        inkMode: DailyCareJournalCardStyle.inkLight,
        inkColorArgb: 0xFFF6F0E6,
        useCardBackground: true,
      ),
      cardBackgroundType: DailyCareJournalTheme.cardTypePreset,
      cardBackgroundPreset: DailyCareJournalTheme.cardPresetPaw,
    );
    expect(setting.journalHeader.useCardBackground, isTrue);
    expect(setting.journalHeader.inkMode, DailyCareJournalCardStyle.inkLight);
    expect(setting.hasCardBackgroundVisual, isTrue);
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      setting.toMap(),
    );
    expect(parsed.journalHeader.useCardBackground, isTrue);
    expect(parsed.journalHeader.inkMode, DailyCareJournalCardStyle.inkLight);
    expect(parsed.cardBackgroundPreset, DailyCareJournalTheme.cardPresetPaw);
    expect(
      parsed.toMap()['cardBackgroundPreset'],
      DailyCareJournalTheme.cardPresetPaw,
    );
    expect(parsed.toMap().containsKey('cardBackgroundAssetUrl'), isFalse);
  });

  test('卡片背景 overlay：原圖清楚、淡化預設、很淡接近白卡', () {
    const DailyCareSettingModel none = DailyCareSettingModel(
      cardBackgroundImageFade: DailyCareJournalTheme.fadeNone,
    );
    const DailyCareSettingModel light = DailyCareSettingModel(
      cardBackgroundImageFade: DailyCareJournalTheme.fadeLight,
    );
    const DailyCareSettingModel heavy = DailyCareSettingModel(
      cardBackgroundImageFade: DailyCareJournalTheme.fadeHeavy,
    );
    expect(none.resolvedCardOverlayOpacity(), 0.22);
    expect(light.resolvedCardOverlayOpacity(), 0.42);
    expect(heavy.resolvedCardOverlayOpacity(), 0.70);
    expect(none.resolvedCardOverlayOpacity(longText: true), 0.32);
    expect(light.resolvedCardOverlayOpacity(longText: true), 0.52);
    expect(heavy.resolvedCardOverlayOpacity(longText: true), closeTo(0.80, 0.001));
    expect(
      const DailyCareSettingModel(
        backgroundImageFade: DailyCareJournalTheme.fadeNone,
        cardBackgroundImageFade: DailyCareJournalTheme.fadeHeavy,
      ).resolvedImageOverlayOpacity(),
      0.32,
    );
    expect(
      const DailyCareSettingModel(
        backgroundImageFade: DailyCareJournalTheme.fadeNone,
        cardBackgroundImageFade: DailyCareJournalTheme.fadeHeavy,
      ).resolvedCardOverlayOpacity(),
      0.70,
    );
    expect(
      DailyCareJournalTheme.builtInVisuals.every(
        (DailyCareCardBackgroundPreset item) => item.hasAsset,
      ),
      isTrue,
    );
    expect(
      DailyCareJournalTheme.builtInVisuals.map(
        (DailyCareCardBackgroundPreset item) => item.key,
      ),
      isNot(contains(DailyCareJournalTheme.cardPresetNone)),
    );
  });

  test('舊資料沒有單卡背景時跟隨統一背景', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{
        'journalCards': <String, dynamic>{
          'food': <String, dynamic>{
            'visible': true,
            'width': 'full',
          },
        },
      },
    );
    final DailyCareJournalCardLayout food =
        parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!;
    expect(food.followsSharedBackground, isTrue);
    expect(
      food.backgroundSource,
      DailyCareJournalCardStyle.backgroundFollow,
    );
    expect(
      parsed.visualForCard(food).cardBackgroundType,
      parsed.cardBackgroundType,
    );
  });

  test('單卡只能跟隨統一或平台內建，不會吃店家自訂圖', () {
    final DailyCareSettingModel setting = DailyCareSettingModel.fromMap(
      <String, dynamic>{
        'cardBackgroundType': DailyCareJournalTheme.cardTypeImage,
        'cardBackgroundImageUrl': 'https://example.com/shop.png',
        'journalCards': <String, dynamic>{
          'food': <String, dynamic>{
            'backgroundSource': 'preset',
            'backgroundPreset': DailyCareJournalTheme.cardPresetPaw,
          },
          'relax': <String, dynamic>{
            'backgroundSource': 'image',
            'backgroundPreset': '',
          },
        },
      },
    );
    final DailyCareJournalCardLayout food =
        setting.resolvedJournalCards[DailyCareJournalCardKeys.food]!;
    final DailyCareJournalCardLayout relax =
        setting.resolvedJournalCards[DailyCareJournalCardKeys.relax]!;
    expect(food.followsSharedBackground, isFalse);
    expect(relax.followsSharedBackground, isTrue);
    final DailyCareSettingModel foodVisual = setting.visualForCard(food);
    expect(foodVisual.cardBackgroundType, DailyCareJournalTheme.cardTypePreset);
    expect(foodVisual.cardBackgroundPreset, DailyCareJournalTheme.cardPresetPaw);
    expect(foodVisual.cardBackgroundImageUrl, isEmpty);
    expect(
      setting.visualForCard(relax).cardBackgroundImageUrl,
      'https://example.com/shop.png',
    );
    expect(
      (food.toMap()['backgroundSource']),
      DailyCareJournalCardStyle.backgroundPreset,
    );
    expect(food.toMap().containsKey('cardBackgroundImageUrl'), isFalse);
  });

  test('自動文字色為可讀深色，淺色只有明確選擇才出現', () {
    const DailyCareJournalCardLayout auto = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
    );
    const DailyCareJournalCardLayout light = DailyCareJournalCardLayout(
      key: DailyCareJournalCardKeys.food,
      inkMode: DailyCareJournalCardStyle.inkLight,
    );
    const ColorScheme colors = ColorScheme.light();
    expect(
      DailyCareInk.of(
        layout: auto,
        fill: const Color(0xFFE8F1F8),
        colors: colors,
      ),
      DailyCareInk.dark,
    );
    expect(
      DailyCareInk.of(
        layout: auto,
        fill: const Color(0xFF2F5D50),
        colors: colors,
      ),
      DailyCareInk.dark,
    );
    expect(
      DailyCareInk.of(
        layout: light,
        fill: const Color(0xFFE8F1F8),
        colors: colors,
      ),
      DailyCareInk.light,
    );
    expect(
      DailyCareInk.headerOf(
        header: const DailyCareJournalHeaderStyle(),
        fill: const Color(0xFFE8F1F8),
        colors: colors,
      ),
      DailyCareInk.dark,
    );
  });
}
