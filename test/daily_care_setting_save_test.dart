// 檔案名稱：test/daily_care_setting_save_test.dart
// 功能說明：每日照護設定寫入 Firestore 的資料必須可序列化，舊欄不寫回

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
        'journalDisplay': <String, dynamic>{
          'showRoomOrOffer': false,
        },
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
    expect(
      (map['journalHeader'] as Map)['useCardBackground'],
      isFalse,
    );
    expect(map.values.every(isPlainFirestoreValue), isTrue);
    expect(map.containsKey('welcomeText'), isFalse);
  });

  test('sanitize 會丟掉 Color 與無法序列化的物件', () {
    final Map<String, dynamic> clean = DailyCareSettingFirestoreValue
        .sanitizeMap(<String, dynamic>{
          'titleFontSize': 18.0,
          'color': const Color(0xFF7A4E2D),
          'icon': Icons.pets,
          'nested': <String, dynamic>{
            'ok': true,
            'bad': const Alignment(0, 0),
          },
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
    expect(payload['welcomeText'], isA<FieldValue>());
    expect(payload['enabled'], isTrue);
    expect(payload['revision'], isA<num>());
    final Map<dynamic, dynamic> display =
        payload['journalDisplay'] as Map<dynamic, dynamic>;
    expect(display.containsKey('showShopName'), isFalse);
    expect(display.containsKey('showTemperature'), isFalse);
    expect(display['showPhotoSection'], isTrue);
    expect(display['showRoomOrOffer'], isA<FieldValue>());
    expect(display['showPetNames'], isA<FieldValue>());
    expect(display['showServiceDate'], isA<FieldValue>());
    expect(display['showFilledTime'], isA<FieldValue>());
    expect(payload.values.every(isPlainFirestoreValue), isTrue);
    expect(display.values.every(isPlainFirestoreValue), isTrue);
  });

  test('NaN 字級不會寫進 payload', () {
    final Map<String, dynamic> clean = DailyCareSettingFirestoreValue
        .sanitizeMap(<String, dynamic>{
          'titleFontSize': double.nan,
          'cardGap': 12,
        });
    expect(clean.containsKey('titleFontSize'), isFalse);
    expect(clean['cardGap'], 12);
  });
}
