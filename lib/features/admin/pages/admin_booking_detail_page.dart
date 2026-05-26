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
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';


class AdminBookingDetailPage extends StatelessWidget {
  const AdminBookingDetailPage({
    super.key,
    required this.bookingId,
    this.canEdit = true,
  });

  final String bookingId;

  /// 是否可操作訂單
  /// true：訂單管理進來，可確認 / 取消 / 入住 / 退房
  /// false：房務或會員詳細進來，只能查看
  final bool canEdit;

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
          final displayBookingCode =
    (data['bookingCode'] ?? '').toString().isNotEmpty
        ? data['bookingCode'].toString()
        : bookingId.substring(0, 8);
final extraPetPrice = data['extraPetPrice'] ?? 0;
final extraPetCount = data['extraPetCount'] ?? 0;
final extraPetTotal = data['extraPetTotal'] ?? 0;

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

          final status = data['status'] ?? 'pending';

          final emergency = Map<String, dynamic>.from(
  data['emergencyContact'] ?? {},
);

final paymentMethodText = _paymentMethodText(data['paymentMethod']);

final depositPaid = data['depositPaid'] == true;
final depositAmount = data['depositAmount'] ?? 0;
final depositRequired = data['depositRequired'] == true;


          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                /// 🔥 房間主卡片（取代基本資訊）
                if (data['source'] == 'admin')
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child:
    Row(
      children: [
        const Icon(Icons.edit_note, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
  text: TextSpan(
    style: TextStyle(
      color: Colors.blue.shade800,
      fontWeight: FontWeight.w900,
      fontSize: 14,
      height: 1.5,
    ),
    children: [
      TextSpan(
        text:
            '手動新增訂單｜${data['createdByEmail'] ?? '未知操作人員'}\n',
      ),

      const TextSpan(
        text:
            '⚠ 此訂單為店家後台手動建立。\n',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w900,
        ),
      ),

      const TextSpan(
        text:
            '• 不會自動套用訂金模式\n'
            '• 不會自動產生付款方式\n'
            '• 建立完成後，請店主自行確認訂單與收款狀態',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
),
        ),
      ],
    ),
  ),
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
Row(
  children: [
    const Text(
      '訂單編號：',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 12,
      ),
    ),

    Expanded(
      child: Text(
        displayBookingCode,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    GestureDetector(
      onTap: () async {
        await Clipboard.setData(
          ClipboardData(text: displayBookingCode),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已複製訂單編號'),
            ),
          );
        }
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(
          Icons.copy_rounded,
          color: Colors.white70,
          size: 18,
        ),
      ),
    ),
  ],
),

const SizedBox(height: 12),
      /// 🔥 房號 + 房型 + 晚數
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [


          /// 左邊：房號＋房型
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
  data['assignStatus'] == 'unassigned'
      ? '待分房'
      : (data['roomName'] ?? '-'),
  style: const TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  ),
),
              Text(
  data['assignStatus'] == 'unassigned'
      ? '${data['roomTypeName'] ?? ''}｜尚未選房間'
      : (data['roomTypeName'] ?? ''),
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
    return AdminBookingPetCard(pet: pet);
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
    child: Row(
  children: [
    Expanded(
      child: Text(
        depositPaid ? '✅ 已收到訂金' : '❌ 尚未確認訂金',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: depositPaid ? Colors.green : Colors.red,
        ),
      ),
    ),

    if (!depositPaid && data['depositExpireAt'] != null)
      Text(
        _formatDateTime(data['depositExpireAt']),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.red.shade700,
        ),
      ),
  ],
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
  padding: const EdgeInsets.all(14),
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
    ],
  ),
),
if (data['paymentMethod'] == 'transfer') ...[
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
          (data['transferLast5'] ?? '').toString().isEmpty
              ? '未填寫'
              : data['transferLast5'].toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  ),
],

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

        /// 🔥 圖片，可點開放大檢查
GestureDetector(
  onTap: () {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            data['transferImageUrl'],
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  },
  child: ClipRRect(
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
),
      ],
    ),
  ),

