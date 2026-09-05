// 檔案名稱：lib/features/platform/pages/platform_contact_request_list_page.dart
// 功能說明：平台後台查看店主與會員送出的聯絡平台案件
// 📮 平台聯絡案件列表頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/features/platform/pages/platform_contact_request_detail_page.dart';

class PlatformContactRequestListPage extends StatelessWidget {
  const PlatformContactRequestListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text('聯絡平台案件'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '店主聯絡'),
              Tab(text: '會員聯絡'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ContactRequestList(source: 'shop_owner'),
            _ContactRequestList(source: 'member'),
          ],
        ),
      ),
    );
  }
}

class _ContactRequestList extends StatelessWidget {
  const _ContactRequestList({required this.source});

  final String source;

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

  int _compareCreatedAt(
    QueryDocumentSnapshot<Object?> a,
    QueryDocumentSnapshot<Object?> b,
  ) {
    final aData = a.data() as Map<String, dynamic>;
    final bData = b.data() as Map<String, dynamic>;

    final aTime = aData['createdAt'];
    final bTime = bData['createdAt'];

    if (aTime is Timestamp && bTime is Timestamp) {
      return bTime.compareTo(aTime);
    }

    if (aTime is Timestamp) return -1;
    if (bTime is Timestamp) return 1;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('platform_contact_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('讀取失敗：${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['source'] ?? '').toString() == source;
        }).toList()..sort(_compareCreatedAt);

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(source == 'shop_owner' ? '目前沒有店主聯絡案件' : '目前沒有會員聯絡案件'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final status = (data['status'] ?? 'open').toString();
            final category = (data['category'] ?? '未分類').toString();
            final title = (data['title'] ?? '未填標題').toString();
            final content = (data['content'] ?? '').toString();

            final imageCount = data['imageCount'] is int
                ? data['imageCount'] as int
                : 0;

            final createdAtText = _formatDate(data['createdAt']);

            final shopName = (data['shopName'] ?? '').toString();
            final shopCode = (data['shopCode'] ?? '').toString();
            final shopId = (data['shopId'] ?? '').toString();

            final userName = (data['userName'] ?? '').toString();
            final userPhone = (data['userPhone'] ?? '').toString();
            final userEmail = (data['userEmail'] ?? '').toString();

            final mainInfo = source == 'shop_owner'
                ? '店家：${shopName.isEmpty ? '未帶入店名' : shopName}'
                : '會員：${userName.isEmpty ? '未帶入姓名' : userName}';

            final secondInfo = source == 'shop_owner'
                ? '店編：${shopCode.isEmpty ? '-' : shopCode}｜店家 ID：${shopId.isEmpty ? '-' : shopId}'
                : '電話：${userPhone.isEmpty ? '-' : userPhone}｜信箱：${userEmail.isEmpty ? '-' : userEmail}';

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                  child: Icon(
                    source == 'shop_owner'
                        ? Icons.storefront
                        : Icons.person_outline,
                    color: _statusColor(status),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusText(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
                      Text(mainInfo),
                      Text(secondInfo),
                      Text('分類：$category'),
                      Text('送出時間：$createdAtText'),
                      if (imageCount > 0) Text('附件照片：$imageCount 張'),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlatformContactRequestDetailPage(requestId: doc.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
