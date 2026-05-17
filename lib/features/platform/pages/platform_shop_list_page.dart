// lib/features/platform/pages/platform_shop_list_page.dart
// 🏪 平台店家列表頁
// 功能：
// 1. 顯示所有公開店家
// 2. 點擊進入店家前台
// 3. 之後可擴充搜尋 / 篩選 / 排序

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';

class PlatformShopListPage extends StatelessWidget {
  const PlatformShopListPage({super.key});

String _businessTypeLabel(String value) {
  switch (value) {
    case 'cat_hotel':
      return '貓咪旅店';
    case 'dog_hotel':
      return '狗狗旅店';
    case 'grooming':
      return '美容';
    case 'hospital':
      return '動物醫院';
    case 'shop':
      return '寵物賣場';
    default:
      return '其他';
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('平台找店'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('isPublic', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('目前沒有公開店家'),
            );
          }

return GridView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: docs.length,

  gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 0.9,
  ),

  itemBuilder: (context, index) {
    final doc = docs[index];

    final data =
        doc.data() as Map<String, dynamic>;

    final city = data['city'] ?? '';
    final district = data['district'] ?? '';
    final coverUrl = data['coverUrl']?.toString() ?? '';
    final isOpen = data['isOpen'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(20),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopPublicPage(
              shopId: doc.id,
            ),
          ),
        );
      },

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Container(
  height: 90,
  width: double.infinity,
  decoration: BoxDecoration(
    color: Colors.grey.shade200,
    borderRadius: BorderRadius.circular(16),
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
            Icons.store,
            color: Colors.black26,
            size: 34,
          ),
        )
      : null,
),

            const SizedBox(height: 14),

            Text(
              data['name'] ?? '未命名店家',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '$city $district',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _businessTypeLabel(
                data['businessType']
                        ?.toString() ??
                    '',
              ),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),

              decoration: BoxDecoration(
                color: isOpen
                    ? Colors.green.shade50
                    : Colors.red.shade50,

                borderRadius:
                    BorderRadius.circular(30),
              ),

              child: Text(
                isOpen ? '營業中' : '休息中',

                style: TextStyle(
                  color: isOpen
                      ? Colors.green
                      : Colors.red,

                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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
    );
  }
}