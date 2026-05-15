// lib/features/shop/pages/shop_room_intro_page.dart
// 🛏️ 前台房間介紹頁
// 顯示店家的房型介紹，讀取 Firestore 房型資料，點擊可進房型詳細頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';

class ShopRoomIntroPage extends StatelessWidget {
  const ShopRoomIntroPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  void _openRoomDetail(
    BuildContext context,
    Map<String, dynamic> roomType,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomTypeDetailPage(
          shopId: shopId,
          roomType: roomType,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(
            const Duration(days: 1),
          ),
          isIntroMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '房間介紹',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF3A2A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '選擇適合毛孩的安心房型',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A2A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '每個房型都會顯示可入住數量、價格與特色，方便快速了解。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8A6A45),
            ),
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ShopService.instance.streamRoomTypes(shopId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final roomTypes = snapshot.data ?? [];

              if (roomTypes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text(
                      '目前尚無房型介紹',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final crossAxisCount = roomTypes.length == 1 ? 1 : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roomTypes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: crossAxisCount == 1 ? 1.65 : 0.78,
                ),
                itemBuilder: (context, index) {
                  final roomType = roomTypes[index];
                  final images = List<String>.from(roomType['images'] ?? []);
                  final imageUrl = images.isNotEmpty ? images.first : '';

                  return _RoomIntroGridCard(
                    roomType: roomType,
                    imageUrl: imageUrl,
                    isFullWidth: crossAxisCount == 1,
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
    required this.onTap,
  });

  final Map<String, dynamic> roomType;
  final String imageUrl;
  final bool isFullWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageHeight = isFullWidth ? 190.0 : 115.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFF0E0CC),
          ),
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
                    color: const Color(0xFFFFF1DD),
                    child: const Icon(
                      Icons.bed,
                      size: 44,
                      color: Color(0xFFB86B18),
                    ),
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
                        color: const Color(0xFF3A2A1A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'NT\$ ${roomType['price'] ?? 0} / 晚',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB86B18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '可住 ${roomType['capacity'] ?? 0} 隻',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A6A45),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1DD),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        '查看房型介紹',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB86B18),
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