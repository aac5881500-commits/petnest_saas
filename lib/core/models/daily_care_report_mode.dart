// 檔案名稱：lib/core/models/daily_care_report_mode.dart
// 功能說明：住宿／安親照護回報三種提供模式與每場照片上限。

class DailyCareReportMode {
  const DailyCareReportMode._();

  static const String includedFixed = 'included_fixed';
  static const String includedByOffer = 'included_by_offer';
  static const String paidAddon = 'paid_addon';

  static const int photosPerSession = 3;
  static const int maxSessions = 3;
  static const int retentionHours = 24;
  static const int photoRuleVersion = 2;
  static const int legacyPhotoRuleVersion = 1;
  static const int legacyMaxPhotosPerRoomPerDay = 6;

  static const String chargePerServiceDay = 'per_service_day';
  static const String chargeOncePerStay = 'once_per_stay';
  static const String chargePerVisit = 'per_visit';
  static const String chargePerNight = 'per_night';

  static const String addonLineType = 'daily_care';
  static const String stayPaidId = 'stay_paid';
  static const String daycarePaidId = 'daycare_paid';

  static const String photoShareNote =
      '每場回報可附最多 3 張照片；同場多隻寵物共用，不依寵物數加乘。服務結束後保留 24 小時，請及時下載。';

  static String normalize(String? raw) {
    switch ((raw ?? '').trim()) {
      case includedByOffer:
        return includedByOffer;
      case paidAddon:
        return paidAddon;
      default:
        return includedFixed;
    }
  }

  static String normalizeChargeUnit(String? raw, {bool daycare = false}) {
    switch ((raw ?? '').trim()) {
      case chargeOncePerStay:
        return chargeOncePerStay;
      case chargePerVisit:
        return chargePerVisit;
      case chargePerNight:
        return daycare ? chargePerVisit : chargePerServiceDay;
      case chargePerServiceDay:
        return chargePerServiceDay;
      default:
        return daycare ? chargePerVisit : chargePerServiceDay;
    }
  }

  static int clampReports(Object? raw, [int fallback = 1]) {
    final int parsed = raw is num
        ? raw.round()
        : int.tryParse('$raw') ?? fallback;
    if (parsed < 1) {
      return 1;
    }
    if (parsed > maxSessions) {
      return maxSessions;
    }
    return parsed;
  }

  static List<String> readLabels(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((Object? item) => item.toString().trim())
        .toList(growable: false);
  }

  static List<String> padLabels(List<String> labels, int count) {
    return List<String>.generate(count, (int index) {
      if (index < labels.length && labels[index].trim().isNotEmpty) {
        return labels[index].trim();
      }
      return '第 ${index + 1} 次照護';
    });
  }

  static String stayModeLabel(String mode) {
    switch (normalize(mode)) {
      case includedByOffer:
        return '依房型提供';
      case paidAddon:
        return '付費加購';
      default:
        return '固定提供';
    }
  }

  static String daycareModeLabel(String mode, {required bool roomBased}) {
    switch (normalize(mode)) {
      case includedByOffer:
        return roomBased ? '依房型提供' : '依方案提供';
      case paidAddon:
        return '付費加購';
      default:
        return '固定提供';
    }
  }

  static String chargeLabel(String unit) {
    switch (normalizeChargeUnit(unit)) {
      case chargeOncePerStay:
        return '整筆住宿收費一次';
      case chargePerVisit:
        return '每筆計費';
      default:
        return '每日計費';
    }
  }
}
