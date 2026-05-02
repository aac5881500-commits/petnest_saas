// 🏠 HomePage（登入後首頁）
// lib/features/auth/pages/home_page.dart
// 功能：
// - 顯示目前登入使用者 Email
// - 提供建立店家按鈕
// - 顯示「我的店家列表」
// - 提供登出按鈕
//
// 用途：
// - 作為登入後的暫時首頁
// - 方便測試 shops / shop_members / 我的店家列表
// - 後面可再拆成真正後台首頁

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PetNest SaaS'),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService.instance.logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                /// 🌐 平台入口區（🔥新增）
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.only(bottom: 20),
  decoration: BoxDecoration(
    color: Colors.blue.shade50,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '歡迎使用 PetNest',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),

      /// 客戶入口
      const Text('🐱 找寵物旅館'),
      const SizedBox(height: 6),
      ElevatedButton(
        onPressed: () {
          // TODO: 之後做搜尋頁
        },
        child: const Text('前往找店'),
      ),

      const SizedBox(height: 12),

      /// 店主入口
      const Text('🏪 我要開店'),
      const SizedBox(height: 6),
      ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateShopPage(),
            ),
          );
        },
        child: const Text('建立店家'),
      ),
    ],
  ),
),

  /// 👤 使用者資訊卡
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '目前登入',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  ),

  const SizedBox(height: 20),

  /// ➕ 建立店家（主按鈕）
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateShopPage(),
          ),
        );
      },
      child: const Text(
        '➕ 建立新店家',
        style: TextStyle(fontSize: 16),
      ),
    ),
  ),

  const SizedBox(height: 24),

  /// 🏪 我的店家標題
  const Align(
    alignment: Alignment.centerLeft,
    child: Text(
      '我的店家',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),

  const SizedBox(height: 12),

  /// 🏪 店家列表
  Expanded(
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: ShopService.instance.getMyShops(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data ?? [];

        if (shops.isEmpty) {
          return const Center(child: Text('還沒有店家'));
        }

        return ListView.builder(
          itemCount: shops.length,
          itemBuilder: (context, index) {
            final shop = shops[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(shop['name'] ?? ''),
                subtitle: Text('角色：${shop['role']}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDashboardPage(
                        shopId: shop['shopId'],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    ),
  ),

],
            ),
          ),
        ),
      ),
    );
  }
}