// 檔案名稱：lib/core/services/daily_care_setting_service.dart
// 功能說明：讀取、監聽與儲存店家的每日照護紀錄設定。
// 🐾 每日照護紀錄設定 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_care_setting_model.dart';

class DailyCareSaveErrorProbe {
  DailyCareSaveErrorProbe._();

  static String readCode(Object error) {
    try {
      if (error is FirebaseException) {
        return error.code;
      }
    } catch (_) {}
    try {
      final Object? value = (error as dynamic).code;
      if (value == null) {
        return '';
      }
      return safeToString(value);
    } catch (_) {
      return '';
    }
  }

  static String readMessage(Object error) {
    try {
      if (error is FirebaseException) {
        return (error.message ?? '').trim();
      }
    } catch (_) {}
    try {
      final Object? value = (error as dynamic).message;
      if (value == null) {
        return '';
      }
      return safeToString(value).trim();
    } catch (_) {
      return '';
    }
  }

  static String safeToString(Object? value) {
    if (value == null) {
      return '';
    }
    try {
      return value.toString();
    } catch (_) {
      return '';
    }
  }

  static void debugLog(String label, Object error, [StackTrace? stack]) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(label);
    if (error is FirebaseException) {
      debugPrint('FirebaseException code=${error.code}');
      debugPrint('FirebaseException message=${error.message}');
    } else {
      final String code = readCode(error);
      final String message = readMessage(error);
      if (code.isNotEmpty) {
        debugPrint('error code=$code');
      }
      if (message.isNotEmpty) {
        debugPrint('error message=$message');
      }
    }
    debugPrint('exception=${safeToString(error)}');
    if (stack != null) {
      debugPrint(safeToString(stack));
    }
  }
}

class DailyCareSettingSaveException implements Exception {
  const DailyCareSettingSaveException(this.message, {this.code = ''});

  final String message;
  final String code;

  @override
  String toString() => message;

  static DailyCareSettingSaveException fromError(Object error) {
    if (error is DailyCareSettingSaveException) {
      return error;
    }
    final String code = DailyCareSaveErrorProbe.readCode(error);
    final String rawMessage = DailyCareSaveErrorProbe.readMessage(error);
    final String asString = DailyCareSaveErrorProbe.safeToString(error);
    final String combined = <String>[
      code,
      rawMessage,
      asString,
    ].join(' ').toLowerCase();

    if (code == 'permission-denied' ||
        combined.contains('permission-denied') ||
        combined.contains('permission_denied')) {
      return const DailyCareSettingSaveException(
        '沒有儲存每日照護設定的權限',
        code: 'permission-denied',
      );
    }
    if (code == 'revision-conflict' ||
        combined.contains('revision-conflict') ||
        combined.contains('已被其他人更新') ||
        combined.contains('重新載入後再儲存')) {
      return const DailyCareSettingSaveException(
        '設定已被其他人更新，請重新載入後再儲存',
        code: 'revision-conflict',
      );
    }
    if (combined.contains('converted future') ||
        combined.contains('javascriptobject') ||
        combined.contains('dart exception thrown')) {
      return const DailyCareSettingSaveException(
        '儲存失敗，請稍後再試',
        code: 'unknown',
      );
    }
    if (rawMessage.isNotEmpty) {
      return DailyCareSettingSaveException(rawMessage, code: code);
    }
    return const DailyCareSettingSaveException('儲存失敗，請稍後再試', code: 'unknown');
  }
}

class DailyCareSettingFirestoreValue {
  DailyCareSettingFirestoreValue._();

