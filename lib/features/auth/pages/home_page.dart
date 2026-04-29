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
              mainAxisSize: MainAxisSize.min,
              children: [
                /// 登入資訊
                const Text('登入成功'),
                const SizedBox(height: 8),
                Text(user?.email ?? '無法取得 Email'),
                const SizedBox(height: 24),

                /// 建立店家按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final shopId = await ShopService.instance.createShop(
                          name: '我的第一間店',
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('店家建立成功：$shopId')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('建立失敗：$e')),
                        );
                      }
                    },
                    child: const Text('建立店家'),
                  ),
                ),

                const SizedBox(height: 24),

                /// 我的店家列表標題
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '我的店家',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                /// 我的店家列表
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ShopService.instance.getMyShops(),
                  builder: (context, snapshot) {
                    /// 載入中
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    /// 發生錯誤
                    if (snapshot.hasError) {
                      return Text('錯誤：${snapshot.error}');
                    }

                    /// 取得資料
                    final shops = snapshot.data ?? [];

                    /// 沒有店家
                    if (shops.isEmpty) {
                      return const Text('目前沒有店家');
                    }

                    /// 顯示店家列表
                    return Column(
  children: shops.map((shop) {
    return Card(
      child: ListTile(
        title: Text(shop['name'] ?? '未命名店家'),
        subtitle: Text('角色：${shop['role'] ?? '-'}'),

        /// 🔥 加這段（關鍵）
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
  }).toList(),
);
                  },
                ),

                const SizedBox(height: 24),

                /// 登出按鈕
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await AuthService.instance.logout();
                    },
                    child: const Text('登出'),
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