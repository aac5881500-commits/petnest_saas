// 檔案名稱：lib/features/shop/pages/shop_contact_request_detail_page.dart
// 功能說明：店主查看平台回覆，並可回覆平台，保留完整對話紀錄
// 📮 店主聯絡平台案件詳情頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShopContactRequestDetailPage extends StatefulWidget {
  const ShopContactRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<ShopContactRequestDetailPage> createState() =>
      _ShopContactRequestDetailPageState();
}

class _ShopContactRequestDetailPageState
    extends State<ShopContactRequestDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSendingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(value.toDate());
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
          'senderType': 'shop_owner',
          'senderUid': user.uid,
          'senderEmail': user.email ?? '',
          'message': message,
          'imageUrls': <String>[],
          'createdAt': now,
        });

        transaction.update(requestRef, {
          'lastMessage': message,
          'lastMessageAt': now,
          'lastSenderType': 'shop_owner',
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
    final requestRef = FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .doc(widget.requestId);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('案件詳情'),
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: requestRef.snapshots(),
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
          final createdAtText = _formatDate(data['createdAt']);
          final updatedAtText = _formatDate(data['updatedAt']);
          final imageUrls = List<String>.from(data['imageUrls'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(
                      status,
                    ).withValues(alpha: 0.12),
                    child: Icon(
                      Icons.support_agent,
                      color: _statusColor(status),
                    ),
                  ),
                  title: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text('更新時間：$updatedAtText'),
                ),
              ),

              const SizedBox(height: 12),

              _InfoCard(
                title: '案件內容',
                children: [
                  _InfoRow(label: '分類', value: category),
                  _InfoRow(label: '標題', value: title),
                  _InfoRow(label: '建立時間', value: createdAtText),
                  const SizedBox(height: 10),
                  Text(
                    content.isEmpty ? '-' : content,
                    style: const TextStyle(height: 1.5),
                  ),
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

              if (status == 'closed')
                Card(
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '此案件已由平台結案，如有新問題請重新建立案件。',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              if (status != 'closed')
                _ReplyCard(
                  controller: _replyController,
                  isSending: _isSendingReply,
                  onSend: _sendReply,
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
                        isPlatform ? '平台回覆' : '我的回覆',
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
      title: '回覆平台',
      children: [
        TextField(
          controller: controller,
          enabled: !isSending,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '輸入要補充給平台的內容',
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
