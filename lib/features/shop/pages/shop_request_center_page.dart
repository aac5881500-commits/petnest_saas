// 檔案名稱：lib/features/shop/pages/shop_request_center_page.dart
// 功能說明：店家查看重要資料修改申請、審核狀態與拒絕原因
// 📨 店家-店家端 申請中心

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShopRequestCenterPage extends StatelessWidget {
  const ShopRequestCenterPage({super.key, required this.shopId});

  final String shopId;

  String _typeLabel(String type) {
    switch (type) {
      case 'name':
        return '店名修改';
      case 'phone':
        return '電話修改';
      case 'address':
        return '地址搬遷';
      case 'licenseNumber':
        return '特寵字號修改';
      case 'taxId':
        return '統編修改';
      default:
        return '資料修改';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '審核中';
      case 'approved':
        return '已核准';
      case 'rejected':
        return '已拒絕';
      default:
        return '未知';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(dynamic value) {
    if (value is! Timestamp) return '尚未記錄';

    final date = value.toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs, bool done) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString() ?? 'pending';
      return done ? status != 'pending' : status == 'pending';
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text(done ? '目前沒有處理完成紀錄' : '目前尚無待審核申請'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = filtered[index].data() as Map<String, dynamic>;

        final requestType = data['requestType']?.toString() ?? '';
        final status = data['status']?.toString() ?? 'pending';
        final newValue = data['newValue']?.toString() ?? '';
        final currentValue = data['currentValue']?.toString() ?? '';
        final reason = data['reason']?.toString() ?? '';
        final reviewNote = data['reviewNote']?.toString() ?? '';
        final applicantEmail = data['applicantEmail']?.toString() ?? '';
        final createdAt = data['createdAt'];
        final reviewedAt = data['reviewedAt'];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(requestType),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (applicantEmail.isNotEmpty) Text('申請人：$applicantEmail'),
                Text('申請時間：${_formatDateTime(createdAt)}'),
                if (done) Text('處理時間：${_formatDateTime(reviewedAt)}'),
                if (currentValue.isNotEmpty) Text('目前資料：$currentValue'),
                if (newValue.isNotEmpty) Text('申請修改為：$newValue'),
                if (reason.isNotEmpty) Text('申請原因：$reason'),
                if (!done && status == 'pending') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('shop_change_requests')
                            .doc(filtered[index].id)
                            .update({
                              'status': 'cancelled',
                              'reviewNote': '店家自行取消申請',
                              'reviewedAt': FieldValue.serverTimestamp(),
                            });
                      },
                      child: const Text('取消申請'),
                    ),
                  ),
                ],
                if (reviewNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    status == 'rejected'
                        ? '拒絕原因：$reviewNote'
                        : '平台回覆：$reviewNote',
                    style: TextStyle(
                      color: status == 'rejected' ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('店家申請中心'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '待處理'),
              Tab(text: '處理完成紀錄'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shop_change_requests')
              .where('shopId', isEqualTo: shopId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            return TabBarView(
              children: [_buildList(docs, false), _buildList(docs, true)],
            );
          },
        ),
      ),
    );
  }
}
