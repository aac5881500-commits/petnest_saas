// lib/features/shop/pages/shop_room_intro_page.dart
// 🛏️ 前台房間介紹頁
// 顯示店家的房型介紹，未來會接 Firestore 房型資料

import 'package:flutter/material.dart';

class ShopRoomIntroPage extends StatelessWidget {
  const ShopRoomIntroPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

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
        children: const [
          Text(
            '選擇適合毛孩的安心房型',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A2A1A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '每個房型都會顯示可入住數量、價格與特色，方便快速了解。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8A6A45),
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              '房型資料準備中',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}