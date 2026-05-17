// 🏠 HomePage（登入後首頁）
// lib/features/auth/pages/home_page.dart
// 功能：登入後首頁、建立店家、我的店家列表、登出

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<Map<String, dynamic>>>? _shopsFuture;

  @override
void initState() {
  super.initState();

  _shopsFuture = ShopService.instance.getMyShops();
}

  Future<void> _reloadShops() async {
  setState(() {
    _shopsFuture = ShopService.instance.getMyShops();
  });
}

  Future<void> _openCreateShopPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateShopPage(),
      ),
    );

    if (!mounted) return;

   await _reloadShops();
  }

String _businessTypeLabel(String value) {
  switch (value) {
    case 'cat_hotel':
      return '貓咪旅館';
    case 'dog_hotel':
      return '狗狗旅館';
    case 'grooming':
      return '寵物美容';
    case 'hospital':
      return '動物醫院';
    case 'shop':
      return '寵物賣場';
    default:
      return '其他服務';
  }
}

String _roleLabel(String value) {
  switch (value) {
    case 'owner':
      return '店主';
    case 'manager':
      return '主管';
    case 'staff':
      return '員工';
    default:
      return value;
  }
}

  Future<void> _logout() async {
    await AuthService.instance.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PetNest SaaS'),
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 18),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目前登入',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('登出'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                      const Text('🐱 找寵物旅館'),
                      const SizedBox(height: 6),
                      ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlatformShopListPage(),
      ),
    );
  },
  child: const Text('前往找店'),
),
                      const SizedBox(height: 12),
                      const Text('🏪 我要開店'),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: _openCreateShopPage,
                        child: const Text('建立店家'),
                      ),
                    ],
                  ),
                ),

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

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _openCreateShopPage,
                    child: const Text(
                      '➕ 建立新店家',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

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

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _shopsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final shops = snapshot.data ?? [];

                      if (shops.isEmpty) {
                        return const Center(child: Text('還沒有店家'));
                      }

                      return ListView.builder(
                        itemCount: shops.length,
                        itemBuilder: (context, index) {
                          final shop = shops[index];
final coverUrl = shop['coverUrl']?.toString() ?? '';
final city = shop['city']?.toString() ?? '';
final district = shop['district']?.toString() ?? '';
final isOpen = shop['isOpen'] == true;
final isPublic = shop['isPublic'] == true;

final businessType = _businessTypeLabel(
  shop['businessType']?.toString() ?? '',
);

final role = _roleLabel(
  shop['role']?.toString() ?? '',
);
return InkWell(
  borderRadius: BorderRadius.circular(22),
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
  child: Container(
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 135,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                image: coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: coverUrl.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.storefront,
                        size: 44,
                        color: Colors.black26,
                      ),
                    )
                  : null,
            ),

            Positioned(
              left: 14,
              top: 14,
              child: _HomeBadge(
                text: isOpen ? '營業中' : '休息中',
                icon: Icons.circle,
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop['name'] ?? '未命名店家',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HomeBadge(
                          text: role,
                          icon: Icons.admin_panel_settings,
                        ),
                        _HomeBadge(
                          text: isPublic ? '平台顯示' : '未公開',
                          icon: Icons.visibility,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

Row(
  children: [
    Expanded(
      child: _HomeInfoCard(
        icon: Icons.receipt_long,
        title: '今日訂單',
        value: '0',
      ),
    ),

    const SizedBox(width: 10),

    Expanded(
      child: _HomeInfoCard(
        icon: Icons.schedule,
        title: '待確認',
        value: '0',
      ),
    ),

    const SizedBox(width: 10),

    Expanded(
      child: _HomeInfoCard(
        icon: Icons.people,
        title: '會員數',
        value: '0',
      ),
    ),
  ],
),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                size: 34,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ],
    ),
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

class _HomeInfoCard extends StatelessWidget {
  const _HomeInfoCard({
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.orange.shade400,
            size: 22,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBadge extends StatelessWidget {
  const _HomeBadge({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}