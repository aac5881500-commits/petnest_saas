// 檔案名稱：lib/core/services/daily_care_setting_service.dart
// 功能說明：讀取、監聽與儲存店家的每日照護紀錄設定。
// 🐾 每日照護紀錄設定 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_care_offer_quota.dart';
import '../models/daily_care_paid_plan.dart';
import '../models/daily_care_report_mode.dart';
import '../models/daily_care_setting_model.dart';
import 'daily_care_js_error_stub.dart'
    if (dart.library.js_interop) 'daily_care_js_error_web.dart';

class DailyCareSaveErrorProbe {
  DailyCareSaveErrorProbe._();

  /// debug 用：保留 transaction 裡真正的 Dart 例外，不讓 Web 外層包裝蓋掉。
  static Object? debugRoot;
  static String debugRootType = '';
  static String debugLabel = '';

  static String readCode(Object error) {
    final Object root = unwrapRoot(error);
    final String dartCode = _readDartCode(root);
    if (dartCode.isNotEmpty) {
      return _normalizeCode(dartCode);
    }
    return _normalizeCode(readDailyCareJsProperty(root, 'code'));
  }

  static String readMessage(Object error) {
    final Object root = unwrapRoot(error);
    final String dartMessage = _readDartMessage(root);
    if (dartMessage.isNotEmpty) {
      return dartMessage;
    }
    return readDailyCareJsProperty(root, 'message');
  }

