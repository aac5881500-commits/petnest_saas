import 'booking_appearance_scope.dart';
import 'booking_editorial_design.dart';
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
        context,
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
    final ThemeData theme = _theme(context);
    if (mode != DailyCareReportMode.paidAddon) {
      if (base.finalReports <= 0) {
        return const SizedBox.shrink();
      }
      return _box(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_styled(context))
              BookingEditorial.heading('已包含照護回報')
            else
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
      return _box(context, child: Text('$error'));
    }
    final String unitLabel = isDaycare
        ? '每筆'
        : (upgraded.chargeUnit == DailyCareReportMode.chargeOncePerStay
              ? '整筆住宿一次'
              : '每個服務日');
    final bool priceReady = upgraded.serviceDates.isNotEmpty;
    final String dateRange = priceReady
        ? '服務日期 ${upgraded.serviceDates.first}～${upgraded.serviceDates.last}（${upgraded.serviceDates.length} 天）'
        : '請先完成服務選擇以計算價格';

    return _box(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_styled(context))
            BookingEditorial.heading('留住寶貝的度假日常')
          else
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
            style: _styled(context)
                ? BookingEditorial.body(14, context)
                : const TextStyle(height: 1.4, color: Colors.black54),
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
              priceReady
                  ? '${plan.description.trim().isEmpty ? '購買後每天提供 ${upgraded.finalReports} 場回報。' : plan.description}\n'
                        '回報：${upgraded.sessionLabels.join('、')}\n'
                        '單價 ${ShopReportFormat.money(upgraded.unitPrice)}／$unitLabel'
                        '${upgraded.chargeUnit == DailyCareReportMode.chargePerServiceDay ? ' × ${upgraded.quantity} 天' : ''}'
                        '，小計 ${ShopReportFormat.money(upgraded.amount)}'
                  : '請先完成服務選擇以計算價格',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  bool _styled(BuildContext context) =>
      !isDaycare &&
      const [
        'editorial',
        'cream',
      ].contains(BookingAppearanceScope.of(context).style);
  ThemeData _theme(BuildContext context) {
    final base = Theme.of(context);
    if (!_styled(context)) return base;
    final t = BookingEditorial.theme(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: t.primaryColor,
        onSurface: t.textColor,
        onSurfaceVariant: t.textColor.withValues(alpha: .8),
        surface: t.cardColor,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: BookingEditorial.body(14, context).fontFamily,
        bodyColor: t.textColor,
        displayColor: t.textColor,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: BookingEditorial.body(16, context),
        subtitleTextStyle: BookingEditorial.body(13, context),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.primaryColor
              : t.textColor.withValues(alpha: .55),
        ),
      ),
    );
  }

  Widget _box(BuildContext context, {required Widget child}) {
    final styled = _styled(context),
        cream = BookingAppearanceScope.of(context).style == 'cream';
    final t = styled ? BookingEditorial.theme(context) : null;
    return Container(
      key: styled
          ? ValueKey(
              'daily-care-upgrade-${BookingAppearanceScope.of(context).style}',
            )
          : null,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: styled && !cream
          ? const EdgeInsets.symmetric(vertical: 16)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: styled
            ? (cream ? t!.cardColor : Colors.transparent)
            : const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(styled ? (cream ? 24 : 0) : 16),
        border: styled
            ? (cream
                  ? Border.all(color: t!.cardBorderColor)
                  : Border(bottom: BorderSide(color: t!.cardBorderColor)))
            : Border.all(color: const Color(0xFFE8C9A8)),
      ),
      child: styled
          ? Theme(
              data: _theme(context),
              child: DefaultTextStyle.merge(
                style: BookingEditorial.body(14, context),
                child: child,
              ),
            )
          : child,
    );
  }
}