  static Map<String, dynamic> copyRawMap(Object? raw) {
    if (raw is! Map) {
      return <String, dynamic>{};
    }
    final Map<String, dynamic> copied = <String, dynamic>{};
    raw.forEach((Object? key, Object? value) {
      final String name = DailyCareSaveErrorProbe.safeToString(key).trim();
      if (name.isEmpty) {
        return;
      }
      copied[name] = value;
    });
    return copied;
  }

  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> input) {
    final Object? value = sanitize(input);
    if (value is Map<String, dynamic>) {
      return value;
    }
    return <String, dynamic>{};
  }

  static const List<String> _removedSettingKeys = <String>[
    'welcomeText',
  ];

  static const List<String> _removedDisplayKeys = <String>[
    'showRoomOrOffer',
    'showPetNames',
    'showServiceDate',
    'showFilledTime',
  ];

  static Map<String, dynamic> payloadForWrite(DailyCareSettingModel setting) {
    final Map<String, dynamic> payload = sanitizeMap(setting.toMap());
    for (final String key in _removedSettingKeys) {
      payload[key] = FieldValue.delete();
    }
    final Map<String, dynamic> display = payload['journalDisplay'] is Map
        ? Map<String, dynamic>.from(payload['journalDisplay'] as Map)
        : <String, dynamic>{};
    for (final String key in _removedDisplayKeys) {
      display.remove(key);
      display[key] = FieldValue.delete();
    }
    payload['journalDisplay'] = display;
    return payload;
  }

  static Object? sanitize(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        return null;
      }
      return value;
    }
    if (value is Timestamp || value is FieldValue) {
      return value;
    }
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is Iterable) {
      return value
          .map(sanitize)
          .where((Object? item) => item != null)
          .toList();
    }
    if (value is Map) {
      final Map<String, dynamic> out = <String, dynamic>{};
      value.forEach((Object? key, Object? nested) {
        final String name = DailyCareSaveErrorProbe.safeToString(key).trim();
        if (name.isEmpty) {
          return;
        }
        final Object? clean = sanitize(nested);
        if (clean != null) {
          out[name] = clean;
        }
      });
      return out;
    }
    return null;
  }
}

class DailyCareSettingService {
  DailyCareSettingService._();

  static final DailyCareSettingService instance = DailyCareSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _shopReference(String shopId) {
    return _firestore.collection('shops').doc(shopId);
  }

  Stream<DailyCareSettingModel> streamSetting(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<DailyCareSettingModel>.value(const DailyCareSettingModel());
    }

