// lib/features/shop/pages/room_type_detail_page.dart
// 🐱 房型詳細頁（升級版🔥）

import 'package:flutter/material.dart';

class RoomTypeDetailPage extends StatelessWidget {

  const RoomTypeDetailPage({
  super.key,
  required this.roomType,
  required this.startDate,
  required this.endDate,
});

  final Map<String, dynamic> roomType;
  final DateTime startDate;
final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(roomType['images'] ?? []);

    return Scaffold(
  bottomNavigationBar: Container(
    padding: const EdgeInsets.all(16),
    child: ElevatedButton(
      onPressed: () {
        Navigator.pop(context, roomType);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: const Text('查看您的選項'),
    ),
  ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔥 主圖輪播
            if (images.isNotEmpty)
              SizedBox(
                height: 240,
                child: PageView(
                  children: images.map((url) {
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                    );
                  }).toList(),
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: Text('尚無圖片')),
              ),

            /// 🔥 小圖列
            if (images.length > 1)
              Container(
                height: 80,
                margin: const EdgeInsets.only(top: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(left: 8),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            /// 🔥 房型資訊
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomType['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'NT\$ ${roomType['price']} / 晚',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '可住 ${roomType['capacity']} 隻',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🔥 住宿特色（先寫死，下一步改後台）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _featureCard(Icons.home, '獨立空間'),
                  _featureCard(Icons.cleaning_services, '每日清潔'),
                  _featureCard(Icons.videocam, '可監視'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🔥 房型介紹
            if ((roomType['description'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  roomType['description'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),

/// 🔥 入住時間
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('入住時間'),
          Text(
            '${startDate.month}月${startDate.day}日',
            style: const TextStyle(color: Colors.blue, fontSize: 16),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('退房時間'),
          Text(
            '${endDate.month}月${endDate.day}日',
            style: const TextStyle(color: Colors.blue, fontSize: 16),
          ),
        ],
      ),
    ],
  ),
),

const SizedBox(height: 20),

/// 🔥 價格區塊
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('1晚房價'),
      Text(
        'TWD ${roomType['price']}',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      const Text('含稅費與其他費用'),
    ],
  ),
),

const SizedBox(height: 20),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// 🔥 小卡
Widget _featureCard(IconData icon, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(text),
      ],
    ),
  );
}