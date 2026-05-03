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
                /// 🔥 房間主卡片（取代基本資訊）
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
    color: Colors.blueGrey.shade900,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 🔥 房號 + 房型 + 晚數
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          /// 左邊：房號＋房型
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['roomName'] ?? '-',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                data['roomTypeName'] ?? '',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),

          /// 右邊：幾晚
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${data['nights'] ?? 0} 晚',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 14),

      /// 🔥 日期區（入住 → 退房）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          /// 入住
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '入住',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                _formatDate(start),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Icon(Icons.arrow_forward, color: Colors.white),

          /// 退房
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '退房',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                _formatDate(end),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          /// 下訂時間
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '下訂',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                _formatDateTime(data['createdAt']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
),

                _sectionTitle('顧客資訊'),

Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
      ),
    ],
  ),
  child: Column(
    children: [

      /// 第一排
      Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoItem('姓名', data['customerName']),
          const SizedBox(height: 6),
          _infoItem('地址', data['address']), // 🔥 地址搬上來
        ],
      ),
    ),
    Expanded(child: _infoItem('電話', data['customerPhone'])),
  ],
),

      const SizedBox(height: 10),

      /// 第二排
      Row(
        children: [
          Expanded(child: _infoItem('緊急聯絡人', emergency['name'])),
          Expanded(child: _infoItem('緊急電話', emergency['phone'])),
        ],
      ),

      const SizedBox(height: 10),

      /// 第三排
      Row(
  children: [
    Expanded(child: _infoItem('關係', emergency['relation'])),
    Expanded(child: _infoItem('緊急地址', emergency['address'])), // 🔥 改這
  ],
),
    ],
  ),
),

                _sectionTitle('寵物資訊 (${pets.length}隻)'),

GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: pets.length,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 0.65, // 🔥 原本0.8 → 改這個
),
  itemBuilder: (context, index) {
    final pet = pets[index];
    return _petCard(pet);
  },
),

                _sectionTitle('價格'),

Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.grey.shade50,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Column(
    children: [

      /// 🏠 房費
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('房費'),
          Text(
            'NT\$ $basePrice × $nights 晚',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'NT\$ $roomPriceTotal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),

      const SizedBox(height: 8),

      /// 🐱 寵物加價
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('寵物加價'),
          Text(
            extraPetCount > 0
                ? 'NT\$ $extraPetPrice × $extraPetCount 隻 × $nights 晚'
                : '-',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'NT\$ $petPriceTotal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),

      const Divider(height: 24),

      /// 💰 小計
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '小計',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'NT\$ $correctSubtotal',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ],
  ),
),

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

return Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.orange.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.orange.shade200),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 🔥 第一排：名稱 + 價格
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('🐾 ', style: TextStyle(fontSize: 16)),
              Text(
                item['name'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          Text(
            '+NT\$ $total',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),

      const SizedBox(height: 8),

      /// 🔥 第二排：計算公式（小字）
      if (count > 1)
        Text(
          '$price x $count = $total',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),

      /// 🔥 第三排：指定寵物（重點）
      if (item['type'] == 'custom' && petNames.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '👉 指定寵物：${petNames.join('、')}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ),
    ],
  ),
);
        },
      ),
    ],
  ),

const SizedBox(height: 10),

/// 🔥 總價卡片（強化）
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.only(top: 10),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 💰 總價（大字）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '總價',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            'NT\$ ${data['totalPrice'] ?? 0}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red, // 🔥 收錢感
            ),
          ),
        ],
      ),

      const SizedBox(height: 10),

      /// 💳 訂金（小一點）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '訂金',
            style: TextStyle(color: Colors.grey),
          ),
          Text(
            'NT\$ ${data['depositAmount'] ?? 0}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: (data['depositPaid'] == true)
                  ? Colors.green
                  : Colors.grey,
            ),
          ),
        ],
      ),
    ],
  ),
),
/// 🔥 訂金狀態
if (depositAmount > 0)
  Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: depositPaid
          ? Colors.green.shade100
          : Colors.red.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      depositPaid ? '✅ 已收到訂金' : '❌ 尚未確認訂金',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: depositPaid ? Colors.green : Colors.red,
      ),
    ),
  )
else
  Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      '💡 本訂單無需訂金',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    ),
  ),
/// 🔥 客戶轉帳資訊
const SizedBox(height: 10),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.blue.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.blue.shade200),
  ),
  child: Row(
    children: [

      /// icon
      const Icon(Icons.payment, color: Colors.blue),

      const SizedBox(width: 10),

      /// 文字
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '付款方式',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              paymentMethodText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      /// 金額型態
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          payAmountTypeText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
),
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
  Container(
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔥 標題
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Text(
            '📷 客戶轉帳截圖',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ),

        /// 🔥 圖片
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
          child: Image.network(
            data['transferImageUrl'],
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    ),
  ),
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
Widget _priceRow(String label, String value, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
Widget _infoItem(String label, dynamic value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value?.toString() ?? '-',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
Widget _petCard(Map<String, dynamic> pet) {
  final medical = pet['medicalStatus'] ?? '';
  final staffNote = pet['staffNote'] ?? '';
  final isNeutered = pet['isNeutered'] == true;

  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      children: [

        /// 🐱 頭像
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
              (pet['photoUrl'] != null && pet['photoUrl'] != '')
                  ? NetworkImage(pet['photoUrl'])
                  : null,
          child: (pet['photoUrl'] == null || pet['photoUrl'] == '')
              ? const Icon(Icons.pets)
              : null,
        ),

        const SizedBox(height: 6),

        /// 名字
        Text(
          pet['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

/// 年齡
if ((pet['age'] ?? '').toString().isNotEmpty)
  Text(
    pet['age'],
    style: const TextStyle(
      fontSize: 11,
      color: Colors.grey,
    ),
  ),

        /// 品種標籤
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            pet['breed'] ?? '',
            style: const TextStyle(fontSize: 11),
          ),
        ),

        const SizedBox(height: 4),

        /// ⚠️ 醫療
        if (medical.toString().isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 14, color: Colors.red),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  medical,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

/// 📝 客戶備註
if ((pet['note'] ?? '').toString().isNotEmpty)
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('📝 ', style: TextStyle(fontSize: 12)),
      Flexible(
        child: Text(
          '客戶：${pet['note']}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),

        /// ✏️ 員工備註
        if (staffNote.toString().isNotEmpty)
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('📌 ', style: TextStyle(fontSize: 12)),
      Flexible(
        child: Text(
          '員工：$staffNote',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),

        const Spacer(),


        /// 結紮
        Text(
          isNeutered ? '已結紮' : '未結紮',
          style: TextStyle(
            fontSize: 11,
            color: isNeutered ? Colors.green : Colors.grey,
          ),
        ),
      ],
    ),
  );
}
}