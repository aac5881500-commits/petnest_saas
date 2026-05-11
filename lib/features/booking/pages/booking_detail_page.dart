// lib/features/booking/pages/booking_detail_page.dart
// 📄 訂單詳細頁（客戶端）
//
// 功能：
// - 顯示完整訂單資訊（卡片式 UI）
// - 顧客 / 寵物 / 訂金 / 備註
// - 上傳轉帳截圖
// - 填寫轉帳後五碼

//
// 特點：
// - UI 已升級（區塊卡片）
// - 訂金區強化（橘色提示）
// - 不顯示員工備註（安全）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'dart:async';

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const BookingDetailPage({
    super.key,
    required this.data,
    required this.docId,
  });

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final TextEditingController _last5Controller = TextEditingController();
final FocusNode _last5FocusNode = FocusNode();
bool _loading = false;
bool _autoCancelling = false;
Timer? _expireTimer;

@override
void initState() {
  super.initState();
}

@override
void dispose() {
  _expireTimer?.cancel();
  _last5Controller.dispose();
  _last5FocusNode.dispose();
  super.dispose();
}
  @override
  Widget build(BuildContext context) {

    // 🔥 價格計算（你現在缺這段）



return StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.docId)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = snapshot.data!.data() as Map<String, dynamic>;

final basePrice = data['basePrice'] ?? 0;
final nights = data['nights'] ?? 1;
final extraPetPrice = data['extraPetPrice'] ?? 0;
final extraPetCount = data['extraPetCount'] ?? 0;

/// 房費
final roomPriceTotal = basePrice * nights;

/// 寵物費
final petPriceTotal = extraPetPrice * extraPetCount * nights;

/// 小計（房間＋寵物）
final correctSubtotal = roomPriceTotal + petPriceTotal;

/// 🔥 加值服務總金額
final addonTotal = (data['addons'] as List? ?? []).fold<int>(
  0,
  (int sum, dynamic item) {
    final price = (item['price'] ?? 0) as num;
    final count = (item['count'] ?? 1) as num;
    final total = (item['total'] ?? (price * count)) as num;

    return sum + total.toInt();
  },
);

/// 🔥 最終總價（完整🔥）
final finalTotal = correctSubtotal + addonTotal;

/// 🔥 退房結算總額
final extraChargeTotal =
    (data['extraCharges'] as List? ?? []).fold<int>(
  0,
  (sum, item) => sum + ((item['amount'] ?? 0) as num).toInt(),
);

    final depositStatus = data['depositStatus'] ?? '';
    final bookingStatus = data['status'] ?? 'unpaid';
    final transferLast5 = (data['transferLast5'] ?? '').toString();

if (_last5Controller.text.isEmpty && transferLast5.isNotEmpty) {
  _last5Controller.text = transferLast5;
}
    final bankName = data['bankName'] ?? '';
final accountName = data['accountName'] ?? '';
final accountNumber = data['accountNumber'] ?? '';
if (_isDepositExpired(data)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _autoCancelExpiredBooking(data);
  });
} else {
  _scheduleDepositExpireCheck(data);
}
    

    final start = (data['startDate'] as Timestamp).toDate();
    final end = (data['endDate'] as Timestamp).toDate();

    return Scaffold(
      appBar: AppBar(
  title: const Text('訂單詳細'),
  actions: [
    if (bookingStatus == 'pending' ||
    bookingStatus == 'unpaid')
  TextButton.icon(
    onPressed: () async {

      final cancelReason = await _showCancelReasonDialog(context);

if (cancelReason == null) return;

      await BookingService.instance.cancelBooking(
  bookingId: widget.docId,
  cancelReason: cancelReason,
  cancelBy: 'customer',
);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('訂單已取消')),
        );
      }
    },
    icon: const Icon(
      Icons.close,
      color: Colors.red,
      size: 18,
    ),
    label: const Text(
      '取消訂單',
      style: TextStyle(color: Colors.red),
    ),
  ),
    Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [

    /// 🔹 小標題
    const Text(
  '訂單編號',
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.grey,
  ),
),

    /// 🔥 編號（放大）
    GestureDetector(
  onTap: () async {
    final id = data['bookingNo'] ?? widget.docId.substring(0, 8);

    await Clipboard.setData(ClipboardData(text: id));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製訂單編號')),
    );
  },
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        data['bookingNo'] ?? widget.docId.substring(0, 8),
        style: const TextStyle(
          fontSize: 18, // 🔥 放大
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 6),
      const Icon(Icons.copy, size: 16, color: Colors.grey),
    ],
  ),
),
  ],
),
        ),
      ),
    ),
  ],
),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [

/// 🏠 房型卡（完全後台版🔥）
_buildStatusCard(bookingStatus),

if (bookingStatus == 'cancelled')
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade100),
    ),
    child: Text(
      '取消原因：${data['cancelReason'] ?? '未填寫'}',
      style: const TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),


