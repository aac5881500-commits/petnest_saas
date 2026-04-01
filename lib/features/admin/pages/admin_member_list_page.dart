// lib/features/admin/pages/admin_member_list_page.dart
// 👤 後台會員列表頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';

class AdminMemberListPage extends StatelessWidget {
  const AdminMemberListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('會員管理'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_profiles')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('尚無會員'));
          }

          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final name = data['name'] ?? '未填姓名';
              final phone = data['phone'] ?? '未填電話';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person),

                  title: Text(name),

                  subtitle: Text('📞 $phone'),

onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AdminMemberDetailPage(
        userId: doc.id,
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
    );
  }
}