// lib/core/widgets/app_drawer.dart
// 🔥 店主 共用側邊選單 Drawer

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [

/// 🔥 會員中心（整合版）
Builder(
  builder: (context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
  return Column(
    children: [
      const SizedBox(height: 16),

      const Text(
        '會員中心',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),

      const SizedBox(height: 12),

      const Text('尚未登入'),

      const SizedBox(height: 12),

ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(context, '/login');
  },
  child: const Text('登入 / 註冊'),
),

      const SizedBox(height: 12),

      ListTile(
  leading: const Icon(Icons.home),
  title: const Text('回店家首頁'),
  onTap: () {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPublicPage(
          shopId: shopId,
        ),
      ),
      (route) => false,
    );
  },
),

      const Divider(),
    ],
  );
}

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        final name = data?['name'] ?? '';
        final phone = data?['phone'] ?? '';

        return Column(
          children: [
            const SizedBox(height: 16),

            const Text(
              '會員中心',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 12),

const SizedBox(height: 8),

/// 🔥 姓名
Text(
  name.isNotEmpty ? name : user.email ?? '',
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),

const SizedBox(height: 4),

/// 🔥 電話
Text(phone),

const SizedBox(height: 4),

/// 🔥 Email
Text(user.email ?? ''),

            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('會員資料'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/member');
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('登出'),
              onTap: () async {
  await FirebaseAuth.instance.signOut();
  Navigator.pop(context); // 只關 Drawer
},
            ),

            const Divider(),
          ],
        );
      },
    );
  },
),


            /// 👇 員工才顯示
            FutureBuilder<bool>(
              future: ShopService.instance.isEmployee(
                shopId: shopId,
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data != true) {
                  return const SizedBox();
                }

                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('回後台'),
onTap: () {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => ShopDashboardPage(
        shopId: shopId, // 🔥 關鍵
      ),
    ),
    (route) => false,
  );
},
                );
                
              },
            ),

            const Divider(),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('快速功能', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('我要預約'),
              onTap: () async {
                Navigator.pop(context);

                final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  Navigator.pushNamed(context, '/login');
  return;
}

                final hasAccepted =
                    await ShopService.instance.hasAcceptedPolicy(
                  shopId: shopId,
                  userId: user.uid,
                );

                if (!hasAccepted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopPolicyViewPage(
                        shopId: shopId,
                      ),
                    ),
                  );

                  if (result != true) return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ShopBookingPage(shopId: shopId),
                  ),
                );
              },
            ),

            ListTile(leading: const Icon(Icons.home), title: const Text('環境介紹')),
            ListTile(leading: const Icon(Icons.bed), title: const Text('房間介紹')),
            ListTile(leading: const Icon(Icons.info), title: const Text('入住須知')),
            ListTile(leading: const Icon(Icons.map), title: const Text('關於我們')),
            ListTile(leading: const Icon(Icons.star), title: const Text('評價')),

            const Divider(),

            ListTile(leading: const Icon(Icons.settings), title: const Text('功能設定')),

            const Divider(),

            ListTile(leading: const Icon(Icons.report), title: const Text('客戶申訴')),
            ListTile(leading: const Icon(Icons.bug_report), title: const Text('BUG回饋')),
          ],
        ),
      ),
    );
  }
}