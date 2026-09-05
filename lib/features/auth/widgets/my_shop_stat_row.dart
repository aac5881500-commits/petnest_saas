// 檔案名稱：lib/features/auth/widgets/my_shop_stat_row.dart
// 功能說明：顯示店家首頁卡片底部統計：待確認、已轉帳回傳、會員數
// 📊 我的店家統計列

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_home_stats_service.dart';

class MyShopStatRow extends StatelessWidget {
  const MyShopStatRow({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: ShopHomeStatsService.instance.getShopHomeStats(shopId),
      builder: (context, statsSnapshot) {
        final stats =
            statsSnapshot.data ??
            {'pendingOrders': 0, 'transferUploadedOrders': 0, 'memberCount': 0};

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.schedule,
                title: '待確認',
                value: '${stats['pendingOrders'] ?? 0}',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatCard(
                icon: Icons.upload_file,
                title: '已轉帳回傳',
                value: '${stats['transferUploadedOrders'] ?? 0}',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatCard(
                icon: Icons.people,
                title: '會員數',
                value: '${stats['memberCount'] ?? 0}',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.orange.shade400, size: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
