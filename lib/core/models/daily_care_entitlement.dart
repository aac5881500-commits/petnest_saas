// 檔案名稱：lib/core/models/daily_care_entitlement.dart
// 功能說明：訂單下單時保存的照護回報權益快照。

import 'daily_care_report_mode.dart';

class DailyCareEntitlement {
  const DailyCareEntitlement({
    this.enabled = false,
    this.service = 'accommodation',
    this.mode = DailyCareReportMode.includedFixed,
    this.baseReports = 0,
    this.basePhotos = 0,
    this.addonId = '',
    this.addonName = '',
    this.addonDescription = '',
    this.addonReports = 0,
    this.addonPhotos = 0,
    this.unitPrice = 0,
    this.chargeUnit = DailyCareReportMode.chargePerServiceDay,
    this.quantity = 0,
    this.amount = 0,
    this.finalReports = 0,
    this.finalPhotos = 0,
    this.sessionLabels = const <String>[],
    this.offerId = '',
    this.offerName = '',
    this.careDateRule = stayCareDateRule,
    this.photoShareNote = DailyCareReportMode.photoShareNote,
    this.includeCheckInDay = true,
    this.includeCheckOutDay = false,
    this.serviceDates = const <String>[],
    this.photosPerSession = DailyCareReportMode.photosPerSession,
    this.photoRuleVersion = DailyCareReportMode.photoRuleVersion,
  });

  static const String stayCareDateRule = '回報日期依住宿晚數計算：入住日包含，退房日不包含。';
  static const String daycareCareDateRule = '每筆安親服務於服務當日提供回報。';

  final bool enabled;
  final String service;
  final String mode;
  final int baseReports;
  final int basePhotos;
  final String addonId;
  final String addonName;
  final String addonDescription;
  final int addonReports;
  final int addonPhotos;
  final int unitPrice;
  final String chargeUnit;
  final int quantity;
  final int amount;
  final int finalReports;
  final int finalPhotos;
  final List<String> sessionLabels;
  final String offerId;
  final String offerName;
  final String careDateRule;
  final String photoShareNote;
  final bool includeCheckInDay;
  final bool includeCheckOutDay;
  final List<String> serviceDates;
  final int photosPerSession;
  final int photoRuleVersion;

  bool get customerIncluded => enabled && finalReports > 0;

  bool get purchasedAddon => addonId.trim().isNotEmpty && amount >= 0;

  bool get isLegacyPhotoRule =>
      photoRuleVersion < DailyCareReportMode.photoRuleVersion;

  String sessionLabelAt(int index) {
    if (index >= 0 && index < sessionLabels.length) {
      final String label = sessionLabels[index].trim();
      if (label.isNotEmpty) {
        return label;
      }
    }
    return '';
  }

  String get dailyQuotaLine {
    if (addonReports > 0) {
      return '基本 $baseReports 場 + 加購 $addonReports 場 = 本日 $finalReports 場';
    }
    return '本日應回報 $finalReports 場';
  }

  factory DailyCareEntitlement.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DailyCareEntitlement();
    }
    final int version = _int(
      map['photoRuleVersion'],
      DailyCareReportMode.legacyPhotoRuleVersion,
    );
    return DailyCareEntitlement(
      enabled: map['enabled'] == true,
      service: (map['service'] ?? 'accommodation').toString(),
      mode: DailyCareReportMode.normalize(map['mode']?.toString()),
      baseReports: _int(map['baseReports']),
      basePhotos: _int(map['basePhotos']),
      addonId: (map['addonId'] ?? '').toString(),
      addonName: (map['addonName'] ?? '').toString(),
      addonDescription: (map['addonDescription'] ?? '').toString(),
      addonReports: _int(map['addonReports']),
      addonPhotos: _int(map['addonPhotos']),
      unitPrice: _int(map['unitPrice']),
      chargeUnit: DailyCareReportMode.normalizeChargeUnit(
        map['chargeUnit']?.toString(),
        daycare: (map['service'] ?? '').toString() == 'daycare',
      ),
      quantity: _int(map['quantity']),
      amount: _int(map['amount']),
      finalReports: _int(map['finalReports']),
      finalPhotos: _int(map['finalPhotos']),
      sessionLabels: DailyCareReportMode.readLabels(map['sessionLabels']),
      offerId: (map['offerId'] ?? '').toString(),
      offerName: (map['offerName'] ?? '').toString(),
      careDateRule: (map['careDateRule'] ?? stayCareDateRule).toString(),
      photoShareNote:
          (map['photoShareNote'] ?? DailyCareReportMode.photoShareNote)
              .toString(),
      includeCheckInDay: map['includeCheckInDay'] != false,
      includeCheckOutDay: map['includeCheckOutDay'] == true,
      serviceDates: DailyCareReportMode.readLabels(map['serviceDates']),
      photosPerSession: version >= DailyCareReportMode.photoRuleVersion
          ? DailyCareReportMode.photosPerSession
          : _int(map['photosPerSession'], 0),
      photoRuleVersion: version,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'service': service,
      'mode': mode,
      'baseReports': baseReports,
      'basePhotos': basePhotos,
      'addonId': addonId,
      'addonName': addonName,
      'addonDescription': addonDescription,
      'addonReports': addonReports,
      'addonPhotos': addonPhotos,
      'unitPrice': unitPrice,
      'chargeUnit': chargeUnit,
      'quantity': quantity,
      'amount': amount,
      'finalReports': finalReports,
      'finalPhotos': finalPhotos,
      'sessionLabels': sessionLabels,
      'offerId': offerId,
      'offerName': offerName,
      'careDateRule': careDateRule,
      'photoShareNote': photoShareNote,
      'includeCheckInDay': includeCheckInDay,
      'includeCheckOutDay': includeCheckOutDay,
      'serviceDates': serviceDates,
      'photosPerSession': photosPerSession,
      'photoRuleVersion': photoRuleVersion,
    };
  }

  Map<String, dynamic>? toAddonLine() {
    if (addonId.trim().isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'id': addonId,
      'name': addonName.isEmpty ? '寵物寫真與照護回報' : addonName,
      'type': DailyCareReportMode.addonLineType,
      'price': unitPrice,
      'count': quantity,
      'amount': amount,
      'total': amount,
      'chargeUnit': chargeUnit,
      'description': addonDescription,
      'extraReports': addonReports,
      'serviceDates': serviceDates,
    };
  }

  static int _int(Object? raw, [int fallback = 0]) {
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse('$raw') ?? fallback;
  }
}
