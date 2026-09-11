// 檔案名稱：lib/features/booking/widgets/booking_detail/daily_care_entitlement_snapshot.dart
// 功能說明：顧客端與後台共用的照護權益快照（不重算價格）。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';

class DailyCareEntitlementSnapshot extends StatelessWidget {
  const DailyCareEntitlementSnapshot({super.key, required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final Object? raw = booking['dailyCareEntitlement'];
    if (raw is! Map) {
      return const SizedBox.shrink();
    }
    final DailyCareEntitlement snap = DailyCareEntitlement.fromMap(
      Map<String, dynamic>.from(raw),
    );
    if (!snap.enabled && snap.finalReports <= 0 && snap.addonId.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '寵物寫真與照護回報',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            snap.finalReports > 0
                ? '已包含 ${snap.finalReports} 場：${snap.sessionLabels.join('、')}'
                : '未包含顧客照護回報',
          ),
          if (snap.addonId.isNotEmpty)
            Text(
              '加購 ${snap.addonName}：單價 ${ShopReportFormat.money(snap.unitPrice)}'
              ' × ${snap.quantity}'
              '${snap.amount > 0 ? '，小計 ${ShopReportFormat.money(snap.amount)}' : ''}',
            ),
          if (snap.serviceDates.isNotEmpty)
            Text('服務日期：${snap.serviceDates.first}～${snap.serviceDates.last}'),
          Text(snap.photoShareNote, style: const TextStyle(fontSize: 12, height: 1.4)),
          Text(
            snap.careDateRule,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