_sectionTitle('退房額外費用'),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  margin: const EdgeInsets.only(bottom: 16),
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
  child: (data['extraCharges'] ?? []).isEmpty
      ? const Text(
          '目前無額外費用',
          style: TextStyle(color: Colors.grey),
        )
      : Column(
          children: List.generate(
            (data['extraCharges'] as List).length,
            (index) {
              final item = data['extraCharges'][index];
              final title = item['title'] ?? '額外費用';
              final amount = item['amount'] ?? 0;
              final note = item['note'] ?? '';
              final imageUrls = (item['imageUrls'] ?? []) as List;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'NT\$ $amount',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    if (note.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note.toString(),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],

                    if (imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(imageUrls.length, (imgIndex) {
                          final url = imageUrls[imgIndex].toString();

                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                url,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
),

_sectionTitle('訂單備註'),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
    color: Colors.grey.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: Text(
    (data['note'] ?? '').toString().trim().isEmpty
        ? '無備註'
        : data['note'].toString(),
    style: const TextStyle(
      fontSize: 15,
      height: 1.5,
    ),
  ),
),

_sectionTitle('訂單時間軸'),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  margin: const EdgeInsets.only(bottom: 16),
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
      _timelineItem(
        title: '已送出預約',
        time: _formatDateTime(data['createdAt']),
        active: true,
      ),

      if (depositRequired)
  _timelineItem(
    title: '付款 / 訂單保留期限',
    time: _formatDateTime(data['depositExpireAt']),
    active: data['depositExpireAt'] != null,
  ),

      _timelineItem(
        title: '店家已確認',
        time: _formatDateTime(data['confirmedAt']),
        active: data['confirmedAt'] != null,
      ),

      _timelineItem(
        title: '入住',
        time: _formatDateTime(data['checkInAt']),
        active: data['checkInAt'] != null,
      ),

      _timelineItem(
        title: '退房完成',
        time: _formatDateTime(data['checkOutAt']),
        active: data['checkOutAt'] != null,
      ),

      if (status == 'cancelled')
        _timelineItem(
          title: '訂單已取消',
          time: _formatDateTime(data['cancelledAt']),
          active: true,
          isLast: true,
        )
      else
        _timelineItem(
          title: '訂單完成',
          time: _formatDateTime(data['checkOutAt']),
          active: status == 'completed',
          isLast: true,
        ),
    ],
  ),
),


                _sectionTitle('狀態'),

                _statusChip(status),

if (status == 'cancelled') ...[
  const SizedBox(height: 10),
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '取消原因：${data['cancelReason'] ?? '未填寫'}',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '取消來源：${_cancelByText(data['cancelBy'])}',
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 13,
          ),
        ),
      ],
    ),
  ),
],

                const SizedBox(height: 16),

