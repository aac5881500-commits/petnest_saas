// 檔案名稱：lib/features/shop/pages/shop_public_page.dart
// 說明：前台店家頁（客戶看到的頁面）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';

class ShopPublicPage extends StatelessWidget {
  const ShopPublicPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('店家頁面'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: ShopService.instance.streamShop(shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('讀取失敗：${snapshot.error}'),
            );
          }

          final shop = snapshot.data;
          if (shop == null) {
            return const Center(
              child: Text('找不到店家'),
            );
          }

          final String coverUrl = (shop['coverUrl'] ?? '').toString();
          final String logoUrl = (shop['logoUrl'] ?? '').toString();

          final List<dynamic> rawServiceTypes = shop['serviceTypes'] ?? [];
          final List<String> serviceTypes =
              rawServiceTypes.map((e) => e.toString()).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// 封面圖
              if (coverUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    coverUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        color: Colors.grey.shade200,
                        child: const Text('封面載入失敗'),
                      );
                    },
                  ),
                ),

              if (coverUrl.isNotEmpty) const SizedBox(height: 16),

              /// Logo + 店名
              Row(
                children: [
                  if (logoUrl.isNotEmpty)
                    ClipOval(
                      child: Image.network(
                        logoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.store),
                          );
                        },
                      ),
                    ),

                  if (logoUrl.isNotEmpty) const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      shop['name'] ?? '未命名店家',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// 營業狀態
              Text(
                (shop['isOpen'] ?? false) ? '🟢 營業中' : '🔴 休息中',
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 8),

              /// 營業時間
              Text(
                '營業時間：${shop['businessHours'] ?? '未設定'}',
              ),

              const SizedBox(height: 16),

              /// 提供服務
              const Text(
                '提供服務',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (serviceTypes.contains('overnight')) const Text('✔ 住宿'),
              if (serviceTypes.contains('daycare')) const Text('✔ 日托'),
              if (serviceTypes.contains('grooming')) const Text('✔ 美容'),
              if (serviceTypes.contains('training')) const Text('✔ 訓練'),

              if (!serviceTypes.contains('overnight') &&
                  !serviceTypes.contains('daycare') &&
                  !serviceTypes.contains('grooming') &&
                  !serviceTypes.contains('training'))
                const Text('尚未設定'),

              const SizedBox(height: 24),

              /// 我要預約
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: serviceTypes.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopBookingPage(
                                shopId: shopId,
                              ),
                            ),
                          );
                        },
                  child: const Text('我要預約'),
                ),
              ),

              const SizedBox(height: 16),

              /// 地址
              Text('地址：${shop['address'] ?? ''}'),

              const SizedBox(height: 8),

              /// 電話
              Text('電話：${shop['phone'] ?? ''}'),

              const SizedBox(height: 16),

              /// 店家介紹
              const Text(
                '店家介紹',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                (shop['description'] ?? '').toString().isEmpty
                    ? '尚未提供介紹'
                    : shop['description'],
              ),
            ],
          );
        },
      ),
    );
  }
}