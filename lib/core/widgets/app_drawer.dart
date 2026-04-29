// lib/core/widgets/app_drawer.dart
// 🔥 共用側邊選單 Drawer

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';

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

            const ListTile(
              title: Text('選單', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('回到首頁'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
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
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin');
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
                if (user == null) return;

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

            ListTile(leading: const Icon(Icons.person), title: const Text('會員')),
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