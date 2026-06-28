// lib/features/platform/pages/platform_account_delete_request_page.dart
// 🗑️ 平台帳號刪除申請管理
// 功能：查看會員刪除帳號申請，並更新處理狀態

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlatformAccountDeleteRequestPage extends StatelessWidget {
  const PlatformAccountDeleteRequestPage({super.key});

  Future<void> _updateStatus({
    required BuildContext context,
    required String requestId,
    required String status,
  }) async {
    await FirebaseFirestore.instance
        .collection('account_delete_requests')
        .doc(requestId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已更新狀態：$status')));
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return '待處理';
      case 'processing':
        return '處理中';
      case 'rejected':
        return '已拒絕';
      case 'completed':
        return '已完成';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showConfirmDialog({
    required BuildContext context,
    required String requestId,
    required String status,
    required String label,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('確認$label？'),
          content: Text('確定要將這筆申請標記為「$label」嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _updateStatus(context: context, requestId: requestId, status: status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('帳號刪除申請')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('account_delete_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('讀取失敗'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有刪除申請'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final email = (data['email'] ?? '') as String;
              final displayName = (data['displayName'] ?? '') as String;
              final reason = (data['reason'] ?? '') as String;
              final status = (data['status'] ?? 'pending') as String;
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFFF1F2),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email.isEmpty ? '未提供 Email' : email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                if (displayName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('名稱：$displayName'),
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatStatus(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(reason.isEmpty ? '原因：未填寫' : '原因：$reason'),
                      const SizedBox(height: 8),
                      Text(
                        createdAt == null
                            ? '申請時間：讀取中'
                            : '申請時間：${createdAt.toDate()}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: status == 'processing'
                                ? null
                                : () {
                                    _showConfirmDialog(
                                      context: context,
                                      requestId: doc.id,
                                      status: 'processing',
                                      label: '處理中',
                                    );
                                  },
                            child: const Text('處理中'),
                          ),
                          OutlinedButton(
                            onPressed: status == 'rejected'
                                ? null
                                : () {
                                    _showConfirmDialog(
                                      context: context,
                                      requestId: doc.id,
                                      status: 'rejected',
                                      label: '已拒絕',
                                    );
                                  },
                            child: const Text('拒絕'),
                          ),
                          FilledButton(
                            onPressed: status == 'completed'
                                ? null
                                : () {
                                    _showConfirmDialog(
                                      context: context,
                                      requestId: doc.id,
                                      status: 'completed',
                                      label: '已完成',
                                    );
                                  },
                            child: const Text('完成'),
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
