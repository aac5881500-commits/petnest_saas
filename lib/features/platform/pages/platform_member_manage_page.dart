// lib/features/platform/pages/platform_member_manage_page.dart
// 👤 平台會員管理頁
// 功能：平台後台查看平台帳號、帳號狀態、最後登入與平台備註

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlatformMemberManagePage extends StatelessWidget {
  const PlatformMemberManagePage({super.key});

  String _formatDate(dynamic value) {
    if (value == null) return '尚未設定';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '尚未設定';

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'blocked':
        return '已封鎖';
      case 'restricted':
        return '限制預約';
      case 'active':
      default:
        return '正常';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'blocked':
        return Colors.red;
      case 'restricted':
        return Colors.orange;
      case 'active':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('平台會員管理')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有平台會員'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final email = data['email']?.toString() ?? '未設定 Email';
              final displayName = data['displayName']?.toString() ?? '未設定名稱';
              final status = data['platformStatus']?.toString() ?? 'active';
              final createdAt = data['createdAt'];
              final lastLoginAt = data['lastLoginAt'];
              final note = data['platformNote']?.toString() ?? '';

              return Card(
                elevation: 0,
                color: status == 'blocked'
                    ? const Color(0xFFFFFBFB)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: status == 'blocked'
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFEAF3FF),
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName.substring(0, 1)
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(
                            icon: Icons.badge_outlined,
                            label: 'UID：${doc.id}',
                          ),
                          _InfoPill(
                            icon: Icons.add_circle_outline,
                            label: '加入：${_formatDate(createdAt)}',
                          ),
                          _InfoPill(
                            icon: Icons.login,
                            label: '最後登入：${_formatDate(lastLoginAt)}',
                          ),
                        ],
                      ),

                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '平台備註：$note',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('備註'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(
                                status == 'blocked'
                                    ? Icons.check_circle_outline
                                    : Icons.block,
                                size: 18,
                              ),
                              label: Text(status == 'blocked' ? '解除封鎖' : '封鎖'),
                            ),
                          ),
                        ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