_sectionTitle('操作紀錄'),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  margin: const EdgeInsets.only(bottom: 16),
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
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('action_logs')
        .where('bookingId', isEqualTo: bookingId)
        .snapshots(),
    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final logs = snapshot.data!.docs;

      if (logs.isEmpty) {
        return const Text(
          '目前無操作紀錄',
          style: TextStyle(color: Colors.grey),
        );
      }

      return Column(
        children: logs.map((doc) {

          final log = doc.data() as Map<String, dynamic>;

          return _actionLogCard(log);

        }).toList(),
      );
    },
  ),
),

                if (canEdit)
  Wrap(
    spacing: 8,
    children: [

/// 🏠 待分房 → 選擇房間
if (data['assignStatus'] == 'unassigned' &&
    status != 'cancelled' &&
    status != 'completed')
  ElevatedButton.icon(
    onPressed: () async {
  await _showAssignRoomDialog(
    context: context,
    data: data,
  );
},
    icon: const Icon(Icons.meeting_room),
    label: const Text('選擇房間'),
  ),
  if (status == 'pending' &&
    data['assignStatus'] != 'assigned')
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Text(
      '請先完成分房，才能確認訂單',
      style: TextStyle(
        color: Colors.orange.shade800,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),

    /// 👉 pending → confirmed
    if (status == 'pending' &&
    depositAmount <= 0 &&
    data['assignStatus'] == 'assigned')
  ElevatedButton(
    onPressed: () async {

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      await _updateStatus('confirmed');
    },
    child: const Text('確認'),
  ),

if (status == 'pending' && depositAmount > 0 && depositPaid != true)
  ElevatedButton(
    onPressed: () => _confirmDepositAndBooking(),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
    child: const Text('確認收到訂金'),
  ),

if (status == 'pending' &&
    depositAmount > 0 &&
    depositPaid &&
    data['assignStatus'] == 'assigned')
  ElevatedButton(
    onPressed: () => _updateStatus('confirmed'),
    child: const Text('確認訂單'),
  ),

    /// 👉 pending → cancelled
   if (status == 'pending' || status == 'confirmed')
  ElevatedButton(
    onPressed: () async {
      await _cancelBookingWithReason(
        context: context,
        data: data,
      );
    },
    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
    child: const Text('取消訂單'),
  ),
    /// 👉 confirmed → completed
    /// 👉 confirmed → checked_in（入住）
if (status == 'confirmed')
  ElevatedButton(
    onPressed: () async {
      if (data['assignStatus'] != 'assigned' ||
          data['roomId'] == null ||
          data['roomName'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('此訂單尚未分房，不能辦理入住'),
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'checkInAt': FieldValue.serverTimestamp(),
      });

      await _updateStatus('checked_in');
    },
    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
    child: const Text('入住'),
  ),

/// 🔁 已分房後可更換房間（先預留入口）
if (data['assignStatus'] == 'assigned' &&
    status != 'cancelled' &&
    status != 'completed')
  ElevatedButton.icon(
    onPressed: () async {
  await _showChangeRoomDialog(
    context: context,
    data: data,
  );
},
    icon: const Icon(Icons.swap_horiz),
    label: const Text('更換房間'),
  ),

/// 👉 checked_in → completed（退房）
if (status == 'checked_in')
  ElevatedButton(
    onPressed: () async {
  final extraFeeController = TextEditingController();

 final extraChargeTitleController =
    TextEditingController(text: '額外清潔費');
final extraChargeNoteController = TextEditingController();

List<XFile> extraChargeImages = [];
bool isUploadingExtraImage = false;

  final result = await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('退房 - 額外收費'),
        content: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    TextField(
      controller: extraChargeTitleController,
      decoration: const InputDecoration(
  labelText: '費用名稱',
  hintText: '例如：額外清潔費',
),
    ),

    const SizedBox(height: 12),

    TextField(
      controller: extraFeeController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: '金額',
        hintText: '例如：300',
      ),
    ),

    const SizedBox(height: 12),

    TextField(
      controller: extraChargeNoteController,
      decoration: const InputDecoration(
        labelText: '備註',
        hintText: '例如：退房時發現亂尿尿',
      ),
    ),
    const SizedBox(height: 12),

StatefulBuilder(
  builder: (context, setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {

  if (isUploadingExtraImage) return;

  if (extraChargeImages.length >= 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('最多只能上傳 3 張照片'),
      ),
    );
    return;
  }

  setDialogState(() {
    isUploadingExtraImage = true;
  });

  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    imageQuality: 75,
  );

  if (picked != null) {
    extraChargeImages.add(picked);
  }

  setDialogState(() {
    isUploadingExtraImage = false;
  });
},
          icon: Icon(
  isUploadingExtraImage
      ? Icons.hourglass_top
      : Icons.photo_library,
),
          label: Text(
  isUploadingExtraImage
      ? '照片處理中...'
      : '選擇照片',
),
        ),

        if (extraChargeImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '已選擇 ${extraChargeImages.length} 張照片',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  },
),
  ],
),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, extraFeeController.text);
            },
            child: const Text('確認退房'),
          ),
        ],
      );
    },
  );

final confirmCheckout = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('確認退房'),
    content: const Text('確定要將此訂單改為退房完成嗎？此操作會結束本次入住流程。'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('返回'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('確認退房'),
      ),
    ],
  ),
);

if (confirmCheckout != true) return;

  if (result == null) return;

  final extraFee = int.tryParse(result) ?? 0;

final extraChargeTitle = extraChargeTitleController.text.trim();
final extraChargeNote = extraChargeNoteController.text.trim();

final List<Map<String, dynamic>> extraCharges = [];

List<String> evidenceImageUrls = [];

if (extraChargeImages.isNotEmpty) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('照片上傳中，請稍候...'),
        ],
      ),
    ),
  );

  try {
  evidenceImageUrls = await _uploadExtraChargeImages(
    bookingId: bookingId,
    images: extraChargeImages,
  );
} catch (e) {
  if (context.mounted) {
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('照片上傳失敗：$e')),
    );
  }

  return;
}

  if (context.mounted) {
    Navigator.pop(context);
  }
}

if (extraFee > 0) {
  extraCharges.add({
  'title': extraChargeTitle.isEmpty ? '退房額外費用' : extraChargeTitle,
  'amount': extraFee,
  'note': extraChargeNote,
  'imageUrls': evidenceImageUrls,
  'createdAt': Timestamp.now(),
});
}

  final now = FieldValue.serverTimestamp();

  await FirebaseFirestore.instance
    .collection('bookings')
    .doc(bookingId)
    .update({
  'checkOutAt': now,
  'extraFee': extraFee,
  'extraCharges': FieldValue.arrayUnion(extraCharges),
});

