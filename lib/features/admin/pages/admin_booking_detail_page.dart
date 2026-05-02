// lib/features/admin/pages/admin_booking_detail_page.dart

// 📄 訂單詳細頁（後台版）
//
//  店主自己的後台店家詳細頁

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

          final basePrice = data['basePrice'] ?? 0;
final extraPetPrice = data['extraPetPrice'] ?? 0;
final extraPetCount = data['extraPetCount'] ?? 0;
final extraPetTotal = data['extraPetTotal'] ?? 0;
final roomSubtotal = data['roomSubtotal'] ?? 0;

final nights = data['nights'] ?? 1;
final roomPriceTotal = basePrice * nights;
final petPriceTotal = extraPetTotal;
final correctSubtotal = roomPriceTotal + petPriceTotal;

          final start =
              (data['startDate'] as Timestamp).toDate();
          final end =
              (data['endDate'] as Timestamp).toDate();

          final rawPets = data['pets'];

final pets = rawPets is List

    ? rawPets.map((e) => e as Map<String, dynamic>).toList()
    : [];

final petMap = {
  for (var pet in pets)
    pet['name']: pet['name']
};

          final status = data['status'] ?? 'pending';

          final emergency = Map<String, dynamic>.from(
  data['emergencyContact'] ?? {},
);

final paymentMethodText = _paymentMethodText(data['paymentMethod']);
final payAmountTypeText = _payAmountTypeText(data['payAmountType']);

final depositPaid = data['depositPaid'] == true;
final depositAmount = data['depositAmount'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('基本資訊'),
                _infoRow('下訂時間', _formatDateTime(data['createdAt'])),
_infoRow('房型', data['roomTypeName'] ?? '-'),
_infoRow('房號', data['roomName'] ?? '-'),
_infoRow('房號ID', data['roomId'] ?? '-'),
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

_infoRow(
  '房型價格',
  'NT\$ $basePrice x ${data['nights']}晚 = NT\$ ${basePrice * (data['nights'] ?? 1)}',
),
_infoRow(
  '寵物加價',
  extraPetCount > 0
      ? '$extraPetPrice x $extraPetCount隻 x $nights晚 = NT\$ $petPriceTotal'
      : 'NT\$ 0',
),
_infoRow('房費小計', 'NT\$ $correctSubtotal'),

const SizedBox(height: 10),

/// 🔥 加值服務
if ((data['addons'] ?? []).isNotEmpty)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '加值服務',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),

      ...List.generate(
        (data['addons'] as List).length,
        (index) {
          final item = data['addons'][index];

          final price = item['price'] ?? 0;
          final count = item['count'] ?? 1;
          final total = item['total'] ?? (price * count);

          final petIds = (item['petNames'] ?? []) as List;

final petNames = petIds
    .map((id) {
      final match = pets.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['name'] == id || p?['petId'] == id,
        orElse: () => null,
      );

      return match != null ? match['name'] : id;
    })
    .where((name) => name != null && name.toString().isNotEmpty)
    .toList();

return Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    /// 🔥 服務名稱
    Text(
      '🐾 ${item['name']}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),

    /// 🔥 客製化 → 顯示寵物（重點強化）
    if (item['type'] == 'custom' && petNames.isNotEmpty)
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '👉 指定寵物：${petNames.join('、')}',
          style: const TextStyle(
            color: Colors.deepOrange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
  ],
),
              Text(
                count > 1
                    ? '$price x $count = $total'
                    : '+$price',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    ],
  ),

const SizedBox(height: 10),

/// 🔥 總價
_infoRow('總價', 'NT\$ ${data['totalPrice'] ?? 0}'),

/// 🔥 訂金
_infoRow('訂金', 'NT\$ ${data['depositAmount'] ?? 0}'),
Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: depositPaid ? Colors.green.shade100 : Colors.red.shade100,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    depositPaid ? '✅ 已收到訂金' : '❌ 尚未確認訂金',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: depositPaid ? Colors.green : Colors.red,
    ),
  ),
),
/// 🔥 客戶轉帳資訊
if (data['transferLast5'] != null)
  const SizedBox(height: 10),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.yellow.shade100,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.orange),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '⚠️ 客戶轉帳後五碼',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        data['transferLast5'] ?? '未填寫',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),

const SizedBox(height: 8),

if (data['transferImageUrl'] != null)
  ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.network(
      data['transferImageUrl'],
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  ),
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
    if (status == 'pending' && depositAmount <= 0)
  ElevatedButton(
    onPressed: () => _updateStatus('confirmed'),
    child: const Text('確認'),
  ),

if (status == 'pending' && depositAmount > 0 && depositPaid != true)
  ElevatedButton(
    onPressed: () => _confirmDepositAndBooking(),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
    child: const Text('確認收到訂金'),
  ),

if (status == 'pending' && depositAmount > 0 && depositPaid)
  ElevatedButton(
    onPressed: () => _updateStatus('confirmed'),
    child: const Text('確認訂單'),
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
Future<void> _confirmDepositAndBooking() async {
  final user = FirebaseAuth.instance.currentUser;

  await FirebaseFirestore.instance
      .collection('bookings')
      .doc(bookingId)
      .update({
    'depositPaid': true,
    'depositPaidAt': FieldValue.serverTimestamp(),
    'status': 'confirmed',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  await FirebaseFirestore.instance
      .collection('action_logs')
      .add({
    'type': 'deposit_confirmed',
    'bookingId': bookingId,
    'operatorUid': user?.uid,
    'operatorRole': 'staff',
    'createdAt': FieldValue.serverTimestamp(),
  });
}
String _formatDateTime(dynamic value) {
  if (value == null) return '-';
  final date = (value as Timestamp).toDate();
  return '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}';
}
}