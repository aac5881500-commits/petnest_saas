// lib/features/member/pages/member_detail_page.dart
// 👤 後台會員詳細頁（完整版 UI + 功能升級🔥）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';

class AdminMemberDetailPage extends StatelessWidget {
  const AdminMemberDetailPage({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('會員詳細')),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ===============================
            /// 👤 會員資料
            /// ===============================
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_profiles')
                  .doc(userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>?;

                if (data == null) {
                  return const Text('找不到會員資料');
                }

                final tags = List<String>.from(data['tags'] ?? []);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// 👤 名字
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            data['name'] ?? '未填姓名',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// 📧 Email（🔥 新增）
                      Row(
                        children: [
                          const Icon(Icons.email, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            currentUser?.email ?? '未填Email',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      /// 📞 電話
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            data['phone'] ?? '未填電話',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      /// 🏠 地址
                      Row(
                        children: [
                          const Icon(Icons.home, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data['address'] ?? '未填地址',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// 🚨 緊急聯絡人
                      const Text(
                        '緊急聯絡人',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('👤 ${data['emergencyContact']?['name'] ?? '未填'}', style: const TextStyle(fontSize: 16)),
                            Text('📞 ${data['emergencyContact']?['phone'] ?? '未填'}', style: const TextStyle(fontSize: 16)),
                            Text('🤝 ${data['emergencyContact']?['relation'] ?? '未填'}', style: const TextStyle(fontSize: 16)),
                            Text('🏠 ${data['emergencyContact']?['address'] ?? '未填'}', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// 🏷️ 標籤
                      Wrap(
                        spacing: 8,
                        children: [
                          if (tags.contains('vip'))
                            const Chip(label: Text('⭐ 常客')),
                          if (tags.contains('blacklist'))
                            const Chip(
                              label: Text('🚫 黑名單'),
                              backgroundColor: Colors.red,
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// 🔘 操作按鈕
                      Row(
                        children: [

                          Expanded(
                            child: ElevatedButton.icon(
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
                              icon: const Icon(Icons.star),
                              label: const Text('常客'),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: ElevatedButton.icon(
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
                              icon: const Icon(Icons.block),
                              label: const Text('黑名單'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            /// ===============================
            /// 🐾 寵物
            /// ===============================
            const Text(
              '🐾 寵物',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),

            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_profiles')
                  .doc(userId)
                  .collection('pets')
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
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PetDetailPage(
        pet: data,
        isAdminView: true,
      ),
    ),
  );
},
                        leading: data['photoUrl'] != null &&
                                data['photoUrl'] != ''
                            ? CircleAvatar(
                                backgroundImage:
                                    NetworkImage(data['photoUrl']),
                              )
                            : const CircleAvatar(
                                child: Icon(Icons.pets),
                              ),
                        title: Row(
  children: [
    Text(
      data['name'] ?? '寵物',
      style: const TextStyle(fontSize: 18),
    ),
    const SizedBox(width: 6),
    const Icon(Icons.lock, size: 16, color: Colors.grey),
  ],
),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['type'] ?? ''),
                            Text('年齡：${data['age'] ?? '未填'}'),
                            Text('性別：${data['gender'] ?? '未填'}'),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            /// ===============================
            /// 📦 訂單
            /// ===============================
            const Text(
              '📦 訂單',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),

            const SizedBox(height: 10),

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
                    final data = doc.data() as Map<String, dynamic>;

                    final start =
                        (data['startDate'] as Timestamp).toDate();
                    final end =
                        (data['endDate'] as Timestamp).toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.home),
                        title: Text(
                          data['roomName'] ?? '房型',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '${start.year}-${start.month}-${start.day} ～ ${end.year}-${end.month}-${end.day}',
                        ),
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