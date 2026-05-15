// lib/features/shop/pages/room_type_detail_page.dart
//
// 🔥 前台房型詳細頁
//
// 功能：
// - 顯示房型照片
// - 顯示房型特色小卡
// - 顯示房型尺寸
// - 顯示房型介紹
// - 顯示入住與退房日期
// - 顯示房型價格
// - 提供返回預約頁按鈕
//
// 使用位置：
// - shop_booking_page.dart 點選房型後進入
//
// 共用元件：
// - RoomFeatureTags（房型特色小卡）
//
// 後續可擴充：
// - 房型影片
// - 房型規範
// - 房型直播鏡頭
// - 房型可入住寵物條件

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_feature_tags.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';

class RoomTypeDetailPage extends StatefulWidget {
  const RoomTypeDetailPage({
  super.key,
  required this.shopId,
  required this.roomType,
  required this.startDate,
  required this.endDate,
  this.isIntroMode = false,
});


  final String shopId;
  final Map<String, dynamic> roomType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isIntroMode;

  @override
  State<RoomTypeDetailPage> createState() => _RoomTypeDetailPageState();
}

class _RoomTypeDetailPageState extends State<RoomTypeDetailPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(widget.roomType['images'] ?? []);

    return Scaffold(
backgroundColor: const Color(0xFFFFFAF4),  appBar: AppBar(
backgroundColor: const Color(0xFFFFFAF4),    elevation: 0,
    surfaceTintColor: Colors.transparent,
    title: Text(
      widget.roomType['name'] ?? '房型介紹',
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF3A2A1A),
      ),
    ),
    centerTitle: true,
  ),
  bottomNavigationBar: widget.isIntroMode
    ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
         onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ShopBookingPage(
        shopId: widget.shopId,
      ),
    ),
  );
},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB86B18),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            '我要預約',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      )
    : Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, widget.roomType);
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

            /// 🔥 圖片區
if (images.isNotEmpty)
  Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            images[_currentIndex],
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) {
              final selected = _currentIndex == index;

              return GestureDetector(
                onTap: () {
                  setState(() => _currentIndex = index);
                },
                child: Container(
                  width: 82,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFB86B18)
                          : Colors.transparent,
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(images[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  )
else
  Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(child: Text('尚無圖片')),
    ),
  ),

  /// 🔥 房型資訊
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0E0CC)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 名稱
        Text(
          widget.roomType['name'] ?? '',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        /// 價格
        Text(
          'NT\$ ${widget.roomType['price']} / 晚',
          style: const TextStyle(
            color: Color(0xFFB86B18),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        /// 容量
        Text(
          '可住 ${widget.roomType['capacity']} 隻',
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        /// 加價
        if ((widget.roomType['extraPrice'] ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '每多一隻 +${widget.roomType['extraPrice']} 元',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        const SizedBox(height: 14),

        RoomFeatureTags(
          features: List<String>.from(
            widget.roomType['features'] ?? [],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: const [
            Icon(Icons.straighten, size: 16),
            SizedBox(width: 6),
            Text(
              '房間尺寸',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        /// 📏 尺寸
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF0E0CC),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _sizeItem('寬', widget.roomType['width']),
              _sizeItem('深', widget.roomType['depth']),
              _sizeItem('高', widget.roomType['height']),
            ],
          ),
        ),

        const SizedBox(height: 20),

        /// 🏠 房型介紹
        if ((widget.roomType['description'] ?? '')
            .toString()
            .isNotEmpty) ...[
          const Text(
            '房型介紹',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A2A1A),
            ),
          ),
          const SizedBox(height: 10),
          Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
              color: const Color(0xFFFFF8EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.roomType['description'],
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ],
    ),
  ),
),
            const SizedBox(height: 20),

            /// 📅 入住時間
if (!widget.isIntroMode)
  Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('入住時間'),
                        Text(
                          '${widget.startDate.month}月${widget.startDate.day}日',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('退房時間'),
                        Text(
                          '${widget.endDate.month}月${widget.endDate.day}日',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 💰 價格（訂房流程用）
if (!widget.isIntroMode)
  Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1晚房價'),
        Text(
          'TWD ${widget.roomType['price']}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text('含稅費與其他費用'),
      ],
    ),
  ),
),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// 尺寸
Widget _sizeItem(String label, dynamic value) {
  return Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Text(
        '${value ?? 0} cm',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
