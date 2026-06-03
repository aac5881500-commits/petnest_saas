// lib/features/admin/pages/admin_member_detail_page.dart
// 👤 後台會員詳細頁（完整版 UI + 功能升級🔥）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_booking_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_logs_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_detail_badges.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_profile_section.dart';

class AdminMemberDetailPage extends StatelessWidget {
  const AdminMemberDetailPage({
    super.key,
    required this.userId,
    required this.shopId,
  });

  final String userId;
  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員詳細')),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminMemberProfileSection(userId: userId, shopId: shopId),

            /// ===============================
            /// 🐾 寵物
            /// ===============================
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pets, color: Colors.orange),
                  ),

                  const SizedBox(width: 10),

                  const Text(
                    '寵物資料',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PetDetailPage(pet: data, isAdminView: true),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.orange.shade50,
                                backgroundImage:
                                    data['photoUrl'] != null &&
                                        data['photoUrl'] != ''
                                    ? NetworkImage(data['photoUrl'])
                                    : null,
                                child:
                                    data['photoUrl'] == null ||
                                        data['photoUrl'] == ''
                                    ? const Icon(
                                        Icons.pets,
                                        color: Colors.orange,
                                      )
                                    : null,
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          data['name'] ?? '寵物',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.lock,
                                          size: 15,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      '${data['type'] ?? '未填種類'}｜${data['age'] ?? '未填年齡'}｜${data['gender'] ?? '未填性別'}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (data['isNeutered'] == true)
                                          adminMemberSmallBadge(
                                            '已結紮',
                                            Colors.green,
                                          )
                                        else
                                          adminMemberSmallBadge(
                                            '未結紮',
                                            Colors.grey,
                                          ),

                                        if ((data['medicalStatus'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          adminMemberSmallBadge(
                                            '醫療注意',
                                            Colors.red,
                                          ),

                                        if ((data['staffNote'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          adminMemberSmallBadge(
                                            '員工備註',
                                            Colors.orange,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            /// ===============================
            /// 📜 條款版本
            /// ===============================
            const SizedBox(height: 24),

            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.teal,
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Text(
                    '條款同意紀錄',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('policy_acceptances')
                  .doc(shopId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final doc = snapshot.data!;

                if (!doc.exists) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('尚未同意任何條款'),
                  );
                }

                final data = doc.data() as Map<String, dynamic>;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_outlined,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '入住須知版本：v${data['acceptedVersion'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '同意時間：${_formatTime(data['acceptedAt'])}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ShopPolicyLogsPage(shopId: shopId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('查看歷史紀錄'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            /// ===============================
            /// 📦 訂單
            /// ===============================
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.blue),
                  ),

                  const SizedBox(width: 10),

                  const Text(
                    '訂單紀錄',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
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

                    return AdminMemberBookingCard(
                      bookingId: doc.id,
                      data: data,
                    );
                  }).toList(),
                );
              },
            ),

            /// ===============================
            /// 📜 操作紀錄
            /// ===============================
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history, color: Colors.purple),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '操作紀錄',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('action_logs')
                  .where('shopId', isEqualTo: shopId)
                  .where('targetUserId', isEqualTo: userId)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final logs = snapshot.data!.docs.toList();

                logs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aTime = aData['createdAt'];
                  final bTime = bData['createdAt'];

                  if (aTime is! Timestamp || bTime is! Timestamp) return 0;

                  return bTime.compareTo(aTime);
                });

                if (logs.isEmpty) {
                  return const Text('尚無操作紀錄');
                }

                return Column(
                  children: logs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final type = data['type'] ?? '';
                    final operator = data['operatorEmail'] ?? '未知操作人';

                    String title = type;

                    switch (type) {
                      case 'member_blacklisted':
                        title = '加入黑名單';
                        break;

                      case 'member_link_approved':
                        title = '確認會員綁定';
                        break;

                      case 'member_link_rejected':
                        title = '拒絕會員綁定';
                        break;

                      case 'member_blacklist_removed':
                        title = '解除黑名單';
                        break;

                      case 'member_vip_added':
                        title = '設為常客';
                        break;

                      case 'member_vip_removed':
                        title = '取消常客';
                        break;
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text('操作人：$operator'),

                          if ((data['reason'] ?? '').toString().isNotEmpty)
                            Text('原因：${data['reason']}'),

                          const SizedBox(height: 4),

                          Text(
                            _formatTime(data['createdAt']),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';

    final dt = value.toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
