// 檔案名稱：lib/features/auth/widgets/my_shop_info.dart
// 功能說明：顯示店名、店家類型、地區、店家 ID
// 🏪 我的店家資訊區塊

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
    required this.shopCode,
  });

  final String shopName;
  final String businessType;
  final String city;
  final String district;
  final String shopId;
  final String shopCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shopName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 2),

        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: shopId));

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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy_rounded, size: 14, color: Colors.grey.shade700),

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

        const SizedBox(height: 4),

        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.black45),

            const SizedBox(width: 6),

            Expanded(
              child: Text(
                '$city $district',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