    return _shopReference(normalizedShopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (data == null) {
        return const DailyCareSettingModel();
      }

      final Object? rawSetting = data['dailyCareSetting'];

      if (rawSetting is! Map) {
        return const DailyCareSettingModel();
      }

      return DailyCareSettingModel.fromMap(
        DailyCareSettingFirestoreValue.sanitizeMap(
          DailyCareSettingFirestoreValue.copyRawMap(rawSetting),
        ),
      );
    });
  }

  Future<DailyCareSettingModel> getSetting(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _shopReference(normalizedShopId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (data == null) {
      return const DailyCareSettingModel();
    }

    final Object? rawSetting = data['dailyCareSetting'];

    if (rawSetting is! Map) {
      return const DailyCareSettingModel();
    }

    return DailyCareSettingModel.fromMap(
      DailyCareSettingFirestoreValue.sanitizeMap(
        DailyCareSettingFirestoreValue.copyRawMap(rawSetting),
      ),
    );
  }

  Future<void> saveSetting({
    required String shopId,
    required DailyCareSettingModel setting,
    int? expectedRevision,
    DailyCareSettingSection section = DailyCareSettingSection.all,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(_shopReference(normalizedShopId));
        final Object? raw = snapshot.data()?['dailyCareSetting'];
        int currentRevision = 0;
        if (raw is Map && raw['revision'] is num) {
          currentRevision = (raw['revision'] as num).round();
        }
        if (expectedRevision != null && expectedRevision != currentRevision) {
          throw const DailyCareSettingSaveException(
            '設定已被其他人更新，請重新載入後再儲存',
            code: 'revision-conflict',
          );
        }
        final DailyCareSettingModel current = raw is Map
            ? DailyCareSettingModel.fromMap(
                DailyCareSettingFirestoreValue.sanitizeMap(
                  DailyCareSettingFirestoreValue.copyRawMap(raw),
                ),
              )
            : const DailyCareSettingModel();
        final DailyCareSettingModel merged = _mergeSection(
          current: current,
          incoming: setting,
          section: section,
        );
        final DailyCareSettingModel next = merged.copyWith(
          revision: currentRevision + 1,
        );
        final Map<String, dynamic> payload =
            DailyCareSettingFirestoreValue.payloadForWrite(next);
        payload['revision'] = currentRevision + 1;
        transaction.set(_shopReference(normalizedShopId), <String, dynamic>{
          'dailyCareSetting': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (error, stack) {
      DailyCareSaveErrorProbe.debugLog(
        'DailyCareSetting save failed',
        error,
        stack,
      );
      throw DailyCareSettingSaveException.fromError(error);
    }
  }

  DailyCareSettingModel _mergeSection({
    required DailyCareSettingModel current,
    required DailyCareSettingModel incoming,
    required DailyCareSettingSection section,
  }) {
    switch (section) {
      case DailyCareSettingSection.rules:
        return current.copyWith(
          enabled: incoming.enabled,
          sessionCount: incoming.sessionCount,
          sessionLabels: incoming.sessionLabels,
          photoEnabled: incoming.photoEnabled,
          stayReportMode: incoming.stayReportMode,
          stayPhotosIncluded: incoming.stayPhotosIncluded,
          stayAddonUpgradeEnabled: incoming.stayAddonUpgradeEnabled,
          stayOfferQuotas: incoming.stayOfferQuotas,
          stayPaidPlan: incoming.stayPaidPlan,
          daycareEnabled: incoming.daycareEnabled,
          daycareSessionCount: incoming.daycareSessionCount,
          daycareSessionLabels: incoming.daycareSessionLabels,
          daycareReportMode: incoming.daycareReportMode,
          daycarePhotosIncluded: incoming.daycarePhotosIncluded,
          daycareAddonUpgradeEnabled: incoming.daycareAddonUpgradeEnabled,
          daycareOfferQuotas: incoming.daycareOfferQuotas,
          daycarePaidPlan: incoming.daycarePaidPlan,
          downloadHoursAfterCheckout: incoming.downloadHoursAfterCheckout,
        );
      case DailyCareSettingSection.content:
        return current.copyWith(
          enabledFields: incoming.enabledFields,
          customFields: incoming.customFields,
        );
      case DailyCareSettingSection.appearance:
        return current.copyWith(
          logoVisible: incoming.logoVisible,
          textColorKey: incoming.textColorKey,
          accentColorKey: incoming.accentColorKey,
          iconSize: incoming.iconSize,
          iconColorKey: incoming.iconColorKey,
          categoryIcons: incoming.categoryIcons,
          cardRadius: incoming.cardRadius,
          cardPadding: incoming.cardPadding,
          cardGap: incoming.cardGap,
          showCardBorder: incoming.showCardBorder,
          photoRadius: incoming.photoRadius,
          backgroundType: incoming.backgroundType,
          backgroundColorKey: incoming.backgroundColorKey,
          backgroundImageUrl: incoming.backgroundImageUrl,
          backgroundImagePath: incoming.backgroundImagePath,
          backgroundImageFit: incoming.backgroundImageFit,
          backgroundImageFade: incoming.backgroundImageFade,
          cardBackgroundType: incoming.cardBackgroundType,
          cardBackgroundPreset: incoming.cardBackgroundPreset,
          cardBackgroundImageUrl: incoming.cardBackgroundImageUrl,
          cardBackgroundImagePath: incoming.cardBackgroundImagePath,
          cardBackgroundImageFit: incoming.cardBackgroundImageFit,
          cardBackgroundImageFade: incoming.cardBackgroundImageFade,
          journalDisplay: incoming.journalDisplay,
          journalCards: incoming.journalCards,
          journalHeader: incoming.journalHeader,
        );
      case DailyCareSettingSection.all:
        return incoming;
    }
  }
}

enum DailyCareSettingSection { rules, content, appearance, all }
