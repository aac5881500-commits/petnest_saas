// lib/features/platform/pages/platform_shop_request_manage_page.dart
// 📨 店家申請中心
// 功能：平台審核店家資料修改、認證、前台公開等申請

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlatformShopRequestManagePage extends StatelessWidget {
  const PlatformShopRequestManagePage({super.key});

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
      case 'fullVerify':
        return '店家認證／平台公開';
      case 'lineUrl':
        return 'LINE 連結修改';

      case 'igUrl':
        return 'IG 連結修改';

      case 'fbUrl':
        return 'FB 連結修改';
      default:
        return '資料修改';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待處理';
      case 'approved':
        return '已核准';
      case 'rejected':
        return '已拒絕';
      case 'cancelled':
        return '已取消';
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
      case 'cancelled':
        return Colors.grey;
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

  Future<void> _approveRequest({
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
  }) async {
    final shopId = data['shopId']?.toString() ?? '';
    final requestType = data['requestType']?.toString() ?? '';
    final newValue = data['newValue']?.toString() ?? '';
    final currentValue = data['currentValue']?.toString() ?? '';

    final newCity = data['newCity']?.toString() ?? '';
    final newDistrict = data['newDistrict']?.toString() ?? '';
    final newAddress = data['newAddress']?.toString() ?? '';

    if (shopId.isEmpty) return;

    if (requestType == 'fullVerify') {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'licenseVerified': true,
        'taxIdVerified': true,
        'isPublic': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (requestType == 'address') {
      if (newCity.isEmpty || newDistrict.isEmpty || newAddress.isEmpty) {
        return;
      }

      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'city': newCity,
        'district': newDistrict,
        'address': newAddress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      String? fieldName;

      switch (requestType) {
        case 'name':
          fieldName = 'name';
          break;

        case 'phone':
          fieldName = 'phone';
          break;

        case 'licenseNumber':
          fieldName = 'licenseNumber';
          break;

        case 'taxId':
          fieldName = 'taxId';
          break;

        case 'lineUrl':
          fieldName = 'lineUrl';
          break;

        case 'igUrl':
          fieldName = 'igUrl';
          break;

        case 'fbUrl':
          fieldName = 'fbUrl';
          break;
      }

      if (fieldName == null || newValue.trim().isEmpty) return;

      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        fieldName: newValue.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    String reviewNote = '平台已核准';

    switch (requestType) {
      case 'fullVerify':
        reviewNote = '平台已完成店家認證，並開放平台公開';
        break;

      default:
        reviewNote = '平台已核准並更新資料';
    }
    await FirebaseFirestore.instance
        .collection('shop_change_requests')
        .doc(doc.id)
        .update({
          'status': 'approved',
          'reviewNote': reviewNote,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _rejectRequest({
    required BuildContext context,
    required QueryDocumentSnapshot doc,
  }) async {
    final reasonController = TextEditingController();

    final rejectReason = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('拒絕申請'),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '拒絕原因',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = reasonController.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: const Text('確認拒絕'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (rejectReason == null || rejectReason.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('shop_change_requests')
        .doc(doc.id)
        .update({
          'status': 'rejected',
          'reviewNote': rejectReason,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
  }

  Widget _buildImagePreview({required String title, required String imageUrl}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList({
    required BuildContext context,
    required List<QueryDocumentSnapshot> docs,
    required bool done,
  }) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString() ?? 'pending';

      return done ? status != 'pending' : status == 'pending';
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text(done ? '目前沒有處理完成紀錄' : '目前尚無待處理申請'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = filtered[index];
        final data = doc.data() as Map<String, dynamic>;

        final shopName = data['shopName']?.toString() ?? '未知店家';
        final shopId = data['shopId']?.toString() ?? '';
        final applicantEmail = data['applicantEmail']?.toString() ?? '';
        final requestType = data['requestType']?.toString() ?? '';
        final newValue = data['newValue']?.toString() ?? '';
        final reason = data['reason']?.toString() ?? '';
        final currentValue = data['currentValue']?.toString() ?? '';
        final status = data['status']?.toString() ?? 'pending';
        final reviewNote = data['reviewNote']?.toString() ?? '';
        final contactName = data['contactName']?.toString() ?? '';
        final contactPhone = data['contactPhone']?.toString() ?? '';
        final contactTitle = data['contactTitle']?.toString() ?? '';
        final contactProofImageUrl =
            data['contactProofImageUrl']?.toString() ?? '';
        final licenseImageUrl = data['licenseImageUrl']?.toString() ?? '';
        final taxIdImageUrl = data['taxIdImageUrl']?.toString() ?? '';
        final createdAt = data['createdAt'];
        final reviewedAt = data['reviewedAt'];

        return Card(
          color: done ? Colors.white : const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text('申請類型：${_typeLabel(requestType)}'),
                if (shopId.isNotEmpty) Text('店家ID：$shopId'),
                if (applicantEmail.isNotEmpty) Text('申請人：$applicantEmail'),
                Text('申請時間：${_formatDateTime(createdAt)}'),
                if (contactName.isNotEmpty) Text('聯絡人姓名：$contactName'),
                if (contactPhone.isNotEmpty) Text('聯絡電話：$contactPhone'),
                if (contactTitle.isNotEmpty) Text('職稱／身分：$contactTitle'),
                if (contactProofImageUrl.isNotEmpty ||
                    licenseImageUrl.isNotEmpty ||
                    taxIdImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),

                  if (contactProofImageUrl.isNotEmpty)
                    _buildImagePreview(
                      title: '聯絡人證明照片',
                      imageUrl: contactProofImageUrl,
                    ),

                  if (licenseImageUrl.isNotEmpty)
                    _buildImagePreview(
                      title: '特寵字號證明照片',
                      imageUrl: licenseImageUrl,
                    ),

                  if (taxIdImageUrl.isNotEmpty)
                    _buildImagePreview(
                      title: '統編證明照片',
                      imageUrl: taxIdImageUrl,
                    ),
                ],
                if (done) Text('處理時間：${_formatDateTime(reviewedAt)}'),

                if (currentValue.isNotEmpty) Text('目前資料：$currentValue'),

                if (newValue.isNotEmpty) Text('申請修改為：$newValue'),

                if (reason.isNotEmpty) Text('申請原因：$reason'),

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

                if (!done) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _approveRequest(doc: doc, data: data);
                          },
                          child: const Text('核准'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _rejectRequest(context: context, doc: doc);
                          },
                          child: const Text('拒絕'),
                        ),
                      ),
                    ],
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
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text('店家申請中心'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '待處理申請'),
              Tab(text: '處理完成紀錄'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shop_change_requests')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            return TabBarView(
              children: [
                _buildRequestList(context: context, docs: docs, done: false),
                _buildRequestList(context: context, docs: docs, done: true),
              ],
            );
          },
        ),
      ),
    );
  }
}
