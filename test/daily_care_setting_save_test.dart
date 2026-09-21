// 檔案名稱：test/daily_care_setting_save_test.dart
// 功能說明：每日照護設定寫入 Firestore 的資料必須可序列化，舊欄不寫回

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_journal_layout.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';

void main() {
  bool isPlainFirestoreValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is String ||
        value is bool ||
        value is num ||
        value is Timestamp ||
        value is FieldValue) {
      return true;
    }
    if (value is List) {
      return value.every(isPlainFirestoreValue);
    }
    if (value is Map) {
      return value.entries.every((MapEntry<dynamic, dynamic> entry) {
        return entry.key is String && isPlainFirestoreValue(entry.value);
      });
    }
    return false;
  }

  test('舊設定缺新欄位仍可讀，並帶入預設值', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{
        'enabled': true,
        'welcomeText': '請放心',
        'journalDisplay': <String, dynamic>{'showRoomOrOffer': false},
      },
    );
    expect(parsed.enabled, isTrue);
    expect(parsed.logoVisible, isTrue);
    expect(parsed.journalDisplay.showShopName, isTrue);
    expect(parsed.journalDisplay.showPhotoSection, isTrue);
    expect(parsed.journalDisplay.showTemperature, isTrue);
    expect(parsed.resolvedJournalCards.length, 7);
    expect(parsed.toMap().containsKey('welcomeText'), isFalse);
    expect(parsed.toMap().containsKey('logoAlign'), isFalse);
    expect(parsed.journalHeader.useCardBackground, isFalse);
    expect(parsed.journalHeader.inkMode, DailyCareJournalCardStyle.inkAuto);
    expect(
      (parsed.toMap()['journalDisplay'] as Map).containsKey('showRoomOrOffer'),
      isFalse,
    );
    expect(
      (parsed.toMap()['journalDisplay'] as Map).containsKey('showShopName'),
      isFalse,
    );
  });

  test('toMap 只含可序列化資料，不含 Color / enum / Widget', () {
    final DailyCareSettingModel setting = DailyCareSettingModel(
      enabled: true,
      logoVisible: false,
      journalDisplay: const DailyCareJournalDisplayFlags(showShopName: false),
    );
    final Map<String, dynamic> map = setting.toMap();
    expect(map['logoVisible'], isFalse);
    expect(map.containsKey('logoSize'), isFalse);
    expect(map['journalCards'], isA<Map>());
    expect(map['journalHeader'], isA<Map>());
    expect((map['journalHeader'] as Map)['useCardBackground'], isFalse);
    expect(map.values.every(isPlainFirestoreValue), isTrue);
    expect(map.containsKey('welcomeText'), isFalse);
  });

  test('sanitize 會丟掉 Color 與無法序列化的物件', () {
    final Map<String, dynamic> clean =
        DailyCareSettingFirestoreValue.sanitizeMap(<String, dynamic>{
          'titleFontSize': 18.0,
          'color': const Color(0xFF7A4E2D),
          'icon': Icons.pets,
          'nested': <String, dynamic>{'ok': true, 'bad': const Alignment(0, 0)},
        });
    expect(clean['titleFontSize'], 18.0);
    expect(clean.containsKey('color'), isFalse);
    expect(clean.containsKey('icon'), isFalse);
    expect(clean['nested'], <String, dynamic>{'ok': true});
  });

  test('寫入 payload 會刪除 welcomeText 與舊顯示開關', () {
    final DailyCareSettingModel setting = DailyCareSettingModel.fromMap(
      <String, dynamic>{
        'enabled': true,
        'welcomeText': '舊歡迎',
        'journalDisplay': <String, dynamic>{
          'showShopName': false,
          'showRoomOrOffer': false,
          'showPetNames': false,
        },
      },
    );
    final Map<String, dynamic> payload =
        DailyCareSettingFirestoreValue.payloadForWrite(setting);
    expect(payload.containsKey('welcomeText'), isFalse);
    expect(payload['enabled'], isTrue);
    expect(payload['revision'], isA<num>());
    final Map<dynamic, dynamic> display =
        payload['journalDisplay'] as Map<dynamic, dynamic>;
    expect(display.containsKey('showShopName'), isFalse);
    expect(display.containsKey('showTemperature'), isFalse);
    expect(display['showPhotoSection'], isTrue);
    expect(display.containsKey('showRoomOrOffer'), isFalse);
    expect(display.containsKey('showPetNames'), isFalse);
    expect(display.containsKey('showServiceDate'), isFalse);
    expect(display.containsKey('showFilledTime'), isFalse);
    expect(payload.values.every(isPlainFirestoreValue), isTrue);
    expect(display.values.every(isPlainFirestoreValue), isTrue);
    expect(payload.values.whereType<FieldValue>(), isEmpty);
  });

  test('店主寫入只存平台 assetId，不含圖檔 URL／bytes', () {
    final DailyCareSettingModel setting = const DailyCareSettingModel()
        .copyWith(
          pageBackgroundSource: DailyCareJournalTheme.pageSourceLibrary,
          pageBackgroundAssetId: 'page-1',
          cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
          cardDefaultBackgroundAssetId: 'card-1',
          journalCards: DailyCareJournalCardLayout.mapFrom(<String, dynamic>{
            'food': <String, dynamic>{
              'surfaceMode': DailyCareJournalCardStyle.surfaceLibrary,
              'backgroundAssetId': 'food-1',
            },
          }),
        );
    final Map<String, dynamic> payload =
        DailyCareSettingFirestoreValue.payloadForWrite(setting);
    expect(
      payload['pageBackgroundSource'],
      DailyCareJournalTheme.pageSourceLibrary,
    );
    expect(payload['pageBackgroundAssetId'], 'page-1');
    expect(payload['cardDefaultBackgroundAssetId'], 'card-1');
    expect(payload.containsKey('imageUrl'), isFalse);
    expect(payload.containsKey('storagePath'), isFalse);
    expect(payload.containsKey('fileBytes'), isFalse);
    final Map<dynamic, dynamic> food =
        (payload['journalCards'] as Map)['food'] as Map;
    expect(food['backgroundAssetId'], 'food-1');
    expect(food.containsKey('imageUrl'), isFalse);
  });

  test('journalCards.iconAssetId 寫入各卡且不含 URL', () {
    final Map<String, dynamic> cards = <String, dynamic>{
      for (final String key in DailyCareJournalCardKeys.ordered)
        key: <String, dynamic>{'iconAssetId': 'icon-$key'},
    };
    final DailyCareSettingModel setting = const DailyCareSettingModel()
        .copyWith(journalCards: DailyCareJournalCardLayout.mapFrom(cards));
    final Map<String, dynamic> payload =
        DailyCareSettingFirestoreValue.payloadForWrite(setting);
    final Map<dynamic, dynamic> stored = payload['journalCards'] as Map;
    for (final String key in DailyCareJournalCardKeys.ordered) {
      expect((stored[key] as Map)['iconAssetId'], 'icon-$key');
      expect((stored[key] as Map).containsKey('imageUrl'), isFalse);
    }
    final DailyCareSettingModel cleared = setting.copyWith(
      journalCards: DailyCareJournalCardLayout.mapFrom(<String, dynamic>{
        DailyCareJournalCardKeys.food: <String, dynamic>{'iconAssetId': ''},
      }),
    );
    expect(
      ((DailyCareSettingFirestoreValue.payloadForWrite(cleared)['journalCards']
              as Map)[DailyCareJournalCardKeys.food]
          as Map)['iconAssetId'],
      '',
    );
  });

  test('圖庫 ID 空白時寫入安全 fallback，不拋錯', () {
    final DailyCareSettingModel setting = const DailyCareSettingModel()
        .copyWith(
          pageBackgroundSource: DailyCareJournalTheme.pageSourceLibrary,
          pageBackgroundAssetId: '  ',
          cardDefaultSurfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
          cardDefaultBackgroundAssetId: '',
          journalCards: DailyCareJournalCardLayout.mapFrom(<String, dynamic>{
            'food': <String, dynamic>{
              'surfaceMode': DailyCareJournalCardStyle.surfaceLibrary,
              'backgroundAssetId': '',
            },
          }),
        );
    final DailyCareSettingModel safe = setting.forShopWrite();
    expect(safe.pageBackgroundSource, DailyCareJournalTheme.pageSourceSystem);
    expect(safe.pageBackgroundAssetId, isEmpty);
    expect(safe.cardDefaultSurfaceMode, DailyCareJournalCardStyle.surfaceSolid);
    expect(
      safe.resolvedJournalCards[DailyCareJournalCardKeys.food]!.surfaceMode,
      DailyCareJournalCardStyle.surfaceFollow,
    );
    expect(
      () => DailyCareSettingFirestoreValue.payloadForWrite(setting),
      returnsNormally,
    );
  });

  test('舊 backgroundImageUrl 仍可讀且寫入時保留', () {
    final DailyCareSettingModel parsed =
        DailyCareSettingModel.fromMap(<String, dynamic>{
          'backgroundType': DailyCareJournalTheme.typeImage,
          'backgroundImageUrl': 'https://old.example/page.png',
          'backgroundImagePath': 'shops/s1/daily_care_backgrounds/a.jpg',
        });
    expect(parsed.backgroundImageUrl, 'https://old.example/page.png');
    expect(parsed.hasCustomBackgroundImage, isTrue);
    final Map<String, dynamic> payload =
        DailyCareSettingFirestoreValue.payloadForWrite(parsed);
    expect(payload['backgroundImageUrl'], 'https://old.example/page.png');
    expect(
      payload['backgroundImagePath'],
      'shops/s1/daily_care_backgrounds/a.jpg',
    );
  });

  test('NaN 字級不會寫進 payload', () {
    final Map<String, dynamic> clean =
        DailyCareSettingFirestoreValue.sanitizeMap(<String, dynamic>{
          'titleFontSize': double.nan,
          'cardGap': 12,
        });
    expect(clean.containsKey('titleFontSize'), isFalse);
    expect(clean['cardGap'], 12);
  });

  test('shops 規則允許店主寫自己的 dailyCareSetting，不可寫平台圖庫', () {
    final String rules = File('firestore.rules').readAsStringSync();
    final int shops = rules.indexOf('match /shops/{shopId} {');
    expect(shops, greaterThanOrEqualTo(0));
    final String shopsBlock = rules.substring(
      shops,
      rules.indexOf('match /platform_media_library/{assetId}', shops),
    );
    expect(shopsBlock.contains("'dailyCareSetting'"), isTrue);
    expect(shopsBlock.contains('isShopMember(shopId)'), isTrue);
    expect(shopsBlock.contains('isShopOwnerUid(shopId)'), isTrue);
    final int library = rules.indexOf(
      'match /platform_media_library/{assetId}',
    );
    final String libraryBlock = rules.substring(
      library,
      rules.indexOf('match /platform_users/{platformUid}', library),
    );
    expect(libraryBlock.contains('canManagePlatformMedia()'), isTrue);
    expect(libraryBlock.contains('isShopMember'), isFalse);
    expect(
      libraryBlock.contains('allow create, update, delete: if true'),
      isFalse,
    );
  });
}
