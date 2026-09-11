// 檔案名稱：lib/features/shop/widgets/booking/daily_care_upgrade_card.dart
// 功能說明：獨立於一般加值服務的寵物寫真與照護回報選購卡。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_entitlement_math.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';

class DailyCareUpgradeCard extends StatelessWidget {
  const DailyCareUpgradeCard({
    super.key,
    required this.setting,
    required this.isDaycare,
    required this.shopDaycareOn,
    required this.offerId,
    required this.offerName,
    required this.nights,
    required this.selectedPlanId,
    required this.onChanged,
    this.startDate,
    this.endDate,
    this.plans = const [],
  });

  final DailyCareSettingModel setting;
  final bool isDaycare;
  final bool shopDaycareOn;
  final String offerId;
  final String offerName;
  final int nights;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedPlanId;
  final ValueChanged<String?> onChanged;

  /// 舊呼叫端相容，新規則不再使用共用加購清單。
  final List<dynamic> plans;

  String get _paidId => isDaycare
      ? DailyCareReportMode.daycarePaidId
      : DailyCareReportMode.stayPaidId;

  @override
  Widget build(BuildContext context) {
    DailyCareEntitlement base;
    try {
      base = DailyCareEntitlementMath.resolve(
        setting: setting,
        isDaycare: isDaycare,
        shopDaycareOn: shopDaycareOn,
        offerId: offerId,
        offerName: offerName,
        nights: nights,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (error) {
      return _box(
        child: Text(
          '$error',
          style: const TextStyle(color: Color(0xFFB42318), height: 1.4),
        ),
      );
    }
    final bool featureOn = isDaycare
        ? setting.daycareEnabled && shopDaycareOn
        : setting.enabled;
    if (!featureOn) {
      return const SizedBox.shrink();
    }
    final String mode = DailyCareReportMode.normalize(
      isDaycare ? setting.daycareReportMode : setting.stayReportMode,
    );
    final ThemeData theme = Theme.of(context);
    if (mode != DailyCareReportMode.paidAddon) {
      if (base.finalReports <= 0) {
        return const SizedBox.shrink();
      }
      return _box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '已包含照護回報',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isDaycare
                  ? '此筆安親已包含 ${base.finalReports} 場回報：${base.sessionLabels.join('、')}'
                  : '此住宿已包含每天 ${base.finalReports} 場回報：${base.sessionLabels.join('、')}',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              base.careDateRule,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              DailyCareReportMode.photoShareNote,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );
    }

    final DailyCarePaidPlan plan = isDaycare
        ? setting.daycarePaidPlan
        : setting.stayPaidPlan;
    DailyCareEntitlement upgraded;
    try {
      upgraded = DailyCareEntitlementMath.resolve(
        setting: setting,
        isDaycare: isDaycare,
        shopDaycareOn: shopDaycareOn,
        offerId: offerId,
        offerName: offerName,
        purchaseAddon: true,
        nights: nights,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (error) {
      return _box(child: Text('$error'));
    }
    final String unitLabel = isDaycare
        ? '每筆'
        : (upgraded.chargeUnit == DailyCareReportMode.chargeOncePerStay
              ? '整筆住宿一次'
              : '每個服務日');
    final String dateRange = upgraded.serviceDates.isEmpty
        ? '請先選擇服務日期'
        : '服務日期 ${upgraded.serviceDates.first}～${upgraded.serviceDates.last}（${upgraded.serviceDates.length} 天）';

    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '留住寶貝的度假日常',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isDaycare
                ? '店家不免費提供這項照護回報，購買後才享有回報及可附照片的服務。'
                : '店家不免費提供這項照護回報，購買後才享有回報及可附照片的服務。',
            style: const TextStyle(height: 1.4, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Text(dateRange, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            DailyCareReportMode.photoShareNote,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          RadioListTile<String?>(
            contentPadding: EdgeInsets.zero,
            value: null,
            groupValue: selectedPlanId,
            onChanged: onChanged,
            title: const Text('不加購'),
          ),
          RadioListTile<String?>(
            contentPadding: EdgeInsets.zero,
            value: _paidId,
            groupValue: selectedPlanId,
            onChanged: onChanged,
            title: Text(plan.name),
            subtitle: Text(
              '${plan.description.trim().isEmpty ? '購買後每天提供 ${upgraded.finalReports} 場回報。' : plan.description}\n'
              '回報：${upgraded.sessionLabels.join('、')}\n'
              '單價 ${ShopReportFormat.money(upgraded.unitPrice)}／$unitLabel'
              '${upgraded.chargeUnit == DailyCareReportMode.chargePerServiceDay ? ' × ${upgraded.quantity} 天' : ''}'
              '，小計 ${ShopReportFormat.money(upgraded.amount)}',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8C9A8)),
      ),
      child: child,
    );
  }
}