const SizedBox(height: 12),
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

      /// 🔝 第一排（房號 + 房型 + 晚數）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 左：房號 + 房型
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 房號（大）
              Text(
                data['roomName'] ?? '---',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 4),

              /// 房型（小）
              Text(
                data['roomTypeName'] ??
                data['roomType'] ??
                '未設定房型',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          /// 右：幾晚
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

      const SizedBox(height: 12),

      /// 🔥 第二排（入住 / 退房 + 訂單時間）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          /// 左（入住）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '入住',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                start.toString().substring(0, 10),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          /// 中（箭頭）
          const Icon(Icons.arrow_forward, color: Colors.white),

          /// 右（退房 + 訂單時間）
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '退房',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                end.toString().substring(0, 10),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              /// 🔥 訂單時間（有標示）
              if (data['createdAt'] != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '下訂 ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      (data['createdAt'] as Timestamp)
                          .toDate()
                          .toString()
                          .substring(0, 16),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ],
  ),
),

            /// 👤 顧客資訊（升級版 UI）
Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 🔥 標題
      const Text(
        '顧客資訊',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

      /// 🔥 第一排（姓名 + 電話）
      Row(
        children: [

          /// 👤 姓名
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data['customerName'] ?? '-',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 📞 電話
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.phone, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  data['customerPhone'] ?? '-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      const SizedBox(height: 12),

      /// 📍 地址（整排）
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              data['address']?? '未填寫地址',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),

 /// 🐾 寵物資訊（簡約版🔥）
_sectionCard(
  title: '寵物資訊 (${(data['pets'] ?? []).length}隻)',
  children: [

    GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: (data['pets'] ?? []).length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
  childAspectRatio: 0.72, // 🔥 讓圖片有更多高度
),
      itemBuilder: (context, index) {
        final pet = (data['pets'] ?? [])[index];

        final image =
            pet['imageUrl'] ??
            pet['photoUrl'] ??
            pet['image'] ??
            '';

        final name = pet['name'] ?? '';

        return Container(
  decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(16),

  /// 🔥 漸層底（重點）
  gradient: LinearGradient(
    colors: [
      Color(0xFFF8FAFF), // 淺藍白
      Color(0xFFEFF3FF), // 淡藍
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),

  /// 🔥 陰影（更柔）
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ],
),
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [

      /// 🐱 方形大圖
Expanded(
  child: ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: image.isNotEmpty
          ? Image.network(
              image,
              fit: BoxFit.cover, // 🔥 佔滿方形區塊
            )
          : const Icon(
              Icons.pets,
              size: 36,
              color: Colors.grey,
            ),
    ),
  ),
),

const SizedBox(height: 8),

/// 名稱
Text(
  name,
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  ),
  overflow: TextOverflow.ellipsis,
),
    ],
  ),
);
      },
    ),
  ],
),

