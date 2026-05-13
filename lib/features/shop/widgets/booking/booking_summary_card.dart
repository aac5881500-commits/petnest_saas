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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
              _infoRow(
                '時間加購',
                '+NT\$ ${timeAddon!['price'] ?? 0}',
              ),

            if (valueServices.isNotEmpty)
              ...valueServices.map(
                (e) => _infoRow(
                  e['name'] ?? '',
                  '+NT\$ ${e['price'] ?? 0}',
                ),
              ),

            if (customServices.isNotEmpty)
              ...customServices.entries.map((entry) {
                final name = entry.key;
                final count = entry.value.length;
                final price = customServicePrices[name] ?? 0;

                return _infoRow(
                  '$name ($count隻)',
                  '+NT\$ ${price * count}',
                );
              }),

            const Divider(),

            _infoRow('總價', 'NT\$ $totalPrice'),
          ],
        ),
      ),
    );
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