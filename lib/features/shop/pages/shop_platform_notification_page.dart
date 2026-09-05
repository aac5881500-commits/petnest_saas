// 檔案名稱：lib/features/shop/pages/shop_platform_notification_page.dart
// 功能說明：查看平台主動發給店家的通知，例如方案到期、停權、審核、系統維護
// 🔔 店主平台通知頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShopPlatformNotificationPage extends StatelessWidget {
  const ShopPlatformNotificationPage({super.key, required this.shopId});

  final String shopId;

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(value.toDate());
  }

  String _typeText(String type) {
    switch (type) {
      case 'plan':
        return '方案通知';
      case 'suspend':
        return '停權通知';
      case 'review':
        return '審核通知';
      case 'system':
        return '系統通知';
      case 'warning':
        return '違規提醒';
      case 'update':
        return '功能更新';
      default:
        return '平台通知';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'plan':
        return Icons.workspace_premium;
      case 'suspend':
        return Icons.block;
      case 'review':
        return Icons.fact_check;
      case 'system':
        return Icons.settings;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'update':
        return Icons.new_releases;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'suspend':
      case 'warning':
        return Colors.red;
      case 'plan':
        return Colors.orange;
      case 'review':
        return Colors.blue;
      case 'update':
        return Colors.green;
      case 'system':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('平台通知'),
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shop_notifications')
            .where('shopId', isEqualTo: shopId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有平台通知'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final type = (data['type'] ?? 'system').toString();
              final title = (data['title'] ?? '平台通知').toString();
              final content = (data['content'] ?? '').toString();
              final status = (data['status'] ?? 'unread').toString();
              final createdAtText = _formatDate(data['createdAt']);
              final isUnread = status == 'unread';

              return Card(
                elevation: 0,
                color: isUnread ? Colors.white : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isUnread
                        ? _typeColor(type).withValues(alpha: 0.25)
                        : Colors.grey.shade300,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(type).withValues(alpha: 0.12),
                    child: Icon(_typeIcon(type), color: _typeColor(type)),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '未讀',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_typeText(type)),
                        Text(createdAtText),
                        if (content.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            content,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  onTap: () async {
                    if (isUnread) {
                      await docs[index].reference.update({
                        'status': 'read',
                        'readAt': FieldValue.serverTimestamp(),
                      });
                    }
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