/// 🔥 👉 這裡貼（就是這一行下面）
await FirebaseFirestore.instance
    .collection('reports')
    .add({
  'bookingId': bookingId,
  'roomName': data['roomName'],
  'totalPrice': data['totalPrice'] ?? 0,
  'extraFee': extraFee,
  'extraCharges': extraCharges,
  'finalAmount': (data['totalPrice'] ?? 0) + extraFee,
  'createdAt': FieldValue.serverTimestamp(),
});

final user = FirebaseAuth.instance.currentUser;

await FirebaseFirestore.instance.collection('action_logs').add({
  'type': 'checkout_completed',

  /// 訂單資訊
  'bookingId': bookingId,
  'bookingShortId': bookingId.substring(0, 8),
  'shopId': data['shopId'],
  'roomId': data['roomId'],
  'roomName': data['roomName'],
  'roomTypeName': data['roomTypeName'],

  /// 金額資訊
  'totalPrice': data['totalPrice'] ?? 0,
  'extraFee': extraFee,
  'finalAmount': (data['totalPrice'] ?? 0) + extraFee,
  'extraCharges': extraCharges,
  'extraChargeImageCount': evidenceImageUrls.length,

  /// 操作者
  'operatorUid': user?.uid,
  'operatorRole': 'staff',
'operatorEmail': user?.email,

  /// 時間
  'createdAt': FieldValue.serverTimestamp(),
});

  await _updateStatus('completed');
},
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

Future<List<String>> _uploadExtraChargeImages({
  required String bookingId,
  required List<XFile> images,
}) async {
  final List<String> urls = [];

  for (final image in images) {
    final bytes = await image.readAsBytes();

    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('圖片太大，請選擇 5MB 以下的圖片');
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('booking_extra_charges')
        .child(bookingId)
        .child('${DateTime.now().millisecondsSinceEpoch}_${image.name}');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await ref.getDownloadURL();
    urls.add(url);
  }

  return urls;
}
Future<void> _showAssignRoomDialog({
  required BuildContext context,
  required Map<String, dynamic> data,
}) async {
  final shopId = data['shopId']?.toString() ?? '';
  final roomTypeId = data['roomTypeId']?.toString() ?? '';
  final startDate = (data['startDate'] as Timestamp).toDate();
  final endDate = (data['endDate'] as Timestamp).toDate();
  final rooms = await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('rooms')
      .where('roomTypeId', isEqualTo: roomTypeId)
      .where('enabled', isEqualTo: true)
      .get();

      final availableRooms = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

for (final roomDoc in rooms.docs) {
  final available = await BookingService.instance.isRoomAvailable(
    shopId: shopId,
    roomId: roomDoc.id,
    startDate: startDate,
    endDate: endDate,
  );

  if (available) {
    availableRooms.add(roomDoc);
  }
}

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('選擇房間'),
        content: SizedBox(
          width: double.maxFinite,
          child: availableRooms.isEmpty
    ? const Text('此房型目前沒有可用房間')
    : ListView(
        shrinkWrap: true,
        children: availableRooms.map((doc) {
                    final room = doc.data();
                    final roomName = room['name']?.toString() ?? '未命名房間';

                    return ListTile(
                      leading: const Icon(Icons.meeting_room),
                      title: Text(roomName),
                      onTap: () async {
                        try {
                          await BookingService.instance.assignRoomToBooking(
                            bookingId: bookingId,
                            shopId: shopId,
                            roomId: doc.id,
                            roomName: roomName,
                            startDate: startDate,
                            endDate: endDate,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已完成分房')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('分房失敗：$e')),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

Future<void> _showChangeRoomDialog({
  required BuildContext context,
  required Map<String, dynamic> data,
}) async {
  final shopId = data['shopId']?.toString() ?? '';
  final roomTypeId = data['roomTypeId']?.toString() ?? '';
  final oldRoomId = data['roomId']?.toString() ?? '';
  final oldRoomName = data['roomName']?.toString() ?? '';
  if (oldRoomId.isEmpty || oldRoomName.isEmpty) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('此訂單尚未分房，不能更換房間')),
    );
  }
  return;
}
  final startDate = (data['startDate'] as Timestamp).toDate();
  final endDate = (data['endDate'] as Timestamp).toDate();
final changeReasonController = TextEditingController();
String selectedChangeReason = '攝影機故障';
  final rooms = await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('rooms')
      .where('roomTypeId', isEqualTo: roomTypeId)
      .where('enabled', isEqualTo: true)
      .get();

  final availableRooms = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  for (final roomDoc in rooms.docs) {
    if (roomDoc.id == oldRoomId) continue;

    final available = await BookingService.instance.isRoomAvailable(
      shopId: shopId,
      roomId: roomDoc.id,
      startDate: startDate,
      endDate: endDate,
    );

    if (available) {
      availableRooms.add(roomDoc);
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('更換房間｜目前：$oldRoomName'),
       content: SizedBox(
  width: double.maxFinite,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
     StatefulBuilder(
  builder: (context, setDialogState) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedChangeReason,
          decoration: const InputDecoration(
            labelText: '更換原因（必選）',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '攝影機故障', child: Text('攝影機故障')),
            DropdownMenuItem(value: '冷氣異常', child: Text('冷氣異常')),
            DropdownMenuItem(value: '設備維修', child: Text('設備維修')),
            DropdownMenuItem(value: '貓咪適應問題', child: Text('貓咪適應問題')),
            DropdownMenuItem(value: '客戶要求', child: Text('客戶要求')),
            DropdownMenuItem(value: '店家安排調整', child: Text('店家安排調整')),
            DropdownMenuItem(value: '其他', child: Text('其他')),
          ],
          onChanged: (value) {
            setDialogState(() {
              selectedChangeReason = value ?? '攝影機故障';
            });
          },
        ),

        if (selectedChangeReason == '其他') ...[
          const SizedBox(height: 12),
          TextField(
            controller: changeReasonController,
            decoration: const InputDecoration(
              labelText: '其他原因',
              hintText: '請輸入更換房間原因',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  },
),

      const SizedBox(height: 12),

      if (availableRooms.isEmpty)
        const Text('目前沒有其他可更換房間')
      else
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: availableRooms.map((doc) {
              final room = doc.data();
              final newRoomName =
                  room['name']?.toString() ?? '未命名房間';

              return ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(newRoomName),
                onTap: () async {

  final reason = selectedChangeReason == '其他'
      ? changeReasonController.text.trim()
      : selectedChangeReason;

  if (reason.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請填寫更換房間原因')),
    );
    return;
  }

  try {
                    await BookingService.instance.changeAssignedRoom(
                      bookingId: bookingId,
                      shopId: shopId,
                      oldRoomId: oldRoomId,
                      oldRoomName: oldRoomName,
                      newRoomId: doc.id,
                      newRoomName: newRoomName,
                      startDate: startDate,
                      endDate: endDate,
                      reason: reason,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已更換房間')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('更換失敗：$e')),
                      );
                    }
                  }
                },
              );
            }).toList(),
          ),
        ),
    ],
  ),
),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}


