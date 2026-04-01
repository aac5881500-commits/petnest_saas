// lib/features/member/pages/member_page.dart
// 👤 會員中心頁（完整版：含電話輸入）

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/member/pages/member_booking_page.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('會員中心'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const Center(child: Text('尚未登入'))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final data =
                      snapshot.data!.data() as Map<String, dynamic>?;

                  final phone = data?['phone'] ?? '';

                  /// 🔥 讓欄位帶入初始值（避免覆蓋輸入）
                  if (_phoneController.text != phone) {
                    _phoneController.text = phone;
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// Email
                        Text('Email：${user.email ?? ''}'),
                        const SizedBox(height: 12),

                        /// 🔥 電話輸入
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: '電話',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('user_profiles')
                                  .doc(user.uid)
                                  .set({
                                'phone': _phoneController.text.trim(),
                                'updatedAt':
                                    FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content: Text('已儲存')),
                                );
                              }
                            },
                            child: const Text('儲存電話'),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// 🔥 寵物標題 + 新增
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '寵物',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AddPetPage(),
                                  ),
                                );
                              },
                              child: const Text('新增'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        /// 🔥 寵物列表
                        StreamBuilder<
                            List<Map<String, dynamic>>>(
                          stream:
                              PetService.instance.streamMyPets(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            final pets = snapshot.data!;

                            if (pets.isEmpty) {
                              return const Text('尚未新增寵物');
                            }

                            return Column(
                              children: pets.map((pet) {
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundImage:
                                          pet['photoUrl'] != null &&
                                                  pet['photoUrl']
                                                      .toString()
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                  pet['photoUrl'])
                                              : null,
                                      child: (pet['photoUrl'] ==
                                                  null ||
                                              pet['photoUrl']
                                                  .toString()
                                                  .isEmpty)
                                          ? const Icon(Icons.pets)
                                          : null,
                                    ),
                                    title: Text(
                                        pet['name'] ?? '未命名'),
                                    subtitle: Text(
                                        pet['type'] ?? ''),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PetDetailPage(
                                                  pet: pet),
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

                       const SizedBox(height: 24),

ListTile(
  leading: const Icon(Icons.receipt_long),
  title: const Text('我的訂單'),
  subtitle: const Text('查看所有預約紀錄'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MemberBookingPage(),
      ),
    );
  },
),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}