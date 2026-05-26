// lib/features/auth/widgets/my_shop_info.dart
// 🏪 我的店家資訊區塊
// 功能：顯示店名、店家類型、地區資訊

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyShopInfo extends StatelessWidget {
 const MyShopInfo({
  super.key,
  required this.shopName,
  required this.businessType,
  required this.city,
  required this.district,
  required this.shopId,
});

  final String shopName;
  final String businessType;
  final String city;
  final String district;
  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          shopName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

const SizedBox(height: 6),

InkWell(
  borderRadius: BorderRadius.circular(8),
  onTap: () async {
    await Clipboard.setData(
      ClipboardData(text: shopId),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('店家 ID 已複製'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  },
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 5,
    ),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.copy_rounded,
          size: 14,
          color: Colors.grey.shade700,
        ),

        const SizedBox(width: 5),

        Text(
  'ID：$shopId',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    ),
  ),
),


        const SizedBox(height: 8),
        

        Row(
          children: [
            const Icon(
              Icons.pets,
              size: 16,
              color: Colors.black45,
            ),

            const SizedBox(width: 6),

            Text(
              businessType,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            const Icon(
              Icons.location_on,
              size: 16,
              color: Colors.black45,
            ),

            const SizedBox(width: 6),

            Text(
              '$city $district',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}