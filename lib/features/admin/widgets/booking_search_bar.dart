// lib/features/admin/widgets/booking_search_bar.dart
// 🔍 後台訂單搜尋框
//
// 功能：
// - 搜尋訂單編號
// - 搜尋顧客姓名
// - 搜尋手機
// - 搜尋寵物名
// - 搜尋房號

import 'package:flutter/material.dart';

class BookingSearchBar extends StatelessWidget {
  const BookingSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '搜尋訂單編號 / 顧客姓名 / 手機 / 寵物名 / 房號',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          border: InputBorder.none,
          icon: Icon(
            Icons.search,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}