/// 💰 價格（清楚版🔥）
Container(
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.only(top: 10),
  decoration: BoxDecoration(
    color: Colors.grey.shade50,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    children: [

      /// 🏠 房費
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('房費'),
          Text(
            '$basePrice × $nights 晚',
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
                ? '$extraPetPrice × $extraPetCount 隻 × $nights 晚'
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

      /// 💰 小計（正確🔥）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '小計',
            style: TextStyle(fontWeight: FontWeight.bold),
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
/// 🔥 加值服務（含小計🔥）
if ((data['addons'] ?? []).isNotEmpty)
  _sectionCard(
    title: '加值服務',
    children: [

      ...List.generate(
        (data['addons'] as List).length,
        (index) {
          final item = data['addons'][index];

          final pets = (data['pets'] ?? []) as List;

final petIds = (item['petNames'] ?? []) as List;

final petNames = petIds.map((id) {
  final match = pets.cast<Map<String, dynamic>?>().firstWhere(
    (p) => p?['name'] == id || p?['petId'] == id,
    orElse: () => null,
  );
  return match != null ? match['name'] : id;
}).where((e) => e != null && e.toString().isNotEmpty).toList();



          final price = (item['price'] ?? 0) as num;
final count = (item['count'] ?? 1) as num;
final total = (item['total'] ?? (price * count)) as num;

return Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.all(12),
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
    Text(
      item['name'] ?? '',
      style: const TextStyle(fontWeight: FontWeight.w500),
    ),

    Text(
      '+ NT\$ ${total.toInt()}',
      style: const TextStyle(
        color: Colors.deepOrange,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),

if (count > 1)
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      '${price.toInt()} x ${count.toInt()} = ${total.toInt()}',
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),
    ),
  ),

      /// 🔥 第二排：指定寵物（關鍵🔥）
      if (petNames.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '👉 ${petNames.join('、')}',
            style: const TextStyle(
              fontSize: 12,
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

      const Divider(),

      /// 🔥 加值服務總計（新增）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '加值服務小計',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'NT\$ $addonTotal',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    ],
  ),

/// 🔥 總價 + 訂金（高級版💰）
Container(
  
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 總價
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '總金額',
            style: TextStyle(color: Colors.white70),
          ),
          Text(
            'NT\$ $finalTotal',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),

      const SizedBox(height: 12),

      /// 訂金
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '需支付訂金',
            style: TextStyle(color: Colors.white70),
          ),
          Text(
            'NT\$ ${data['depositAmount'] ?? 0}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: (data['depositStatus'] == 'confirmed')
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),
          ),
        ],
      ),

      const SizedBox(height: 6),
    ],
  ),
),

            /// 💰 訂金提示
if ((data['depositAmount'] ?? 0) > 0 &&
    (data['paymentMethod'] == 'transfer' || data['paymentMethod'] == 'cash') &&
    depositStatus != 'confirmed')
  Container(
  padding: const EdgeInsets.all(10),
  margin: const EdgeInsets.only(bottom: 10),
  decoration: BoxDecoration(
    color: Colors.red.shade50,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '⚠️ 請依店家規定完成訂金付款，訂單才會成立',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),

      if (data['depositExpireAt'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '付款期限：${_formatDateTime(data['depositExpireAt'])}',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
    ],
  ),
),

if ((data['depositAmount'] ?? 0) <= 0 ||
    data['paymentMethod'] == 'cash')
  Container(
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      '💡 本訂單無需線上支付訂金，請依店家安排付款',
      style: TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
            _sectionCard(
  title: '付款方式',
  children: [

                Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.orange.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.orange.shade200),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '付款方式',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        data['paymentMethod'] == 'transfer'
            ? '銀行轉帳'
            : data['paymentMethod'] == 'cash'
                ? '到店付款'
                : '未設定',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      /// 🔥 查看轉帳資訊
if (data['paymentMethod'] == 'transfer')
  Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
  ),
  child: Container(
    width: 360,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: [
          Colors.white,
          Colors.blue.shade50,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔥 標題
        Row(
          children: [
            Icon(
              Icons.account_balance,
              color: Colors.blue.shade700,
              size: 30,
            ),

            const SizedBox(width: 10),

            const Text(
              '轉帳資訊',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        /// 銀行
        _bankInfoItem(
          title: '銀行',
          value: bankName,
        ),

        const SizedBox(height: 16),

        /// 戶名
        _bankInfoItem(
          title: '戶名',
          value: accountName,
        ),

        const SizedBox(height: 16),

        /// 帳號
        _bankInfoItem(
          title: '帳號',
          value: accountNumber,
        ),

        const SizedBox(height: 28),

        /// 關閉
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '關閉',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),
        );
      },
      child: const Text('查看轉帳資訊'),
    ),
  ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '訂金金額',
            style: TextStyle(color: Colors.grey),
          ),
          Text(
            'NT\$ ${data['depositAmount'] ?? 0}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    ],
  ),
),


                const SizedBox(height: 10),

