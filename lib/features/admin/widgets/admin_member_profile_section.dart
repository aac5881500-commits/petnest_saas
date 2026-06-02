// lib/features/admin/widgets/admin_member_profile_section.dart
// 👤 後台會員詳細頁：會員資料區塊
// 功能：顯示會員基本資料、緊急聯絡人、會員綁定、備註、標籤、封存操作

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_detail_badges.dart';

class AdminMemberProfileSection extends StatelessWidget {
  const AdminMemberProfileSection({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
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
            data['createdFrom'] == 'admin' && data['status'] == 'archived';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MemberHeader(data: data, tags: tags),
              const SizedBox(height: 12),
              _MemberBasicInfo(data: data),
              const SizedBox(height: 16),
              _MemberStats(userId: userId, tags: tags),
              const SizedBox(height: 20),
              _EmergencyContactBox(data: data),
              const SizedBox(height: 16),
              _MemberTags(data: data, tags: tags),
              const SizedBox(height: 12),
              _MemberLinkRequests(userId: userId, data: data),
              const SizedBox(height: 12),
              _AdminNoteBox(userId: userId, data: data),
              const SizedBox(height: 12),
              _MemberActionButtons(userId: userId, data: data),
              if (canArchiveMember) _ArchiveButton(userId: userId),
              if (canRestoreMember) _RestoreButton(userId: userId),
            ],
          ),
        );
      },
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.data, required this.tags});

  final Map<String, dynamic> data;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.person, size: 34, color: Colors.blue),
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
                    adminMemberSmallBadge('常客', Colors.orange),
                  if (tags.contains('blacklist'))
                    adminMemberSmallBadge('黑名單', Colors.red),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberBasicInfo extends StatelessWidget {
  const _MemberBasicInfo({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                const Icon(Icons.verified_user, size: 18, color: Colors.green),
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
        Row(
          children: [
            const Icon(Icons.phone, size: 18),
            const SizedBox(width: 6),
            Text(data['phone'] ?? '未填電話', style: const TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 6),
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
      ],
    );
  }
}

class _MemberStats extends StatelessWidget {
  const _MemberStats({required this.userId, required this.tags});

  final String userId;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
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
              child: adminMemberStatBox(
                icon: Icons.pets,
                color: Colors.orange,
                value: '$petCount',
                label: '寵物數',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: adminMemberStatBox(
                icon: Icons.receipt_long,
                color: Colors.blue,
                value: '$bookingCount',
                label: '訂單數',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: adminMemberStatBox(
                icon: Icons.verified_user,
                color: tags.contains('vip') ? Colors.green : Colors.grey,
                value: tags.contains('vip') ? 'VIP' : '一般',
                label: '會員',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmergencyContactBox extends StatelessWidget {
  const _EmergencyContactBox({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '緊急聯絡人',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              _InfoRow(
                icon: Icons.person,
                text: data['emergencyContact']?['name'] ?? '未填',
                bold: true,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.phone,
                text: data['emergencyContact']?['phone'] ?? '未填',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.people,
                text: data['emergencyContact']?['relation'] ?? '未填',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.home,
                text: data['emergencyContact']?['address'] ?? '未填',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.bold = false});

  final IconData icon;
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: bold ? 16 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberTags extends StatelessWidget {
  const _MemberTags({required this.data, required this.tags});

  final Map<String, dynamic> data;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            if (tags.contains('vip')) const Chip(label: Text('⭐ 常客')),
            if (tags.contains('blacklist'))
              const Chip(label: Text('🚫 黑名單'), backgroundColor: Colors.red),
          ],
        ),
        if (tags.contains('blacklist') &&
            (data['blacklistReason'] ?? '').toString().isNotEmpty) ...[
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
      ],
    );
  }
}

class _MemberLinkRequests extends StatelessWidget {
  const _MemberLinkRequests({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
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
            final request = requestDoc.data() as Map<String, dynamic>;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '會員綁定申請',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text('登入帳號：${request['authEmail'] ?? '未填'}'),
                  Text('申請手機：${request['targetPhone'] ?? '未填'}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _approveLinkRequest(
                              context: context,
                              requestDoc: requestDoc,
                              request: request,
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('確認綁定'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _rejectLinkRequest(
                              context: context,
                              requestDoc: requestDoc,
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
    );
  }

  Future<void> _approveLinkRequest({
    required BuildContext context,
    required QueryDocumentSnapshot requestDoc,
    required Map<String, dynamic> request,
  }) async {
    final authUid = request['authUid']?.toString() ?? '';

    if (authUid.isEmpty) return;

    final oldUserRef = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId);

    final newUserRef = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(authUid);

    final oldUserSnap = await oldUserRef.get();

    if (!oldUserSnap.exists) return;

    final oldData = oldUserSnap.data() ?? {};

    await newUserRef.set({
      ...oldData,
      'uid': authUid,
      'email': request['authEmail'] ?? '',
      'linkedAuthUid': authUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final pets = await oldUserRef.collection('pets').get();

    for (final pet in pets.docs) {
      await newUserRef.collection('pets').doc(pet.id).set(pet.data());
      await pet.reference.delete();
    }

    final bookings = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .get();

    for (final booking in bookings.docs) {
      await booking.reference.update({'userId': authUid});
    }

    await requestDoc.reference.update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final operator = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'member_link_approved',
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': operator?.uid,
      'operatorEmail': operator?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await oldUserRef.delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('會員資料已成功合併')));

    Navigator.pop(context);
  }

  Future<void> _rejectLinkRequest({
    required BuildContext context,
    required QueryDocumentSnapshot requestDoc,
  }) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('拒絕綁定原因'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '例如：資料不符、無法確認本人、手機號碼填錯',
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
                Navigator.pop(context, reasonController.text.trim());
              },
              child: const Text('確認拒絕'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    await requestDoc.reference.update({
      'status': 'rejected',
      'rejectReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final operator = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'member_link_rejected',
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': operator?.uid,
      'operatorEmail': operator?.email,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已拒絕會員綁定')));
  }
}

class _AdminNoteBox extends StatelessWidget {
  const _AdminNoteBox({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    'adminNote1': noteController.text.trim(),
                    'adminNoteUpdatedAt': FieldValue.serverTimestamp(),
                  });

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已儲存備註')));
            },
            icon: const Icon(Icons.save),
            label: const Text('儲存備註'),
          ),
        ),
      ],
    );
  }
}

class _MemberActionButtons extends StatelessWidget {
  const _MemberActionButtons({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              await _toggleVip();
            },
            icon: const Icon(Icons.star),
            label: const Text('常客'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _toggleBlacklist(context);
            },
            icon: const Icon(Icons.block),
            label: const Text('黑名單'),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleVip() async {
    final ref = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId);

    final snap = await ref.get();

    final tags = List<String>.from(snap.data()?['tags'] ?? []);
    final wasVip = tags.contains('vip');

    if (wasVip) {
      tags.remove('vip');
    } else {
      tags.add('vip');
    }

    await ref.update({'tags': tags});

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': wasVip ? 'member_vip_removed' : 'member_vip_added',
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': user?.uid,
      'operatorEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleBlacklist(BuildContext context) async {
    final ref = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId);

    final snap = await ref.get();
    final tags = List<String>.from(snap.data()?['tags'] ?? []);

    if (tags.contains('blacklist')) {
      tags.remove('blacklist');

      await ref.update({
        'tags': tags,
        'blacklistReason': FieldValue.delete(),
        'blacklistedAt': FieldValue.delete(),
      });

      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('action_logs').add({
        'type': 'member_blacklist_removed',
        'targetUserId': userId,
        'targetUserName': data['name'] ?? '',
        'targetUserEmail': data['email'] ?? '',
        'operatorUid': user?.uid,
        'operatorEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    final reasonController = TextEditingController();

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
                Navigator.pop(context, reasonController.text.trim());
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

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'member_blacklisted',
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': user?.uid,
      'operatorEmail': user?.email,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class _ArchiveButton extends StatelessWidget {
  const _ArchiveButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  'archivedAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

            if (!context.mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已封存會員')));

            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  content: const Text('解除封存後，會員會重新出現在正常會員列表。確定要解除封存嗎？'),
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
                  'restoredAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

            if (!context.mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已解除封存')));

            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