Future<void> _cancelBookingWithReason({
  required BuildContext context,
  required Map<String, dynamic> data,
}) async {
  String selectedReason = '客戶未付款';
  final otherReasonController = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('取消訂單原因'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  items: const [
                    DropdownMenuItem(value: '客戶未付款', child: Text('客戶未付款')),
                    DropdownMenuItem(value: '客戶自行取消', child: Text('客戶自行取消')),
                    DropdownMenuItem(value: '店家無法接待', child: Text('店家無法接待')),
                    DropdownMenuItem(value: '重複預約', child: Text('重複預約')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      selectedReason = v ?? '客戶未付款';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: '取消原因',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (selectedReason == '其他') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otherReasonController,
                    decoration: const InputDecoration(
                      labelText: '其他原因',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = selectedReason == '其他'
                      ? otherReasonController.text.trim()
                      : selectedReason;

                  if (reason.isEmpty) return;

                  Navigator.pop(context, reason);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('確認取消'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == null) return;

  await BookingService.instance.cancelBooking(
  bookingId: bookingId,
  cancelReason: result,
  cancelBy: 'admin',
);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('訂單已取消並釋放房間')),
    );
  }
}

Future<void> _updateStatus(String newStatus) async {
  final user = FirebaseAuth.instance.currentUser;

  final doc = await FirebaseFirestore.instance
      .collection('bookings')
      .doc(bookingId)
      .get();

  final data = doc.data() ?? {};
  final oldStatus = data['status'] ?? '';

  await BookingService.instance.updateBookingStatus(
    bookingId: bookingId,
    status: newStatus,
  );

  await FirebaseFirestore.instance.collection('action_logs').add({
    'type': 'booking_status_update',

    /// 訂單資訊
    'bookingId': bookingId,
    'bookingShortId': bookingId.substring(0, 8),
    'shopId': data['shopId'],
    'roomId': data['roomId'],
    'roomName': data['roomName'],
    'roomTypeName': data['roomTypeName'],

    /// 狀態變化
    'fromStatus': oldStatus,
    'toStatus': newStatus,

    /// 操作者
    'operatorUid': user?.uid,
    'operatorRole': 'staff',
    'operatorEmail': user?.email,

    /// 時間
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

Widget _actionLogCard(Map<String, dynamic> log) {
  final type = log['type'] ?? '';
  final time = _formatDateTime(log['createdAt']);
  final operatorEmail = log['operatorEmail'];

final operatorText = operatorEmail != null &&
        operatorEmail.toString().isNotEmpty
    ? operatorEmail.toString()
    : _operatorRoleText(log['operatorRole']);

  String title = '操作紀錄';

  if (type == 'booking_status_update') {
    title =
    '狀態變更：'
    '${_statusText(log['fromStatus'])}'
    ' → '
    '${_statusText(log['toStatus'])}';
  } else if (type == 'deposit_confirmed') {
    title = '確認收到訂金';
  } else if (type == 'booking_cancelled') {
    title = '取消訂單：${log['cancelReason'] ?? '-'}';
 } else if (type == 'checkout_completed') {
  title = '退房完成：額外費用 NT\$ ${log['extraFee'] ?? 0}';
} else if (type == 'room_assigned') {
  title = '完成分房：${log['roomName'] ?? '-'}';
} else if (type == 'room_changed') {
  final reason = (log['reason'] ?? '').toString();

  title =
      '更換房間：${log['oldRoomName'] ?? '-'} → ${log['newRoomName'] ?? '-'}';

  if (reason.isNotEmpty) {
    title += '\n原因：$reason';
  }
}

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
  '$time ・ 操作者：$operatorText',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}

Widget _timelineItem({
  required String title,
  required String time,
  required bool active,
  bool isLast = false,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: active ? Colors.green : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: active
                ? const Icon(
                    Icons.check,
                    size: 13,
                    color: Colors.white,
                  )
                : null,
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 38,
              color: Colors.grey.shade300,
            ),
        ],
      ),

      const SizedBox(width: 10),

      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              Text(
  time,
  style: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: active ? Colors.blue.shade700 : Colors.grey,
  ),
),
            ],
          ),
        ),
      ),
    ],
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

