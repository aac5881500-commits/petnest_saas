// lib/features/shop/widgets/booking/addon_item_card.dart
// 🔥 前台預約加值服務小卡：顯示加值服務名稱、說明、價格與選取狀態// lib/features/shop/widgets/booking/addon_item_card.dart
// 🔥 前台預約加值服務小卡：顯示加值服務名稱、說明、價格與選取狀態

import 'package:flutter/material.dart';

class AddonItemCard extends StatelessWidget {
  const AddonItemCard({
    super.key,
    required this.item,
    required this.isSelected,
  });

  final Map item;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ), 
      child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: isSelected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  item['desc'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+NT\$ ${item['price'] ?? 0}',
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}