if (data['paymentMethod'] == 'transfer') ...[

                /// 🔥 轉帳後五碼
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      '轉帳後五碼',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
    const SizedBox(height: 8),

    TextField(
  controller: _last5Controller,
  enabled: depositStatus != 'pending_review' &&
    depositStatus != 'pending' &&
    depositStatus != 'confirmed',
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
  ],
  onChanged: (value) {
  if (value.length > 5) {
    final fixed = value.substring(0, 5);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _last5Controller.value = TextEditingValue(
        text: fixed,
        selection: TextSelection.collapsed(offset: fixed.length),
        composing: TextRange.empty,
      );
    });
  }
},
  decoration: InputDecoration(
        counterText: '',
        hintText: '例如：12345',
        helperText: '請輸入碼轉帳 後五碼',
        filled: true,
        fillColor: Colors.orange.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.orange.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.orange.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepOrange, width: 1.5),
        ),
      ),
    ),
  ],
),

                const SizedBox(height: 12),

                /// 上傳圖片
/// 上傳圖片 / 顯示圖片
GestureDetector(
  onTap: (depositStatus == 'pending_review' ||
        depositStatus == 'pending' ||
        depositStatus == 'confirmed')
    ? null
    : (_loading ? null : _uploadImage),
  child: Container(
    width: double.infinity,
    height: 140,
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: (data['transferImageUrl'] != null &&
            data['transferImageUrl'].toString().isNotEmpty)
        ? Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          data['transferImageUrl'],
          width: double.infinity,
          height: 140,
          fit: BoxFit.contain,
        ),
      ),
if (depositStatus != 'pending_review' &&
    depositStatus != 'pending' &&
    depositStatus != 'confirmed')
      Positioned(
        top: 8,
        right: 8,
        child: InkWell(
          onTap: (_loading ||
        depositStatus == 'pending_review' ||
        depositStatus == 'pending' ||
        depositStatus == 'confirmed')
    ? null
    : () => _deleteTransferImage(
          data['transferImageUrl'].toString(),
        ),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    ],
  )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.image_outlined, size: 34, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                '上傳轉帳截圖',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '支援 JPG / PNG',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
  ),
),

                const SizedBox(height: 12),

                /// 送出訂金
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
  onPressed: (depositStatus == 'pending_review' ||
        depositStatus == 'pending' ||
        depositStatus == 'confirmed')
    ? null
    : (_loading ? null : _submitDeposit),
                    child: Text(_loading ? '送出中...' : '送出付款資料'),
                  ),
                ),
                ],
              ],
            ),
/// 🔥 退房結算（不併入原總金額）
/// 🔥 退房結算明細（不併入原總金額）
_sectionCard(
  title: '退房結算明細',
  children: [
    if ((data['extraCharges'] ?? []).isEmpty)
      const Text(
        '目前無額外費用',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),

    if ((data['extraCharges'] ?? []).isNotEmpty)
      ...List.generate(
        (data['extraCharges'] as List).length,
        (index) {
          final item = data['extraCharges'][index];
          final title = item['title'] ?? '額外費用';
          final amount = item['amount'] ?? 0;
          final note = item['note'] ?? '';
          final imageUrls = (item['imageUrls'] ?? []) as List;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.red.shade100,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          if (note.toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                note,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    Text(
                      'NT\$ $amount',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Divider(color: Colors.red.shade100),

                  const SizedBox(height: 8),

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
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            url,
                            width: 96,
                            height: 96,
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
  ],
),

/// 🔥 訂單狀態（時間軸）
_sectionCard(
  title: '訂單狀態',
  children: [
    _buildStatusStep(
      title: '已送出預約',
      active: true,
      time: _formatDateTime(data['createdAt']),
    ),

    _buildStatusStep(
      title: depositStatus == 'pending'
          ? '訂金待店家確認'
          : '等待店家確認',
      active: bookingStatus == 'pending' ||
          bookingStatus == 'confirmed' ||
          bookingStatus == 'checked_in' ||
          bookingStatus == 'completed',
    ),

    _buildStatusStep(
      title: '店家已確認',
      active: bookingStatus == 'confirmed' ||
          bookingStatus == 'checked_in' ||
          bookingStatus == 'completed',
      time: _formatDateTime(data['depositPaidAt'] ?? data['confirmedAt']),
    ),

    _buildStatusStep(
      title: '入住中',
      active: bookingStatus == 'checked_in' ||
          bookingStatus == 'completed',
      time: _formatDateTime(data['checkInAt']),
    ),

    _buildStatusStep(
      title: '已完成',
      active: bookingStatus == 'completed',
      time: _formatDateTime(data['checkOutAt']),
      isLast: bookingStatus != 'cancelled',
    ),

    if (bookingStatus == 'cancelled')
      _buildStatusStep(
        title: '訂單已取消',
        active: true,
        time: _formatDateTime(data['cancelledAt']),
        isLast: true,
      ),
  ],
),

            /// 📝 備註
            _sectionCard(
              title: '備註',
              children: [
                Text(data['note'] ?? '無'),
              ],
            ),
          ],
        ),
      ),
    );
  },
  );
  }

