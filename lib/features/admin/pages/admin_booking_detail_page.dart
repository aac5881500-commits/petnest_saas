// lib/features/admin/pages/admin_booking_detail_page.dart
// 📄 訂單詳細頁（後台版）
//
// 功能：
// - 即時讀取 booking（Firestore）
// - 顯示完整訂單資料
// - 可操作狀態（確認 / 完成 / 取消）
// - 未來可擴充員工操作


import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/booking_service.dart';

class AdminBookingDetailPage extends StatelessWidget {
  const AdminBookingDetailPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單詳細'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('訂單不存在'));
          }

          final data = doc.data() as Map<String, dynamic>;

          final start =
              (data['startDate'] as Timestamp).toDate();
          final end =
              (data['endDate'] as Timestamp).toDate();

          final pets = (data['pets'] as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];

          final status = data['status'] ?? 'pending';

          final emergency = Map<String, dynamic>.from(
  data['emergencyContact'] ?? {},
);

final paymentMethodText = _paymentMethodText(data['paymentMethod']);
final payAmountTypeText = _payAmountTypeText(data['payAmountType']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('基本資訊'),

                _infoRow('房型', data['roomName'] ?? '-'),
                _infoRow('服務', data['serviceType'] ?? '-'),
                _infoRow('入住日', _formatDate(start)),
                _infoRow('退房日', _formatDate(end)),
                _infoRow('晚數', '${data['nights'] ?? 0} 晚'),

                const SizedBox(height: 16),

                _sectionTitle('顧客資訊'),

                _infoRow('姓名', data['customerName'] ?? '-'),
                _infoRow('電話', data['customerPhone'] ?? '-'),
                _infoRow('地址', data['address'] ?? '-'),
_infoRow('緊急聯絡人', emergency['name'] ?? '-'),
_infoRow('緊急電話', emergency['phone'] ?? '-'),
_infoRow('關係', emergency['relation'] ?? '-'),
_infoRow('緊急地址', emergency['address'] ?? '-'),
_infoRow('備用電話', emergency['phone2'] ?? '-'),

                const SizedBox(height: 16),

                _sectionTitle('寵物'),

                ...pets.map((pet) {
  final staffNote = pet['staffNote'] ?? '';
  final breed = pet['breed'] ?? pet['type'] ?? '-';

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      title: Text(
        pet['name'] ?? '寵物',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('品種：$breed'),
          if (staffNote.toString().isNotEmpty)
            Text(
              '員工備註：$staffNote',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        _infoRow('性別', pet['gender'] ?? '-'),
        _infoRow('年齡', pet['age'] ?? '-'),
        _infoRow(
          '結紮',
          pet['isNeutered'] == true ? '已結紮' : '未結紮',
        ),
        _infoRow('醫療狀況', pet['medicalStatus'] ?? '-'),
        _infoRow('貓砂', pet['litterType'] ?? '-'),
        _infoRow('備註', pet['note'] ?? '-'),
      ],
    ),
  );
}),

                const SizedBox(height: 16),

                _sectionTitle('價格'),

                _infoRow('總價', 'NT\$ ${data['totalPrice'] ?? 0}'),

                _infoRow('訂金', 'NT\$ ${data['depositAmount'] ?? 0}'),
_infoRow('付款方式', paymentMethodText),
_infoRow('付款金額', payAmountTypeText),

                const SizedBox(height: 16),

                _sectionTitle('狀態'),

                _statusChip(status),

                const SizedBox(height: 16),

                Wrap(
  spacing: 8,
  children: [

    /// 👉 pending → confirmed
    if (status == 'pending')
      ElevatedButton(
        onPressed: () => _updateStatus('confirmed'),
        child: const Text('確認'),
      ),

    /// 👉 pending → cancelled
    if (status == 'pending')
      ElevatedButton(
        onPressed: () => _updateStatus('cancelled'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('取消'),
      ),

    /// 👉 confirmed → completed
    /// 👉 confirmed → checked_in（入住）
if (status == 'confirmed')
  ElevatedButton(
    onPressed: () => _updateStatus('checked_in'),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
    child: const Text('入住'),
  ),

/// 👉 checked_in → completed（退房）
if (status == 'checked_in')
  ElevatedButton(
    onPressed: () => _updateStatus('completed'),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
    child: const Text('退房完成'),
  ),

  ],
),
              ],
            ),
          );
        },
      ),
    );
  }

Future<void> _updateStatus(String status) async {
  final user = FirebaseAuth.instance.currentUser;

  /// 🔥 更新狀態
  await BookingService.instance.updateBookingStatus(
    bookingId: bookingId,
    status: status,
  );

  /// 🔥 紀錄操作
  await FirebaseFirestore.instance
      .collection('action_logs')
      .add({
    'type': 'booking_status_update',
    'bookingId': bookingId,
    'status': status,
    'operatorUid': user?.uid,
    'operatorRole': 'staff',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

  /// UI 小工具
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = '已確認';
        break;
case 'checked_in':
  color = Colors.blue;
  text = '入住中';
  break;
      case 'completed':
        color = Colors.grey;
        text = '已完成';
        break;
      case 'cancelled':
        color = Colors.red;
        text = '已取消';
        break;
      default:
        color = Colors.orange;
        text = '待確認';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
  String _paymentMethodText(dynamic value) {
  switch (value) {
    case 'cash':
      return '到店付款';
    case 'transfer':
      return '銀行轉帳';
    default:
      return '-';
  }
}

String _payAmountTypeText(dynamic value) {
  switch (value) {
    case 'deposit':
      return '先付訂金';
    case 'full':
      return '一次付清';
    default:
      return '-';
  }
}
}