  static String _normalizeCode(String code) {
    final String text = code.trim();
    const String prefix = 'firestore/';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length);
    }
    return text;
  }

  static String _readDartCode(Object error) {
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

  static String _readDartMessage(Object error) {
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

  /// Web transaction 會把 callback 裡的 Dart 例外裝進 JS Error.error。
  static Object unwrapRoot(Object error) {
    Object current = error;
    final Set<Object> seen = <Object>{};
    for (int depth = 0; depth < 4; depth++) {
      if (!seen.add(current)) {
        break;
      }
      final Object? inner = _innerError(current);
      if (inner == null) {
        break;
      }
      current = inner;
    }
    return current;
  }

  static Object? _innerError(Object error) {
    final Object? boxed = _unboxJsError(error);
    if (boxed != null) {
      return boxed;
    }
    try {
      final Object? inner = (error as dynamic).error;
      if (inner == null || identical(inner, error) || inner is String) {
        return null;
      }
      return inner;
    } catch (_) {
      return null;
    }
  }

  static Object? _unboxJsError(Object error) {
    try {
      return unboxDailyCareJsError(error);
    } catch (_) {
      return null;
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
    final Object root = unwrapRoot(error);
    if (kDebugMode) {
      debugRoot = root;
      debugRootType = root.runtimeType.toString();
      debugLabel = label;
      debugPrint(label);
      debugPrint('runtimeType=${error.runtimeType}');
      debugPrint('rootRuntimeType=${root.runtimeType}');
      debugPrint('safe=${safeToString(root)}');
      final String code = _readDartCode(root).isNotEmpty
          ? _normalizeCode(_readDartCode(root))
          : _normalizeCode(readDailyCareJsProperty(root, 'code'));
      final String message = _readDartMessage(root).isNotEmpty
          ? _readDartMessage(root)
          : readDailyCareJsProperty(root, 'message');
      if (code.isNotEmpty) {
        debugPrint('code=$code');
      }
      if (message.isNotEmpty) {
        debugPrint('message=$message');
      }
      if (!identical(root, error)) {
        debugPrint('outer=${safeToString(error)}');
      }
      if (stack != null) {
        debugPrint(safeToString(stack));
      }
    }
  }
}

class DailyCareSettingSaveException implements Exception {
  const DailyCareSettingSaveException(this.message, {this.code = ''});

  final String message;
  final String code;

  @override
  String toString() => message;

  static const String formatMessage = '設定資料格式異常，請重新載入後再試';
  static const String genericMessage = '儲存失敗，請稍後再試';

  static DailyCareSettingSaveException fromError(Object error) {
    final Object root = DailyCareSaveErrorProbe.unwrapRoot(error);
    if (root is DailyCareSettingSaveException) {
      return root;
    }
    final String code = DailyCareSaveErrorProbe.readCode(root);
    final String rawMessage = DailyCareSaveErrorProbe.readMessage(root);
    final String asString = DailyCareSaveErrorProbe.safeToString(root);
    final String combined = <String>[
      code,
      rawMessage,
      asString,
      root.runtimeType.toString(),
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
    if (_isFormatError(root, combined)) {
      return const DailyCareSettingSaveException(
        formatMessage,
        code: 'invalid-data',
      );
    }
    return const DailyCareSettingSaveException(genericMessage, code: 'unknown');
  }

  static bool _isFormatError(Object error, String combined) {
    if (error is ArgumentError ||
        error is TypeError ||
        error is FormatException ||
        error is NoSuchMethodError ||
        error is UnsupportedError) {
      return true;
    }
    return combined.contains('unsupported field') ||
        combined.contains('invalid-argument') ||
        combined.contains('invalid data') ||
        combined.contains('rangeerror') ||
        combined.contains('index out of range');
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

  static const List<String> _removedSettingKeys = <String>['welcomeText'];

  static const List<String> _removedDisplayKeys = <String>[
    'showRoomOrOffer',
    'showPetNames',
    'showServiceDate',
    'showFilledTime',
  ];

  static int readRevision(Object? raw) {
    if (raw is num) {
      if (raw.isNaN || raw.isInfinite) {
        return 0;
      }
      return raw.round();
    }
    final num? parsed = num.tryParse(
      DailyCareSaveErrorProbe.safeToString(raw).trim(),
    );
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return 0;
    }
    return parsed.round();
  }

  static int clampPaidReports(int reports) {
    if (reports < 1) {
      return 1;
    }
    if (reports > DailyCareReportMode.maxSessions) {
      return DailyCareReportMode.maxSessions;
    }
    return reports;
  }

  static int clampQuotaReports(int reports) {
    if (reports < 0) {
      return 0;
    }
    if (reports > DailyCareReportMode.maxSessions) {
      return DailyCareReportMode.maxSessions;
    }
    return reports;
  }

  static String _safeLabel(List<String> labels, int index) {
    try {
      if (index < 0 || index >= labels.length) {
        return '';
      }
      return labels[index].trim();
    } catch (_) {
      return '';
    }
  }

  static DailyCarePaidPlan preparePaidPlan(DailyCarePaidPlan plan) {
    final int reports = clampPaidReports(plan.reports);
    final List<String> labels = <String>[];
    final int limit =
        plan.sessionLabels.length < DailyCareReportMode.maxSessions
        ? plan.sessionLabels.length
        : DailyCareReportMode.maxSessions;
    for (int index = 0; index < limit; index++) {
      labels.add(_safeLabel(plan.sessionLabels, index));
    }
    return plan.copyWith(reports: reports, sessionLabels: labels);
  }

  static DailyCareOfferQuota prepareQuota(DailyCareOfferQuota quota) {
    final int reports = clampQuotaReports(quota.reports);
    final List<String> labels = <String>[];
    final int limit =
        quota.sessionLabels.length < DailyCareReportMode.maxSessions
        ? quota.sessionLabels.length
        : DailyCareReportMode.maxSessions;
    for (int index = 0; index < limit; index++) {
      labels.add(_safeLabel(quota.sessionLabels, index));
    }
    return DailyCareOfferQuota(
      configured: quota.configured,
      reports: reports,
      sessionLabels: labels,
    );
  }

  static Map<String, DailyCareOfferQuota> prepareQuotas(
    Map<String, DailyCareOfferQuota> quotas,
  ) {
    return quotas.map(
      (String key, DailyCareOfferQuota quota) =>
          MapEntry<String, DailyCareOfferQuota>(key, prepareQuota(quota)),
    );
  }

  /// 舊資料場次數量異常時先補成可寫入的範圍，不清空其他欄位。
  static DailyCareSettingModel prepareForSave(DailyCareSettingModel setting) {
    return setting.copyWith(
      stayPaidPlan: preparePaidPlan(setting.stayPaidPlan),
      daycarePaidPlan: preparePaidPlan(setting.daycarePaidPlan),
      stayOfferQuotas: prepareQuotas(setting.stayOfferQuotas),
      daycareOfferQuotas: prepareQuotas(setting.daycareOfferQuotas),
    );
  }

  static Map<String, dynamic> payloadForWrite(DailyCareSettingModel setting) {
    final DailyCareSettingModel safe = prepareForSave(setting).forShopWrite();
    final Map<String, dynamic> payload = sanitizeMap(safe.toMap());
    for (final String key in _removedSettingKeys) {
      payload.remove(key);
    }
    final Map<String, dynamic> display = payload['journalDisplay'] is Map
        ? Map<String, dynamic>.from(payload['journalDisplay'] as Map)
        : <String, dynamic>{};
    for (final String key in _removedDisplayKeys) {
      display.remove(key);
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
      return value.map(sanitize).where((Object? item) => item != null).toList();
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

  static const String incompatibleDaycareReportMessage =
      '安親目前是獨立時數／方案計費，不能使用依房型提供。請改選「固定提供」或「付費加購」後再儲存。原本的設定在按下儲存前不會被自動改寫。';

  /// 獨立時數／方案計費且回報已啟用時，不可保存依房型提供。
  static bool daycareReportModeIncompatible({
    required DailyCareSettingModel setting,
    required bool daycareRoomBased,
  }) {
    if (daycareRoomBased || !setting.daycareEnabled) {
      return false;
    }
    return DailyCareReportMode.normalize(setting.daycareReportMode) ==
        DailyCareReportMode.includedByOffer;
  }

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
    bool? daycareRoomBased,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }
    final bool rulesSection =
        section == DailyCareSettingSection.rules ||
        section == DailyCareSettingSection.all;
    if (rulesSection &&
        daycareRoomBased == false &&
        daycareReportModeIncompatible(
          setting: setting,
          daycareRoomBased: false,
        )) {
      throw const DailyCareSettingSaveException(
        incompatibleDaycareReportMessage,
        code: 'incompatible-daycare-mode',
      );
    }

    String step = 'prepare';
    int? currentRevision;
    Object? callbackError;
    StackTrace? callbackStack;
    try {
      final DailyCareSettingModel prepared =
          DailyCareSettingFirestoreValue.prepareForSave(setting);
      await _firestore.runTransaction((Transaction transaction) async {
        try {
          step = 'read';
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(_shopReference(normalizedShopId));
          final Object? raw = snapshot.data()?['dailyCareSetting'];
          step = 'revision';
          currentRevision = 0;
          if (raw is Map) {
            currentRevision = DailyCareSettingFirestoreValue.readRevision(
              raw['revision'],
            );
          }
          if (expectedRevision != null && expectedRevision != currentRevision) {
            throw const DailyCareSettingSaveException(
              '設定已被其他人更新，請重新載入後再儲存',
              code: 'revision-conflict',
            );
          }
          step = 'parse';
          final DailyCareSettingModel current = raw is Map
              ? DailyCareSettingModel.fromMap(
                  DailyCareSettingFirestoreValue.sanitizeMap(
                    DailyCareSettingFirestoreValue.copyRawMap(raw),
                  ),
                )
              : const DailyCareSettingModel();
          step = 'merge';
          final DailyCareSettingModel merged = _mergeSection(
            current: current,
            incoming: prepared,
            section: section,
          );
          final DailyCareSettingModel next = merged.copyWith(
            revision: currentRevision! + 1,
          );
          step = 'payload';
          final Map<String, dynamic> payload =
              DailyCareSettingFirestoreValue.payloadForWrite(next);
          payload['revision'] = currentRevision! + 1;
          if (kDebugMode) {
            debugPrint(
              'DailyCareSetting write shopId=$normalizedShopId '
              'section=$section expectedRevision=$expectedRevision '
              'currentRevision=$currentRevision',
            );
            debugPrint('writeFields=${payload.keys.toList()}');
          }
          step = 'write';
          transaction.set(_shopReference(normalizedShopId), <String, dynamic>{
            'dailyCareSetting': payload,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          step = 'done';
        } catch (error, stack) {
          callbackError = error;
          callbackStack = stack;
          DailyCareSaveErrorProbe.debugLog(
            'DailyCareSetting transaction failed '
            'step=$step section=$section shopId=$normalizedShopId '
            'expectedRevision=$expectedRevision currentRevision=$currentRevision',
            error,
            stack,
          );
          rethrow;
        }
      });
    } catch (error, stack) {
      final Object root =
          callbackError ?? DailyCareSaveErrorProbe.unwrapRoot(error);
      final StackTrace rootStack = callbackStack ?? stack;
      if (callbackError == null) {
        DailyCareSaveErrorProbe.debugLog(
          'DailyCareSetting save failed '
          'step=$step section=$section shopId=$normalizedShopId '
          'expectedRevision=$expectedRevision currentRevision=$currentRevision',
          root,
          rootStack,
        );
      }
      throw DailyCareSettingSaveException.fromError(root);
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
          pageBackgroundSource: incoming.pageBackgroundSource,
          pageBackgroundAssetId: incoming.pageBackgroundAssetId,
          cardDefaultSurfaceMode: incoming.cardDefaultSurfaceMode,
          cardDefaultBackgroundAssetId: incoming.cardDefaultBackgroundAssetId,
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
