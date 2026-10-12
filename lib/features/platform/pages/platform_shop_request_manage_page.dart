// 檔案名稱：lib/features/platform/pages/platform_shop_request_manage_page.dart
// 功能說明：平台審核店家資料修改、認證、前台公開等申請
// 📨 店家申請中心

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/legal_pet_service.dart';

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
      case 'supplement':
        return '補件';
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
      case 'supplement':
        return Colors.blue;
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
    required BuildContext context,
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
  }) async {
    final requestType = data['requestType']?.toString() ?? '';
    bool approveLicense = false;
    bool approveTaxId = false;
    bool approvePublic = false;
    bool applyProposedAddress = false;
    bool transferLicense = false;
    if (requestType == 'fullVerify') {
      final choice = await showDialog<Map<String, bool>>(
        context: context,
        builder: (dialogContext) {
          bool license = false;
          bool tax = false;
          bool publish = false;
          bool address = data['proposedAddress'] is Map;
          bool transfer = false;
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: const Text('分開核准'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: license,
                      title: const Text('核可特寵字號'),
                      onChanged: (value) =>
                          setLocal(() => license = value ?? false),
                    ),
                    CheckboxListTile(
                      value: tax,
                      title: const Text('核可統編'),
                      onChanged: (value) => setLocal(() => tax = value ?? false),
                    ),
                    CheckboxListTile(
                      value: publish,
                      title: const Text('開放平台公開'),
                      onChanged: (value) =>
                          setLocal(() => publish = value ?? false),
                    ),
                    CheckboxListTile(
                      value: address,
                      title: const Text('套用擬更正地址'),
                      onChanged: (value) =>
                          setLocal(() => address = value ?? false),
                    ),
                    CheckboxListTile(
                      value: transfer,
                      title: const Text('字號已綁定其他店時，改綁到這家'),
                      onChanged: (value) =>
                          setLocal(() => transfer = value ?? false),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, {
                      'license': license,
                      'tax': tax,
                      'public': publish,
                      'address': address,
                      'transfer': transfer,
                    }),
                    child: const Text('送出核准'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (choice == null || !context.mounted) return;
      approveLicense = choice['license'] == true;
      approveTaxId = choice['tax'] == true;
      approvePublic = choice['public'] == true;
      applyProposedAddress = choice['address'] == true;
      transferLicense = choice['transfer'] == true;
    }
    await _sendReview(
      context: context,
      requestId: doc.id,
      action: 'approve',
      approveLicense: approveLicense,
      approveTaxId: approveTaxId,
      approvePublic: approvePublic,
      applyProposedAddress: applyProposedAddress,
      transferLicense: transferLicense,
    );
  }

  Future<void> _sendReview({
    required BuildContext context,
    required String requestId,
    required String action,
    String reviewNote = '',
    bool approveLicense = false,
    bool approveTaxId = false,
    bool approvePublic = false,
    bool applyProposedAddress = false,
    bool transferLicense = false,
  }) async {
    try {
      await LegalPetService.instance.reviewRequest({
        'requestId': requestId,
        'action': action,
        'reviewNote': reviewNote,
        'approveLicense': approveLicense,
        'approveTaxId': approveTaxId,
        'approvePublic': approvePublic,
        'applyProposedAddress': applyProposedAddress,
        'transferLicense': transferLicense,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('審核已送出')),
      );
    } on LegalPetException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
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

    if (rejectReason == null ||
        rejectReason.isEmpty ||
        !context.mounted) {
      return;
    }

    await _sendReview(
      context: context,
      requestId: doc.id,
      action: 'reject',
      reviewNote: rejectReason,
    );
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
      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                if ((data['addressDifferenceNote'] ?? '').toString().isNotEmpty)
                  Text('地址差異說明：${data['addressDifferenceNote']}'),
                if ((data['checkResult'] ?? '').toString().isNotEmpty)
                  Text('字號查核：${data['checkResult']}'),
                if ((data['addressComparison'] ?? '').toString().isNotEmpty)
                  Text('地址比對：${data['addressComparison']}'),
                if ((data['licenseBindingShopId'] ?? '').toString().isNotEmpty)
                  Text('字號目前綁定店家：${data['licenseBindingShopId']}'),
                if (data['shopSnapshot'] is Map)
                  Text('送件店家資料：${data['shopSnapshot']}'),
                if (data['governmentSnapshot'] is Map)
                  Text('送件政府資料：${data['governmentSnapshot']}'),
                if (data['proposedAddress'] is Map)
                  Text('擬更正地址：${data['proposedAddress']}'),
                if ((data['addressProofImageUrl'] ?? '').toString().isNotEmpty)
                  _buildImagePreview(
                    title: '地址差異證明',
                    imageUrl: data['addressProofImageUrl'].toString(),
                  ),

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
                            await _approveRequest(
                              context: context,
                              doc: doc,
                              data: data,
                            );
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final reasonController = TextEditingController();
                            final reason = await showDialog<String>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('要求補件'),
                                  content: TextField(
                                    controller: reasonController,
                                    decoration: const InputDecoration(
                                      labelText: '補件原因',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                        dialogContext,
                                        reasonController.text.trim(),
                                      ),
                                      child: const Text('送出'),
                                    ),
                                  ],
                                );
                              },
                            );
                            reasonController.dispose();
                            if (reason == null || reason.isEmpty) return;
                            if (!context.mounted) return;
                            await _sendReview(
                              context: context,
                              requestId: doc.id,
                              action: 'supplement',
                              reviewNote: reason,
                            );
                          },
                          child: const Text('補件'),
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
