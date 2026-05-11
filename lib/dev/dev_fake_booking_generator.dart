// lib/dev/dev_fake_booking_generator.dart
// 🧪 開發用假訂單產生器
//
// 功能：
// - 快速產生大量 bookings 測試資料
// - 測試訂單列表效能 / limit(30) / 搜尋 / 排序 / 狀態篩選
//
// ⚠️ 注意：
// - 這個檔案只給開發測試用
// - 正式上線前不要放按鈕給店家使用

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class DevFakeBookingGenerator {
  DevFakeBookingGenerator._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> generate({
    required String shopId,
    int count = 50,
  }) async {
    final random = Random();

    final names = [
      '劉志晟',
      '王小明',
      '陳小姐',
      '林先生',
      '黃太太',
      '張先生',
      '李小姐',
      '許小姐',
    ];

    final petGroups = [
      ['黃瓜', '麵條', '花生'],
      ['奶茶', '布丁'],
      ['豆豆'],
      ['小橘', '虎斑'],
      ['黑糖'],
      ['咪咪', '球球'],
    ];

    final statuses = [
      'pending',
      'confirmed',
      'checked_in',
      'completed',
      'cancelled',
    ];

    final paymentMethods = [
      'cash',
      'transfer',
    ];

    final batch = _db.batch();

    for (int i = 0; i < count; i++) {
      final docRef = _db.collection('bookings').doc();

      final startDate = DateTime.now().add(
        Duration(days: random.nextInt(90) - 20),
      );

      final nights = random.nextInt(4) + 1;
      final endDate = startDate.add(Duration(days: nights));

      final status = statuses[random.nextInt(statuses.length)];
      final paymentMethod =
          paymentMethods[random.nextInt(paymentMethods.length)];

      final roomNumber = (random.nextInt(5) + 1).toString().padLeft(3, '0');

      final customerName = names[random.nextInt(names.length)];
      final customerPhone =
          '09${random.nextInt(90000000) + 10000000}';

      final pets = petGroups[random.nextInt(petGroups.length)]
          .map((name) => {
                'name': name,
                'breed': '米克斯',
                'photoUrl': '',
                'medicalStatus': '',
                'note': '',
              })
          .toList();

      final basePrice = 1400;
      final totalPrice = basePrice * nights;
      final depositAmount = (totalPrice / 2).round();

      final depositConfirmed = status == 'confirmed' ||
          status == 'checked_in' ||
          status == 'completed';

      batch.set(docRef, {
        'shopId': shopId,

        /// 訂單基本
        'status': status,
        'roomName': roomNumber,
        'roomNumber': roomNumber,
        'roomTypeName': '貓咪跳跳房',
        'nights': nights,

        /// 日期
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(Duration(days: random.nextInt(60))),
        ),
        'updatedAt': FieldValue.serverTimestamp(),

        /// 顧客
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': '新竹縣新埔鎮測試路 ${random.nextInt(99) + 1} 號',

        /// 緊急聯絡人
        'emergencyContact': {
          'name': '緊急聯絡人',
          'phone': '0912345678',
          'relation': '家人',
          'address': '同飼主地址',
        },

        /// 寵物
        'pets': pets,

        /// 金額
        'basePrice': basePrice,
        'extraPetPrice': 0,
        'extraPetCount': 0,
        'extraPetTotal': 0,
        'roomSubtotal': totalPrice,
        'totalPrice': totalPrice,

        /// 付款 / 訂金
        'paymentMethod': paymentMethod,
        'payAmountType': 'deposit',
        'depositAmount': depositAmount,
        'depositPaid': depositConfirmed,
        'depositStatus': depositConfirmed ? 'confirmed' : 'waiting',

        /// 備註
        'note': '這是開發測試假訂單 #$i',

        /// 加值服務
        'addons': [],
      });
    }

    await batch.commit();
  }
}