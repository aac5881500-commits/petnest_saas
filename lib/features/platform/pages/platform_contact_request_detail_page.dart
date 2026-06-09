// lib/features/platform/pages/platform_contact_request_detail_page.dart
// 📮 平台聯絡案件詳情頁
// 功能：查看案件內容、照片、狀態，並支援平台與店主雙向留言紀錄

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlatformContactRequestDetailPage extends StatefulWidget {
  const PlatformContactRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<PlatformContactRequestDetailPage> createState() =>
      _PlatformContactRequestDetailPageState();
}

class _PlatformContactRequestDetailPageState
    extends State<PlatformContactRequestDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSendingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  String _statusText(String status) {
    switch (status) {
      case 'open':
        return '待處理';
      case 'processing':
        return '處理中';
      case 'closed':
        return '已關閉';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(value.toDate());
  }

  Future<void> _updateStatus({
    required BuildContext context,
    required String status,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('platform_contact_requests')
          .doc(widget.requestId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已更新為：${_statusText(status)}')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    setState(() => _isSendingReply = true);

    try {
      final requestRef = FirebaseFirestore.instance
          .collection('platform_contact_requests')
          .doc(widget.requestId);

      final messageRef = requestRef.collection('messages').doc();

      final now = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(messageRef, {
          'senderType': 'platform',
          'senderUid': user.uid,
          'senderEmail': user.email ?? '',
          'message': message,
          'imageUrls': <String>[],
          'createdAt': now,
        });

        transaction.update(requestRef, {
          'status': 'processing',
          'lastMessage': message,
          'lastMessageAt': now,
          'lastSenderType': 'platform',
          'updatedAt': now,
        });
      });

      _replyController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已送出回覆')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('回覆失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _isSendingReply = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .doc(widget.requestId);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('案件詳情')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('找不到案件資料'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final status = (data['status'] ?? 'open').toString();
          final category = (data['category'] ?? '未分類').toString();
          final title = (data['title'] ?? '未填標題').toString();
          final content = (data['content'] ?? '').toString();
          final shopId = (data['shopId'] ?? '').toString();
          final shopName = (data['shopName'] ?? '').toString();
          final shopCode = (data['shopCode'] ?? '').toString();
          final userId = (data['userId'] ?? '').toString();
          final userEmail = (data['userEmail'] ?? '').toString();
          final createdAtText = _formatDate(data['createdAt']);
          final updatedAtText = _formatDate(data['updatedAt']);
          final imageUrls = List<String>.from(data['imageUrls'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _statusColor(status).withOpacity(0.12),
                        child: Icon(
                          Icons.support_agent,
                          color: _statusColor(status),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusText(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _InfoCard(
                title: '案件內容',
                children: [
                  _InfoRow(label: '分類', value: category),
                  _InfoRow(label: '標題', value: title),
                  const SizedBox(height: 10),
                  Text(
                    content.isEmpty ? '-' : content,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _InfoCard(
                title: '送出資訊',
                children: [
                  _InfoRow(label: '店名', value: shopName),
                  _InfoRow(label: '店編', value: shopCode),
                  _InfoRow(label: '店家 ID', value: shopId),
                  _InfoRow(label: '使用者 ID', value: userId),
                  _InfoRow(label: '送出帳號', value: userEmail),
                  _InfoRow(label: '建立時間', value: createdAtText),
                  _InfoRow(label: '更新時間', value: updatedAtText),
                ],
              ),

              const SizedBox(height: 12),

              _InfoCard(
                title: '附件照片',
                children: [
                  if (imageUrls.isEmpty)
                    Text(
                      '沒有上傳照片',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: imageUrls.map((url) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                width: 110,
                                height: 110,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              _MessageListCard(
                requestId: widget.requestId,
                formatDate: _formatDate,
              ),

              const SizedBox(height: 12),

              if (status != 'closed')
                _ReplyCard(
                  controller: _replyController,
                  isSending: _isSendingReply,
                  onSend: _sendReply,
                ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: status == 'processing' || status == 'closed'
                          ? null
                          : () {
                              _updateStatus(
                                context: context,
                                status: 'processing',
                              );
                            },
                      icon: const Icon(Icons.timelapse),
                      label: const Text('標記處理中'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: status == 'closed'
                          ? null
                          : () {
                              _updateStatus(context: context, status: 'closed');
                            },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('關閉案件'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageListCard extends StatelessWidget {
  const _MessageListCard({required this.requestId, required this.formatDate});

  final String requestId;
  final String Function(dynamic value) formatDate;

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .doc(requestId)
        .collection('messages');

    return _InfoCard(
      title: '對話紀錄',
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: messagesRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('留言讀取失敗：${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final sortedDocs = docs.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aTime = aData['createdAt'];
                final bTime = bData['createdAt'];

                if (aTime is Timestamp && bTime is Timestamp) {
                  return aTime.compareTo(bTime);
                }

                return 0;
              });

            if (sortedDocs.isEmpty) {
              return Text(
                '目前還沒有對話紀錄',
                style: TextStyle(color: Colors.grey.shade600),
              );
            }

            return Column(
              children: sortedDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final senderType = (data['senderType'] ?? '').toString();
                final senderEmail = (data['senderEmail'] ?? '').toString();
                final message = (data['message'] ?? '').toString();
                final createdAtText = formatDate(data['createdAt']);

                final isPlatform = senderType == 'platform';

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPlatform
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPlatform
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPlatform ? '平台回覆' : '店主補充',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPlatform
                              ? Colors.blue.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        senderEmail.isEmpty ? '-' : senderEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(message, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 6),
                      Text(
                        createdAtText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '平台回覆',
      children: [
        TextField(
          controller: controller,
          enabled: !isSending,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '輸入要回覆店主的內容',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(isSending ? '送出中...' : '送出回覆'),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '$label：',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
