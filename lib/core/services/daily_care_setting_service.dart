// 檔案名稱：lib/core/services/daily_care_setting_service.dart
// 功能說明：讀取、監聽與儲存店家的每日照護紀錄設定。
// 🐾 每日照護紀錄設定 Service

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_care_setting_model.dart';

class DailyCareSettingService {
  DailyCareSettingService._();

  static final DailyCareSettingService instance = DailyCareSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _shopReference(String shopId) {
    return _firestore.collection('shops').doc(shopId);
  }

  /// 即時監聽每日照護紀錄設定
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
        Map<String, dynamic>.from(rawSetting),
      );
    });
  }

  /// 單次取得每日照護紀錄設定
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

    return DailyCareSettingModel.fromMap(Map<String, dynamic>.from(rawSetting));
  }

  /// 儲存每日照護紀錄設定（確認後才寫入；帶 revision 避免無提示覆蓋）
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

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(_shopReference(normalizedShopId));
      final Object? raw = snapshot.data()?['dailyCareSetting'];
      int currentRevision = 0;
      if (raw is Map && raw['revision'] is num) {
        currentRevision = (raw['revision'] as num).round();
      }
      if (expectedRevision != null && expectedRevision != currentRevision) {
        throw StateError('其他員工已更新照護設定，請重新載入後再儲存。');
      }
      final DailyCareSettingModel current = raw is Map
          ? DailyCareSettingModel.fromMap(Map<String, dynamic>.from(raw))
          : const DailyCareSettingModel();
      final DailyCareSettingModel merged = _mergeSection(
        current: current,
        incoming: setting,
        section: section,
      );
      final DailyCareSettingModel next = merged.copyWith(
        revision: currentRevision + 1,
      );
      transaction.set(_shopReference(normalizedShopId), <String, dynamic>{
        'dailyCareSetting': next.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
          stayReportMode: incoming.stayReportMode,
          stayOfferQuotas: incoming.stayOfferQuotas,
          includeCheckInDay: incoming.includeCheckInDay,
          includeCheckOutDay: incoming.includeCheckOutDay,
          stayPaidPlan: incoming.stayPaidPlan,
          daycareEnabled: incoming.daycareEnabled,
          daycareSessionCount: incoming.daycareSessionCount,
          daycareSessionLabels: incoming.daycareSessionLabels,
          daycareReportMode: incoming.daycareReportMode,
          daycareOfferQuotas: incoming.daycareOfferQuotas,
          daycarePaidPlan: incoming.daycarePaidPlan,
        );
      case DailyCareSettingSection.content:
        return current.copyWith(
          enabledFields: incoming.enabledFields,
          customFields: incoming.customFields,
        );
      case DailyCareSettingSection.appearance:
        return current.copyWith(
          logoVisible: incoming.logoVisible,
          logoAlign: incoming.logoAlign,
          logoSize: incoming.logoSize,
          titleFontSize: incoming.titleFontSize,
          bodyFontSize: incoming.bodyFontSize,
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
        );
      case DailyCareSettingSection.all:
        return incoming;
    }
  }
}

enum DailyCareSettingSection { rules, content, appearance, all }
