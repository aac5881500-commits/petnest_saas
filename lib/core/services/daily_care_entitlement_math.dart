// 檔案名稱：lib/core/services/daily_care_entitlement_math.dart
// 功能說明：依店家設定計算照護權益與金額；每日計費依服務日期，不暗中改用晚數。

import '../models/daily_care_date_helper.dart';
import '../models/daily_care_entitlement.dart';
import '../models/daily_care_offer_quota.dart';
import '../models/daily_care_paid_plan.dart';
import '../models/daily_care_report_mode.dart';
import '../models/daily_care_setting_model.dart';

class DailyCareEntitlementMath {
  DailyCareEntitlementMath._();

  static DailyCareEntitlement resolve({
    required DailyCareSettingModel setting,
    required bool isDaycare,
    required bool shopDaycareOn,
    String offerId = '',
    String offerName = '',
    bool purchaseAddon = false,
    DateTime? startDate,
    DateTime? endDate,
    int nights = 1,
  }) {
    final bool featureOn = isDaycare
        ? setting.daycareEnabled && shopDaycareOn
        : setting.enabled;
    final String mode = DailyCareReportMode.normalize(
      isDaycare ? setting.daycareReportMode : setting.stayReportMode,
    );
    final List<DateTime> dates = isDaycare
        ? DailyCareDateHelper.daycareCareDates(serviceDate: startDate)
        : DailyCareDateHelper.careDates(
            checkIn: startDate,
            checkOut: endDate,
          );
    final List<String> serviceDateKeys = dates
        .map(DailyCareDateHelper.dateKey)
        .toList();

    int reports = 0;
    List<String> labels = const <String>[];
    String addonId = '';
    String addonName = '';
    String addonDescription = '';
    String chargeUnit = isDaycare
        ? DailyCareReportMode.chargePerVisit
        : DailyCareReportMode.chargePerServiceDay;
    int unitPrice = 0;
    int quantity = 0;
    int amount = 0;

    if (!featureOn) {
      return DailyCareEntitlement(
        enabled: false,
        service: isDaycare ? 'daycare' : 'accommodation',
        mode: mode,
        serviceDates: serviceDateKeys,
        photoRuleVersion: DailyCareReportMode.photoRuleVersion,
        photosPerSession: DailyCareReportMode.photosPerSession,
      );
    }

    if (mode == DailyCareReportMode.paidAddon) {
      if (purchaseAddon) {
        final DailyCarePaidPlan plan = isDaycare
            ? setting.daycarePaidPlan
            : setting.stayPaidPlan;
        reports = plan.reports;
        labels = plan.resolvedLabels();
        addonId = isDaycare
            ? DailyCareReportMode.daycarePaidId
            : DailyCareReportMode.stayPaidId;
        addonName = plan.name;
        addonDescription = plan.description;
        chargeUnit = isDaycare
            ? DailyCareReportMode.chargePerVisit
            : DailyCareReportMode.normalizeChargeUnit(plan.chargeUnit);
        unitPrice = plan.price;
        if (isDaycare) {
          quantity = 1;
        } else if (chargeUnit == DailyCareReportMode.chargeOncePerStay) {
          quantity = 1;
        } else {
          quantity = serviceDateKeys.isNotEmpty
              ? serviceDateKeys.length
              : (nights < 1 ? 1 : nights);
        }
        amount = unitPrice * quantity;
      }
    } else if (mode == DailyCareReportMode.includedByOffer) {
      if (offerId.trim().isEmpty) {
        throw StateError('請先選擇房型或方案，才能確認照護回報場次。');
      }
      final DailyCareOfferQuota? quota = isDaycare
          ? setting.daycareOfferQuotas[offerId]
          : setting.stayOfferQuotas[offerId];
      if (quota == null || !quota.configured || quota.reports < 1) {
        throw StateError('此房型／方案尚未設定照護回報場次，請先完成回報規則。');
      }
      reports = quota.reports;
      labels = quota.resolvedLabels();
    } else {
      reports = isDaycare ? setting.daycareSessionCount : setting.sessionCount;
      labels = isDaycare
          ? setting.resolvedDaycareSessionLabelsForCount(reports)
          : setting.resolvedStaySessionLabelsForCount(reports);
    }

    if (reports > DailyCareReportMode.maxSessions) {
      throw StateError('回報場次不可超過 ${DailyCareReportMode.maxSessions} 場。');
    }

    final int photosPerSession = DailyCareReportMode.photosPerSession;
    return DailyCareEntitlement(
      enabled: featureOn && (reports > 0 || mode == DailyCareReportMode.paidAddon),
      service: isDaycare ? 'daycare' : 'accommodation',
      mode: mode,
      baseReports: purchaseAddon ? 0 : reports,
      basePhotos: 0,
      addonId: addonId,
      addonName: addonName,
      addonDescription: addonDescription,
      addonReports: purchaseAddon ? reports : 0,
      addonPhotos: 0,
      unitPrice: unitPrice,
      chargeUnit: chargeUnit,
      quantity: addonId.isEmpty ? 0 : quantity,
      amount: addonId.isEmpty ? 0 : amount,
      finalReports: reports,
      finalPhotos: reports * photosPerSession,
      sessionLabels: labels,
      offerId: offerId,
      offerName: offerName,
      careDateRule: isDaycare
          ? DailyCareEntitlement.daycareCareDateRule
          : _stayRule(chargeUnit),
      photoShareNote: DailyCareReportMode.photoShareNote,
      includeCheckInDay: true,
      includeCheckOutDay: false,
      serviceDates: serviceDateKeys,
      photosPerSession: photosPerSession,
      photoRuleVersion: DailyCareReportMode.photoRuleVersion,
    );
  }

  static String _stayRule(String chargeUnit) {
    const String days = '回報日期依住宿晚數計算：入住日包含，退房日不包含。';
    if (chargeUnit == DailyCareReportMode.chargeOncePerStay) {
      return '整筆住宿收費一次；服務日期仍每天提供設定場次。$days';
    }
    return '每日費用依實際包含的服務日期計算。$days';
  }

  static DailyCareEntitlement fallbackFromSetting({
    required DailyCareSettingModel setting,
    required bool isDaycare,
    required Map<String, dynamic> booking,
  }) {
    final Object? raw = booking['dailyCareEntitlement'];
    if (raw is Map) {
      return DailyCareEntitlement.fromMap(Map<String, dynamic>.from(raw));
    }
    final bool enabled = isDaycare ? setting.daycareEnabled : setting.enabled;
    final int reports = isDaycare
        ? setting.daycareSessionCount
        : setting.sessionCount;
    return DailyCareEntitlement(
      enabled: enabled,
      service: isDaycare ? 'daycare' : 'accommodation',
      mode: DailyCareReportMode.includedFixed,
      baseReports: reports,
      finalReports: enabled ? reports : 0,
      finalPhotos: enabled
          ? DailyCareReportMode.legacyMaxPhotosPerRoomPerDay
          : 0,
      sessionLabels: isDaycare
          ? setting.resolvedDaycareSessionLabels()
          : setting.resolvedSessionLabels(),
      photosPerSession: 0,
      photoRuleVersion: DailyCareReportMode.legacyPhotoRuleVersion,
      careDateRule: isDaycare
          ? DailyCareEntitlement.daycareCareDateRule
          : DailyCareEntitlement.stayCareDateRule,
    );
  }
}
