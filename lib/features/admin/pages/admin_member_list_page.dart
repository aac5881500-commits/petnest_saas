// lib/features/admin/pages/admin_member_list_page.dart
// 👤 會員管理（穩定完整版🔥）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';

class AdminMemberListPage extends StatefulWidget {
  const AdminMemberListPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<AdminMemberListPage> createState() =>
      _AdminMemberListPageState();
}

class _AdminMemberListPageState extends State<AdminMemberListPage> {
  String keyword = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員管理')),
      body: Column(
        children: [
          /// 🔍 搜尋
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋姓名 / 電話',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  keyword = value.trim();
                });
              },
            ),
          ),

          /// 📦 列表
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
    .collection('bookings')
    .where('shopId', isEqualTo: widget.shopId)
    .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;

                final bookingDocs = snapshot.data!.docs;

final userMap = <String, Map<String, dynamic>>{};

for (final doc in bookingDocs) {
  final data = doc.data() as Map<String, dynamic>;

  final userId = data['userId'];

  if (userId == null) continue;

  userMap[userId] = {
    'userId': userId,
    'name': data['customerName'] ?? '',
    'phone': data['customerPhone'] ?? '',
    'email': data['customerEmail'] ?? '',
  };
}

final docs = userMap.values.where((data) {
  final name = (data['name'] ?? '').toString();
  final phone = (data['phone'] ?? '').toString();

  if (keyword.isEmpty) return true;

  return name.contains(keyword) ||
      phone.contains(keyword);
}).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('查無會員'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 🔥 一排2個
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];

final userId = data['userId']?.toString() ?? '';
final name = data['name']?.toString().isEmpty == true
    ? '未填姓名'
    : data['name'].toString();
final phone = data['phone']?.toString().isEmpty == true
    ? '未填電話'
    : data['phone'].toString();
final email = data['email']?.toString().isEmpty == true
    ? '無Email'
    : data['email'].toString();

                    final note1Controller =
                        TextEditingController(
                            text: data['adminNote1'] ?? '');
                    final note2Controller =
                        TextEditingController(
                            text: data['adminNote2'] ?? '');

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('user_profiles')
.doc(userId)
.collection('pets')
.get(),
                      builder: (context, petSnapshot) {
                        int petCount = 0;
                        if (petSnapshot.hasData) {
                          petCount =
                              petSnapshot.data!.docs.length;
                        }

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminMemberDetailPage(
  userId: userId,
),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(12),
                              child: Column(
                                children: [
  const Icon(Icons.person, size: 50),

  const SizedBox(height: 8),

  Text(
    name,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),

  Text(phone, style: const TextStyle(fontSize: 14)),

  Text(
    email,
    style: const TextStyle(
      fontSize: 12,
      color: Colors.grey,
    ),
  ),

  const SizedBox(height: 6),

  /// 🔴 黑名單（中間）
  if (data['isBlack'] == true)
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '黑名單',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    ),

  const SizedBox(height: 6),

  /// 🐱 寵物
  Text(
    '🐱 $petCount 隻',
    style: const TextStyle(fontSize: 14),
  ),

  const Spacer(), // 🔥 關鍵：往下推

  /// 🔥 備註1（下面）
  GestureDetector(
    onTap: () {},
    child: TextField(
      controller: note1Controller,
      decoration: const InputDecoration(
        hintText: '備註1',
        isDense: true,
      ),
      onSubmitted: (v) {
        FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(userId)
            .update({'adminNote1': v});
      },
    ),
  ),

  const SizedBox(height: 6),

  /// 🔥 備註2（最下面）
  GestureDetector(
    onTap: () {},
    child: TextField(
      controller: note2Controller,
      decoration: const InputDecoration(
        hintText: '備註2',
        isDense: true,
      ),
      onSubmitted: (v) {
        FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(userId)
            .update({'adminNote2': v});
      },
    ),
  ),
],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}