Future<String?> _showCancelReasonDialog(BuildContext context) async {
  String selectedReason = '客戶自行取消';
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
                    DropdownMenuItem(value: '客戶自行取消', child: Text('客戶自行取消')),
                    DropdownMenuItem(value: '行程變更', child: Text('行程變更')),
                    DropdownMenuItem(value: '重複預約', child: Text('重複預約')),
                    DropdownMenuItem(value: '改用其他付款方式', child: Text('改用其他付款方式')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      selectedReason = v ?? '客戶自行取消';
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

  otherReasonController.dispose();
  return result;
}

  /// 🔥 寫入訂金
  Future<void> _submitDeposit() async {
  final last5 = _last5Controller.text.trim();

  final bookingDoc = await FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.docId)
      .get();

  final bookingData = bookingDoc.data() ?? {};
  final transferImageUrl =
      (bookingData['transferImageUrl'] ?? '').toString();

  if (transferImageUrl.isEmpty) {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('尚未上傳轉帳截圖'),
        content: const Text(
          '你目前沒有上傳轉帳截圖，確定只送出後五碼嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回上傳'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定送出'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
  }

  if (last5.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入正確的後五碼')),
      );
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      await FirebaseFirestore.instance
    .collection('bookings')
    .doc(widget.docId)
    .update({
  'transferLast5': last5,

  /// 🔥 客戶已回傳付款資料
  'depositStatus': 'pending_review',

  /// 🔥 記錄送出時間
  'depositSubmittedAt': FieldValue.serverTimestamp(),
});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('訂金已送出')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('錯誤：$e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// 📦 區塊卡片
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  /// 🔹 欄位
  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// 📸 上傳圖片
  Future<void> _uploadImage() async {
    final picker = ImagePicker();

final picked = await picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 1200,      // 🔥 限制圖片寬度
  imageQuality: 75,    // 🔥 壓縮品質
);

    if (picked == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final bytes = await picked.readAsBytes();
      /// 🔥 限制上傳後大小，避免高階手機大圖炸容量
if (bytes.length > 5 * 1024 * 1024) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('圖片太大，請選擇 5MB 以下的圖片')),
  );

  setState(() {
    _loading = false;
  });

  return;
}

final ref = FirebaseStorage.instance
    .ref()
    .child('booking_images')
    .child(widget.docId)
    .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

await ref.putData(
  bytes,
  SettableMetadata(contentType: 'image/jpeg'),
);

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({
        'transferImageUrl': url,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圖片上傳成功')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗：$e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

Future<void> _deleteTransferImage(String imageUrl) async {
  if (imageUrl.isEmpty) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('刪除轉帳截圖'),
      content: const Text('確定要刪除目前上傳的轉帳截圖嗎？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('確定刪除'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() {
    _loading = true;
  });

  try {
    await FirebaseStorage.instance.refFromURL(imageUrl).delete();

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.docId)
        .update({
      'transferImageUrl': FieldValue.delete(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已刪除轉帳截圖')),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('刪除失敗：$e')),
    );
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}

Widget _buildStatusCard(String status) {
  Color bgColor;
  Color textColor;
  String text;
  IconData icon;

  switch (status) {
    case 'unpaid':
      bgColor = Colors.red.shade50;
      textColor = Colors.red;
      text = '尚未付款';
      icon = Icons.warning;
      break;

    case 'pending':
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange;
      text = '已付款・待確認';
      icon = Icons.access_time;
      break;

    case 'confirmed':
      bgColor = Colors.green.shade50;
      textColor = Colors.green;
      text = '已確認訂單';
      icon = Icons.check_circle;
      break;

    case 'checked_in':
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue;
      text = '入住中';
      icon = Icons.home;
      break;

    case 'completed':
      bgColor = Colors.grey.shade300;
      textColor = Colors.black87;
      text = '已完成';
      icon = Icons.flag;
      break;

case 'cancelled':
  bgColor = Colors.red.shade50;
  textColor = Colors.red;
  text = '已取消訂單';
  icon = Icons.cancel;
  break;

    default:
      bgColor = Colors.grey.shade200;
      textColor = Colors.black;
      text = '未知狀態';
      icon = Icons.help;
  }

  return Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: textColor),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
Widget _buildStatusStep({
  required String title,
  required bool active,
  String? time,
  bool isLast = false,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 🔥 左邊：圓圈 + 線
      Column(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: active ? Colors.green : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: active
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),

          if (!isLast)
            Container(
              width: 2,
              height: 40,
              color: Colors.grey.shade300,
            ),
        ],
      ),

      const SizedBox(width: 10),

      /// 🔥 右邊文字 + 時間
Expanded(
  child: Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: active ? Colors.black : Colors.grey,
            ),
          ),
        ),

        if (time != null)
  Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(
      time,
      style: TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w900,
  letterSpacing: 0.3,
  color: active
      ? Colors.blue.shade800
      : Colors.grey.shade400,
),
    ),
  ),
      ],
    ),
  ),
),
    ],
  );
}
Widget _bankInfoItem({
  required String title,
  required String value,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}
String? _formatDateTime(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) {
    final date = value.toDate();

    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');

    return '$y-$m-$d $h:$min';
  }

  return null;
}
bool _needDepositPayment(Map<String, dynamic> data) {
  final depositAmount = data['depositAmount'] ?? 0;
  final paymentMethod = data['paymentMethod'] ?? '';
  final depositStatus = data['depositStatus'] ?? '';
  final status = data['status'] ?? '';

  return depositAmount > 0 &&
      (paymentMethod == 'transfer' || paymentMethod == 'cash') &&
      depositStatus != 'pending' &&
      depositStatus != 'confirmed' &&
      status != 'cancelled';
}

