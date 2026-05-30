// lib/features/admin/pages/admin_member_detail_page.dart
// 👤 後台會員詳細頁（完整版 UI + 功能升級🔥）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_booking_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_logs_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

                final data = snapshot.data!.data() as Map<String, dynamic>?;

                if (data == null) {
                  return const Text('找不到會員資料');
                }

                final tags = List<String>.from(data['tags'] ?? []);
                final canArchiveMember =
                    data['createdFrom'] == 'admin' &&
                    (data['linkedAuthUid'] ?? '').toString().isEmpty &&
                    (data['email'] ?? '').toString().isEmpty &&
                    data['status'] != 'archived';

                final canRestoreMember =
                    data['createdFrom'] == 'admin' &&
                    data['status'] == 'archived';

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
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 👤 名字
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.blue.shade50,
                            child: const Icon(
                              Icons.person,
                              size: 34,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? '未填姓名',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    if (tags.contains('vip'))
                                      _smallBadge('常客', Colors.orange),
                                    if (tags.contains('blacklist'))
                                      _smallBadge('黑名單', Colors.red),
                                  ],
                                ),
                              ],
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
                            data['email'] ?? '未填Email',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      if ((data['linkedAuthUid'] ?? '').toString().isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user,
                                size: 18,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '已綁定登入帳號：${data['email'] ?? '未填 Email'}',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

                      FutureBuilder<List<int>>(
                        future: Future.wait([
                          FirebaseFirestore.instance
                              .collection('user_profiles')
                              .doc(userId)
                              .collection('pets')
                              .get()
                              .then((snapshot) => snapshot.docs.length),
                          FirebaseFirestore.instance
                              .collection('bookings')
                              .where('userId', isEqualTo: userId)
                              .get()
                              .then((snapshot) => snapshot.docs.length),
                        ]),
                        builder: (context, countSnapshot) {
                          final petCount = countSnapshot.data?[0] ?? 0;
                          final bookingCount = countSnapshot.data?[1] ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _statBox(
                                  icon: Icons.pets,
                                  color: Colors.orange,
                                  value: '$petCount',
                                  label: '寵物數',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _statBox(
                                  icon: Icons.receipt_long,
                                  color: Colors.blue,
                                  value: '$bookingCount',
                                  label: '訂單數',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _statBox(
                                  icon: Icons.verified_user,
                                  color: tags.contains('vip')
                                      ? Colors.green
                                      : Colors.grey,
                                  value: tags.contains('vip') ? 'VIP' : '一般',
                                  label: '會員',
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

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
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 👤 姓名
                            Row(
                              children: [
                                const Icon(Icons.person, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['emergencyContact']?['name'] ?? '未填',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            /// 📞 電話
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['emergencyContact']?['phone'] ?? '未填',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            /// 🤝 關係
                            Row(
                              children: [
                                const Icon(Icons.people, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['emergencyContact']?['relation'] ??
                                        '未填',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            /// 🏠 地址
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.home, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['emergencyContact']?['address'] ??
                                        '未填',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
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

                      if (tags.contains('blacklist') &&
                          (data['blacklistReason'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Text(
                            '黑名單原因：${data['blacklistReason']}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('member_link_requests')
                            .where('targetUserId', isEqualTo: userId)
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, requestSnapshot) {
                          if (!requestSnapshot.hasData) {
                            return const SizedBox();
                          }

                          final requests = requestSnapshot.data!.docs;

                          if (requests.isEmpty) {
                            return const SizedBox();
                          }

                          return Column(
                            children: requests.map((requestDoc) {
                              final request =
                                  requestDoc.data() as Map<String, dynamic>;

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.blue.shade100,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '會員綁定申請',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '登入帳號：${request['authEmail'] ?? '未填'}',
                                    ),
                                    Text(
                                      '申請手機：${request['targetPhone'] ?? '未填'}',
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final authUid =
                                                  request['authUid']
                                                      ?.toString() ??
                                                  '';

                                              if (authUid.isEmpty) {
                                                return;
                                              }

                                              final oldUserRef =
                                                  FirebaseFirestore.instance
                                                      .collection(
                                                        'user_profiles',
                                                      )
                                                      .doc(userId);

                                              final newUserRef =
                                                  FirebaseFirestore.instance
                                                      .collection(
                                                        'user_profiles',
                                                      )
                                                      .doc(authUid);

                                              final oldUserSnap =
                                                  await oldUserRef.get();

                                              if (!oldUserSnap.exists) {
                                                return;
                                              }

                                              final oldData =
                                                  oldUserSnap.data() ?? {};

                                              /// 🔥 合併會員資料
                                              await newUserRef.set({
                                                ...oldData,
                                                'uid': authUid,
                                                'email':
                                                    request['authEmail'] ?? '',
                                                'linkedAuthUid': authUid,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              }, SetOptions(merge: true));

                                              /// 🔥 搬移寵物
                                              final pets = await oldUserRef
                                                  .collection('pets')
                                                  .get();

                                              for (final pet in pets.docs) {
                                                await newUserRef
                                                    .collection('pets')
                                                    .doc(pet.id)
                                                    .set(pet.data());

                                                await pet.reference.delete();
                                              }

                                              /// 🔥 更新訂單 userId
                                              final bookings =
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('bookings')
                                                      .where(
                                                        'userId',
                                                        isEqualTo: userId,
                                                      )
                                                      .get();

                                              for (final booking
                                                  in bookings.docs) {
                                                await booking.reference.update({
                                                  'userId': authUid,
                                                });
                                              }

                                              /// 🔥 更新綁定狀態
                                              await requestDoc.reference.update({
                                                'status': 'approved',
                                                'approvedAt':
                                                    FieldValue.serverTimestamp(),
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              });

                                              final operator = FirebaseAuth
                                                  .instance
                                                  .currentUser;

                                              await FirebaseFirestore.instance
                                                  .collection('action_logs')
                                                  .add({
                                                    'type':
                                                        'member_link_approved',
                                                    'targetUserId': userId,
                                                    'targetUserName':
                                                        data['name'] ?? '',
                                                    'targetUserEmail':
                                                        data['email'] ?? '',
                                                    'operatorUid':
                                                        operator?.uid,
                                                    'operatorEmail':
                                                        operator?.email,
                                                    'createdAt':
                                                        FieldValue.serverTimestamp(),
                                                  });

                                              /// 🔥 刪除舊會員
                                              await oldUserRef.delete();

                                              if (!context.mounted) return;

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('會員資料已成功合併'),
                                                ),
                                              );
                                              Navigator.pop(context);
                                            },
                                            icon: const Icon(Icons.check),
                                            label: const Text('確認綁定'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final reasonController =
                                                  TextEditingController();

                                              final reason = await showDialog<String>(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    title: const Text('拒絕綁定原因'),
                                                    content: TextField(
                                                      controller:
                                                          reasonController,
                                                      maxLines: 3,
                                                      decoration: const InputDecoration(
                                                        hintText:
                                                            '例如：資料不符、無法確認本人、手機號碼填錯',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        child: const Text('取消'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                            reasonController
                                                                .text
                                                                .trim(),
                                                          );
                                                        },
                                                        child: const Text(
                                                          '確認拒絕',
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );

                                              if (reason == null ||
                                                  reason.isEmpty) {
                                                return;
                                              }

                                              await requestDoc.reference.update({
                                                'status': 'rejected',
                                                'rejectReason': reason,
                                                'rejectedAt':
                                                    FieldValue.serverTimestamp(),
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              });

                                              final operator = FirebaseAuth
                                                  .instance
                                                  .currentUser;

                                              await FirebaseFirestore.instance
                                                  .collection('action_logs')
                                                  .add({
                                                    'type':
                                                        'member_link_rejected',
                                                    'targetUserId': userId,
                                                    'targetUserName':
                                                        data['name'] ?? '',
                                                    'targetUserEmail':
                                                        data['email'] ?? '',
                                                    'operatorUid':
                                                        operator?.uid,
                                                    'operatorEmail':
                                                        operator?.email,
                                                    'reason': reason,
                                                    'createdAt':
                                                        FieldValue.serverTimestamp(),
                                                  });

                                              if (!context.mounted) return;

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('已拒絕會員綁定'),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.close),
                                            label: const Text('拒絕'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      Builder(
                        builder: (context) {
                          final noteController = TextEditingController(
                            text: data['adminNote1'] ?? '',
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: noteController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: '店家備註',
                                  hintText: '例如：容易緊張、需提前提醒訂金、常提早入住',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('user_profiles')
                                        .doc(userId)
                                        .update({
                                          'adminNote1': noteController.text
                                              .trim(),
                                          'adminNoteUpdatedAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已儲存備註')),
                                    );
                                  },
                                  icon: const Icon(Icons.save),
                                  label: const Text('儲存備註'),
                                ),
                              ),
                            ],
                          );
                        },
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
                                  snap.data()?['tags'] ?? [],
                                );

                                final wasVip = tags.contains('vip');

                                if (wasVip) {
                                  tags.remove('vip');
                                } else {
                                  tags.add('vip');
                                }

                                await ref.update({'tags': tags});

                                final user = FirebaseAuth.instance.currentUser;

                                await FirebaseFirestore.instance
                                    .collection('action_logs')
                                    .add({
                                      'type': wasVip
                                          ? 'member_vip_removed'
                                          : 'member_vip_added',
                                      'targetUserId': userId,
                                      'targetUserName': data['name'] ?? '',
                                      'targetUserEmail': data['email'] ?? '',
                                      'operatorUid': user?.uid,
                                      'operatorEmail': user?.email,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
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
                                  snap.data()?['tags'] ?? [],
                                );

                                /// 已是黑名單 → 移除
                                if (tags.contains('blacklist')) {
                                  tags.remove('blacklist');

                                  await ref.update({
                                    'tags': tags,
                                    'blacklistReason': FieldValue.delete(),
                                    'blacklistedAt': FieldValue.delete(),
                                  });

                                  final user =
                                      FirebaseAuth.instance.currentUser;

                                  await FirebaseFirestore.instance
                                      .collection('action_logs')
                                      .add({
                                        'type': 'member_blacklist_removed',
                                        'targetUserId': userId,
                                        'targetUserName': data['name'] ?? '',
                                        'targetUserEmail': data['email'] ?? '',
                                        'operatorUid': user?.uid,
                                        'operatorEmail': user?.email,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                      });

                                  return;
                                }

                                /// 輸入原因
                                final reasonController =
                                    TextEditingController();

                                final reason = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('加入黑名單原因'),
                                      content: TextField(
                                        controller: reasonController,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                          hintText: '例如：惡意取消、未付款、攻擊店員',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text('取消'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(
                                              context,
                                              reasonController.text.trim(),
                                            );
                                          },
                                          child: const Text('確認加入'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (reason == null || reason.isEmpty) return;

                                tags.add('blacklist');

                                await ref.update({
                                  'tags': tags,
                                  'blacklistReason': reason,
                                  'blacklistedAt': FieldValue.serverTimestamp(),
                                });
                                final user = FirebaseAuth.instance.currentUser;

                                await FirebaseFirestore.instance
                                    .collection('action_logs')
                                    .add({
                                      'type': 'member_blacklisted',
                                      'targetUserId': userId,
                                      'targetUserName': data['name'] ?? '',
                                      'targetUserEmail': data['email'] ?? '',
                                      'operatorUid': user?.uid,
                                      'operatorEmail': user?.email,
                                      'reason': reason,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                              },
                              icon: const Icon(Icons.block),
                              label: const Text('黑名單'),
                            ),
                          ),
                        ],
                      ),
                      if (canArchiveMember)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.archive),
                              label: const Text('封存手動會員'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('封存會員'),
                                      content: const Text(
                                        '封存後會員列表將不再顯示此會員，但資料會保留，避免日後查不到紀錄。確定要封存嗎？',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },
                                          child: const Text('取消'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },
                                          child: const Text('確認封存'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm != true) return;

                                await FirebaseFirestore.instance
                                    .collection('user_profiles')
                                    .doc(userId)
                                    .update({
                                      'status': 'archived',
                                      'archivedAt':
                                          FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已封存會員')),
                                );

                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ),
                      if (canRestoreMember)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.unarchive),
                              label: const Text('解除封存'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('解除封存會員'),
                                      content: const Text(
                                        '解除封存後，會員會重新出現在正常會員列表。確定要解除封存嗎？',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },
                                          child: const Text('取消'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },
                                          child: const Text('確認解除'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm != true) return;

                                await FirebaseFirestore.instance
                                    .collection('user_profiles')
                                    .doc(userId)
                                    .update({
                                      'status': FieldValue.delete(),
                                      'restoredAt':
                                          FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已解除封存')),
                                );

                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

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
                                          _smallBadge('已結紮', Colors.green)
                                        else
                                          _smallBadge('未結紮', Colors.grey),

                                        if ((data['medicalStatus'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          _smallBadge('醫療注意', Colors.red),

                                        if ((data['staffNote'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          _smallBadge('員工備註', Colors.orange),
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

  Widget _statusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = '已確認';
        break;
      case 'checked_in':
        color = Colors.blue;
        text = '入住中';
        break;
      case 'completed':
        color = Colors.grey;
        text = '已完成';
        break;
      case 'cancelled':
        color = Colors.red;
        text = '已取消';
        break;
      default:
        color = Colors.orange;
        text = '待確認';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
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

  Widget _statBox({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: value.length > 3 ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
