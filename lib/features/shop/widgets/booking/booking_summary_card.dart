// lib/features/shop/widgets/booking/booking_summary_card.dart
// 🔥 前台預約確認卡片：顯示入住日、退房日、晚數、寵物數量、房型、加值服務與總價

import 'package:flutter/material.dart';

class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.startDateText,
    required this.endDateText,
    required this.nights,
    required this.petCount,
    required this.roomTypeName,
    required this.totalPrice,
    this.originalTotal,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.discountMinNights = 0,
    this.discountBase = '',
    required this.timeAddon,
    required this.valueServices,
    required this.customServices,
    required this.customServicePrices,
  });

  final String startDateText;
  final String endDateText;
  final int nights;
  final int petCount;
  final String roomTypeName;
  final int totalPrice;
  final int? originalTotal;
  final int discountAmount;
  final int discountPercent;
  final int discountMinNights;
  final String discountBase;
  final Map<String, dynamic>? timeAddon;
  final List<Map<String, dynamic>> valueServices;
  final Map<String, List<String>> customServices;
  final Map<String, int> customServicePrices;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '預約確認',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _infoRow('入住日', startDateText),
            const SizedBox(height: 6),

            _infoRow('退房日', endDateText),
            const SizedBox(height: 6),

            _infoRow('晚數', '$nights 晚'),
            const SizedBox(height: 6),

            _infoRow('寵物數量', '$petCount 隻'),
            const SizedBox(height: 6),

            _infoRow('房型', roomTypeName),
            const SizedBox(height: 6),

            if (timeAddon != null)
              _infoRow('時間加購', '+NT\$ ${timeAddon!['price'] ?? 0}'),

            if (valueServices.isNotEmpty)
              ...valueServices.map(
                (e) => _infoRow(e['name'] ?? '', '+NT\$ ${e['price'] ?? 0}'),
              ),

            if (customServices.isNotEmpty)
              ...customServices.entries.map((entry) {
                final name = entry.key;
                final count = entry.value.length;
                final price = customServicePrices[name] ?? 0;

                return _infoRow('$name ($count隻)', '+NT\$ ${price * count}');
              }),

            const Divider(),

            if (discountAmount > 0 && originalTotal != null) ...[
              _infoRow('原價', 'NT\$ $originalTotal'),
              const SizedBox(height: 6),
              _infoRow('長住優惠', '滿 $discountMinNights 晚折扣 $discountPercent%'),
              const SizedBox(height: 6),
              _infoRow('折扣範圍', _discountBaseText()),
              const SizedBox(height: 6),
              _infoRow('折扣金額', '-NT\$ $discountAmount'),
              const SizedBox(height: 6),
            ],

            _infoRow(discountAmount > 0 ? '折後總價' : '總價', 'NT\$ $totalPrice'),
          ],
        ),
      ),
    );
  }

  String _discountBaseText() {
    switch (discountBase) {
      case 'room':
        return '只折房價';
      case 'room_pet':
        return '房價＋寵物加價';
      case 'total':
        return '總金額（含加值服務）';
      default:
        return '長住優惠';
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
