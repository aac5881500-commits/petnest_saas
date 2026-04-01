// lib/features/admin/pages/admin_member_detail_page.dart
// 👤 會員詳細頁（後台）完整版（含標籤系統）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMemberDetailPage extends StatelessWidget {
  const AdminMemberDetailPage({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員詳細')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔥 會員資料
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_profiles')
                  .doc(userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>?;

                if (data == null) {
                  return const Text('找不到會員資料');
                }

                final tags =
                    List<String>.from(data['tags'] ?? []);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// 👤 基本資料
                    Text(
                      '👤 ${data['name'] ?? '未填姓名'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text('📞 ${data['phone'] ?? '未填電話'}'),

                    const SizedBox(height: 8),

                    /// 🔥 標籤顯示
                    Row(
                      children: [
                        if (tags.contains('vip'))
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(label: Text('⭐ 常客')),
                          ),
                        if (tags.contains('blacklist'))
                          const Chip(
                            label: Text('🚫 黑名單'),
                            backgroundColor: Colors.red,
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// 🔥 按鈕（切換標籤）
                    Wrap(
                      spacing: 8,
                      children: [

                        /// ⭐ VIP
                        ElevatedButton(
                          onPressed: () async {
                            final ref = FirebaseFirestore.instance
                                .collection('user_profiles')
                                .doc(userId);

                            final snap = await ref.get();
                            final tags = List<String>.from(
                                snap.data()?['tags'] ?? []);

                            if (tags.contains('vip')) {
                              tags.remove('vip');
                            } else {
                              tags.add('vip');
                            }

                            await ref.update({'tags': tags});
                          },
                          child: const Text('⭐ 常客'),
                        ),

                        /// 🚫 黑名單
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () async {
                            final ref = FirebaseFirestore.instance
                                .collection('user_profiles')
                                .doc(userId);

                            final snap = await ref.get();
                            final tags = List<String>.from(
                                snap.data()?['tags'] ?? []);

                            if (tags.contains('blacklist')) {
                              tags.remove('blacklist');
                            } else {
                              tags.add('blacklist');
                            }

                            await ref.update({'tags': tags});
                          },
                          child: const Text('🚫 黑名單'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            /// 🐾 寵物
            const Text('🐾 寵物',
                style: TextStyle(fontWeight: FontWeight.bold)),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pets')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final pets = snapshot.data!.docs;

                if (pets.isEmpty) {
                  return const Text('無寵物資料');
                }

                return Column(
                  children: pets.map((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text(data['name'] ?? '寵物'),
                      subtitle: Text(data['type'] ?? ''),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            /// 📦 訂單
            const Text('📦 訂單',
                style: TextStyle(fontWeight: FontWeight.bold)),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final bookings = snapshot.data!.docs;

                if (bookings.isEmpty) {
                  return const Text('無訂單');
                }

                return Column(
                  children: bookings.map((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    final start = (data['startDate'] as Timestamp)
                        .toDate();
                    final end = (data['endDate'] as Timestamp)
                        .toDate();

                    return ListTile(
                      leading: const Icon(Icons.home),
                      title: Text(data['roomName'] ?? '房型'),
                      subtitle: Text(
                        '${start.year}-${start.month}-${start.day} ～ ${end.year}-${end.month}-${end.day}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}