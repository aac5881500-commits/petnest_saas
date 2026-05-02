// lib/features/booking/pages/my_bookings_page.dart
// 📄 我的訂單頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_detail_page.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('請先登入')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的訂單')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('目前沒有訂單'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final start = (data['startDate'] as Timestamp).toDate();
              final end = (data['endDate'] as Timestamp).toDate();

              return Card(
  margin: const EdgeInsets.all(12),
  child: ListTile(
    title: Text(data['roomName'] ?? '房型'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${start.toString().substring(0, 10)} → ${end.toString().substring(0, 10)}'),
        Text('寵物數：${(data['petIds'] ?? []).length}'),
        Text('狀態：${data['status'] ?? ''}'),
      ],
    ),

    /// 🔥 點擊進詳細頁
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailPage(
  data: data,
  docId: docs[index].id, // 🔥 這行關鍵
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
    );
  }
}