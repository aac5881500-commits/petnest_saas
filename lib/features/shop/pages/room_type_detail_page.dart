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
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_feature_tags.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';

class RoomTypeDetailPage extends StatefulWidget {
  const RoomTypeDetailPage({
    super.key,
    required this.shopId,
    required this.roomType,
    required this.startDate,
    required this.endDate,
    required this.theme,
    this.isIntroMode = false,
  });

  final String shopId;
  final Map<String, dynamic> roomType;
  final DateTime startDate;
  final DateTime endDate;
  final HomeThemeModel theme;
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
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.backgroundColor,
        foregroundColor: widget.theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.roomType['name'] ?? '房型介紹',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: widget.theme.textColor,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: widget.isIntroMode
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.theme.cardColor,
                border: Border(
                  top: BorderSide(color: widget.theme.cardBorderColor),
                ),
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
                        theme: widget.theme,
                        useModernDrawer:
                            widget.theme != HomeThemeModel.classicDefault,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '我要預約',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.theme.cardColor,
                border: Border(
                  top: BorderSide(color: widget.theme.cardBorderColor),
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, widget.roomType);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.primaryColor,
                  foregroundColor: Colors.white,
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
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          return Container(
                            height: 260,
                            width: double.infinity,
                            color: widget.theme.cardColor,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              color: widget.theme.primaryColor,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 260,
                            width: double.infinity,
                            color: widget.theme.cardColor,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image,
                              color: widget.theme.textColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          );
                        },
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
                                      ? widget.theme.primaryColor
                                      : widget.theme.cardBorderColor,
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
                    color: widget.theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: widget.theme.cardBorderColor),
                  ),
                  child: Center(
                    child: Text(
                      '尚無圖片',
                      style: TextStyle(
                        color: widget.theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),

            /// 🔥 房型資訊
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: widget.theme.cardBorderColor),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.theme.textColor,
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// 價格
                    Text(
                      'NT\$ ${widget.roomType['price']} / 晚',
                      style: TextStyle(
                        color: widget.theme.primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    /// 容量
                    Text(
                      '可住 ${widget.roomType['capacity']} 隻',
                      style: TextStyle(
                        color: widget.theme.textColor.withValues(alpha: 0.65),
                      ),
                    ),

                    /// 加價
                    if ((widget.roomType['extraPrice'] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '每多一隻 +${widget.roomType['extraPrice']} 元',
                          style: TextStyle(
                            color: widget.theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),

                    RoomFeatureTags(
                      features: [
                        ...List<String>.from(widget.roomType['features'] ?? []),
                        ...List<Map<String, dynamic>>.from(
                          widget.roomType['customFeatures'] ?? [],
                        ).map((e) => '${e['icon']} ${e['name']}'),
                      ],
                      theme: widget.theme,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 16,
                          color: widget.theme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '房間尺寸',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.theme.textColor,
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
                        color: widget.theme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: widget.theme.cardBorderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _sizeItem(
                            '寬',
                            widget.roomType['width'],
                            widget.theme,
                          ),
                          _sizeItem(
                            '深',
                            widget.roomType['depth'],
                            widget.theme,
                          ),
                          _sizeItem(
                            '高',
                            widget.roomType['height'],
                            widget.theme,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 🏠 房型介紹
                    if ((widget.roomType['description'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      Text(
                        '房型介紹',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.theme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.theme.cardBorderColor,
                          ),
                        ),
                        child: Text(
                          widget.roomType['description'],
                          style: TextStyle(
                            height: 1.5,
                            color: widget.theme.textColor.withValues(
                              alpha: 0.75,
                            ),
                          ),
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
                    color: widget.theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.theme.cardBorderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '入住時間',
                            style: TextStyle(
                              color: widget.theme.textColor.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.startDate.month}月${widget.startDate.day}日',
                            style: TextStyle(
                              color: widget.theme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '退房時間',
                            style: TextStyle(
                              color: widget.theme.textColor.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.endDate.month}月${widget.endDate.day}日',
                            style: TextStyle(
                              color: widget.theme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
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
                    color: widget.theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.theme.cardBorderColor),
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
                      Text(
                        '1晚房價',
                        style: TextStyle(
                          color: widget.theme.textColor.withValues(alpha: 0.68),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TWD ${widget.roomType['price']}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: widget.theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '含稅費與其他費用',
                        style: TextStyle(
                          color: widget.theme.textColor.withValues(alpha: 0.58),
                        ),
                      ),
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
Widget _sizeItem(String label, dynamic value, HomeThemeModel theme) {
  return Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: theme.textColor.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '${value ?? 0} cm',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.textColor,
        ),
      ),
    ],
  );
}