String _operatorRoleText(dynamic value) {
  switch (value) {
    case 'customer':
      return '客戶自行取消';

    case 'admin':
      return '店家操作';

    case 'system':
      return '系統自動取消';

    case 'staff':
      return '店家人員';

    default:
      return value?.toString() ?? '-';
  }
}

String _statusText(dynamic value) {
  switch (value) {
    case 'pending':
      return '待確認';

    case 'confirmed':
      return '已確認';

    case 'checked_in':
      return '入住中';

    case 'completed':
      return '已完成';

    case 'cancelled':
      return '已取消';

    default:
      return value?.toString() ?? '-';
  }
}

  String _cancelByText(dynamic value) {
  switch (value) {
    case 'customer':
      return '客戶取消';
    case 'admin':
      return '店家取消';
    case 'system':
      return '系統自動取消';
    default:
      return '-';
  }
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
  'depositStatus': 'confirmed', 
  'depositPaidAt': FieldValue.serverTimestamp(),
  'confirmedAt': FieldValue.serverTimestamp(),
  'status': 'confirmed',
  'updatedAt': FieldValue.serverTimestamp(),
});

  final doc = await FirebaseFirestore.instance
    .collection('bookings')
    .doc(bookingId)
    .get();

final data = doc.data() ?? {};

await FirebaseFirestore.instance
    .collection('action_logs')
    .add({
  'type': 'deposit_confirmed',

  /// 訂單資訊
  'bookingId': bookingId,
  'bookingShortId': bookingId.substring(0, 8),
  'shopId': data['shopId'],
  'roomId': data['roomId'],
  'roomName': data['roomName'],
  'roomTypeName': data['roomTypeName'],

  /// 訂金資訊
  'depositAmount': data['depositAmount'] ?? 0,
  'paymentMethod': data['paymentMethod'],
  'transferLast5': data['transferLast5'],

  /// 操作者
  'operatorUid': user?.uid,
  'operatorRole': 'staff',
  'operatorEmail': user?.email,

  /// 時間
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

}