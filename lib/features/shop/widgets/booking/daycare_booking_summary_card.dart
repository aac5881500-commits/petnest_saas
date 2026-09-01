// lib/features/shop/widgets/booking/daycare_booking_summary_card.dart
// 🐾 臨托預約確認卡片：沿用住宿確認卡視覺

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class DaycareBookingSummaryCard extends StatelessWidget {
  const DaycareBookingSummaryCard({
    super.key,
    required this.dateText,
    required this.dropOffText,
    required this.pickUpText,
    required this.durationMinutes,
    required this.petCount,
    required this.petNames,
    required this.planName,
    required this.roomTypeName,
    required this.addons,
    required this.quote,
    this.couponName = '',
    this.campaignName = '',
  });

  final String dateText;
  final String dropOffText;
  final String pickUpText;
  final int durationMinutes;
  final int petCount;
  final List<String> petNames;
  final String planName;
  final String roomTypeName;
  final List<Map<String, dynamic>> addons;
  final DaycareQuote quote;
  final String couponName;
  final String campaignName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '預約確認',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _infoRow('臨托日期', dateText),
            const SizedBox(height: 6),
            _infoRow('送達時間', dropOffText),
            const SizedBox(height: 6),
            _infoRow('預計接回時間', pickUpText),
            const SizedBox(height: 6),
            _infoRow(
              '預計臨托時數',
              DaycareTimeHelper.durationLabel(durationMinutes),
            ),
            const SizedBox(height: 6),
            _infoRow(
              '寵物資料與數量',
              petNames.isEmpty
                  ? '$petCount 隻'
                  : '${petNames.join('、')}（$petCount 隻）',
            ),
            const SizedBox(height: 6),
            _infoRow('臨托方案', planName),
            const SizedBox(height: 6),
            _infoRow(
              '房間',
              roomTypeName.isEmpty ? '房間將由店家安排' : roomTypeName,
            ),
            if (addons.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                '加值服務',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...addons.map((Map<String, dynamic> addon) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _infoRow(
                    DaycareAddonCatalog.displayName(addon),
                    '+NT\$ ${addon['amount'] ?? addon['price'] ?? 0}',
                  ),
                );
              }),
            ],
            const Divider(),
            if (quote.surchargeAmount > 0) ...<Widget>[
              _infoRow('特殊日期加價', '+NT\$ ${quote.surchargeAmount}'),
              const SizedBox(height: 6),
            ],
            if (quote.discountAmount > 0 || quote.couponAmount > 0) ...<Widget>[
              _infoRow(
                '原價',
                'NT\$ ${quote.baseAmount + quote.extraPetAmount + quote.addonAmount + quote.surchargeAmount}',
              ),
              const SizedBox(height: 6),
            ],
            if (quote.discountAmount > 0) ...<Widget>[
              _infoRow(
                campaignName.trim().isEmpty ? '優惠活動折扣' : campaignName,
                '-NT\$ ${quote.discountAmount}',
              ),
              const SizedBox(height: 6),
            ],
            if (quote.couponAmount > 0) ...<Widget>[
              _infoRow(
                couponName.trim().isEmpty ? '優惠券折扣' : couponName,
                '-NT\$ ${quote.couponAmount}',
              ),
              const SizedBox(height: 6),
            ],
            if (quote.pointAmount > 0) ...<Widget>[
              _infoRow('點數折抵', '-NT\$ ${quote.pointAmount}'),
              const SizedBox(height: 6),
            ],
            _infoRow(
              (quote.discountAmount > 0 || quote.couponAmount > 0)
                  ? '折後總價'
                  : '總金額',
              'NT\$ ${quote.totalAmount}',
            ),
            if (quote.depositAmount > 0) ...<Widget>[
              const SizedBox(height: 6),
              _infoRow('本次應付訂金', 'NT\$ ${quote.depositAmount}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
