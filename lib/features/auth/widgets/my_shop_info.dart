// 檔案名稱：lib/features/auth/widgets/my_shop_info.dart
// 功能說明：顯示店名、地區、服務類型，以及較淡的店家編號。
// 🏪 我的店家資訊區塊

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyShopInfo extends StatelessWidget {
  const MyShopInfo({
    super.key,
    required this.shopName,
    required this.city,
    required this.district,
  });

  final String shopName;
  final String city;
  final String district;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String left = city.trim();
    final String right = district.trim();
    final String place = left.isEmpty
        ? right
        : (right.isEmpty ? left : '$left・$right');
    final double width = MediaQuery.sizeOf(context).width;
    final double nameSize = width >= 1100 ? 30 : (width >= 700 ? 27 : 25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          shopName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.headlineSmall?.copyWith(
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if (place.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  place,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class MyShopIdLine extends StatelessWidget {
  const MyShopIdLine({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color muted = colors.onSurfaceVariant.withValues(alpha: 0.78);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.tag_outlined, size: 13, color: muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '店家編號 $shopId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: muted, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