bool _isDepositExpired(Map<String, dynamic> data) {
  if (!_needDepositPayment(data)) return false;

  final expireAt = data['depositExpireAt'];
  if (expireAt == null || expireAt is! Timestamp) return false;

  return DateTime.now().isAfter(expireAt.toDate());
}

Future<void> _autoCancelExpiredBooking(Map<String, dynamic> data) async {
  if (_autoCancelling) return;

  _autoCancelling = true;

  try {
    await BookingService.instance.cancelBooking(
  bookingId: widget.docId,
  cancelReason: '訂單保留逾期自動取消',
  cancelBy: 'system',
);

await FirebaseFirestore.instance
    .collection('bookings')
    .doc(widget.docId)
    .update({
  'depositExpired': true,
});
  } finally {
    _autoCancelling = false;
  }
}
void _scheduleDepositExpireCheck(Map<String, dynamic> data) {
  if (!_needDepositPayment(data)) return;

  final expireAt = data['depositExpireAt'];
  if (expireAt == null || expireAt is! Timestamp) return;

  _expireTimer?.cancel();

  final diff = expireAt.toDate().difference(DateTime.now());

  if (diff.isNegative) return;

  _expireTimer = Timer(diff, () {
    if (!mounted) return;
    _autoCancelExpiredBooking(data);
  });
}
}