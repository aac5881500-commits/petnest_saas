// lib/features/shop/pages/shop_room_intro_page.dart
// 🛏️ 前台房間介紹頁
// 顯示店家的房型介紹，讀取 Firestore 房型資料，點擊可進房型詳細頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';

class ShopRoomIntroPage extends StatelessWidget {
  const ShopRoomIntroPage({
    super.key,
    required this.shopId,
    required this.theme,
  });

  final String shopId;
  final HomeThemeModel theme;

  void _openRoomDetail(BuildContext context, Map<String, dynamic> roomType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomTypeDetailPage(
          shopId: shopId,
          roomType: roomType,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 1)),
          theme: theme,
          isIntroMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '房間介紹',
          style: TextStyle(fontWeight: FontWeight.w800, color: theme.textColor),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '選擇適合毛孩的安心房型',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '每個房型都會顯示可入住數量、價格與特色，方便快速了解。',
            style: TextStyle(
              fontSize: 13,
              color: theme.textColor.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ShopService.instance.streamRoomTypes(shopId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  ),
                );
              }

              final roomTypes = snapshot.data ?? [];

              if (roomTypes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      '目前尚無房型介紹',
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                );
              }

              const crossAxisCount = 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roomTypes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: crossAxisCount == 1 ? 0.95 : 0.62,
                ),
                itemBuilder: (context, index) {
                  final roomType = roomTypes[index];
                  final images = List<String>.from(roomType['images'] ?? []);
                  final imageUrl = images.isNotEmpty ? images.first : '';

                  return _RoomIntroGridCard(
                    roomType: roomType,
                    imageUrl: imageUrl,
                    isFullWidth: crossAxisCount == 1,
                    theme: theme,
                    onTap: () => _openRoomDetail(context, roomType),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoomIntroGridCard extends StatelessWidget {
  const _RoomIntroGridCard({
    required this.roomType,
    required this.imageUrl,
    required this.isFullWidth,
    required this.theme,
    required this.onTap,
  });

  final Map<String, dynamic> roomType;
  final String imageUrl;
  final bool isFullWidth;
  final HomeThemeModel theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageHeight = isFullWidth ? 160.0 : 100.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: imageHeight,
                    width: double.infinity,
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    child: Icon(Icons.bed, size: 44, color: theme.primaryColor),
                  ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomType['name'] ?? '未命名房型',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isFullWidth ? 20 : 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'NT\$ ${roomType['price'] ?? 0} / 晚',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '可住 ${roomType['capacity'] ?? 0} 隻',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textColor.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '查看房型介紹',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
