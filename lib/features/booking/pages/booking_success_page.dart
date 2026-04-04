// lib/features/booking/pages/booking_success_page.dart
// 🎉 訂單成功頁

import 'package:flutter/material.dart';

class BookingSuccessPage extends StatelessWidget {
  const BookingSuccessPage({
    super.key,
    required this.shopName,
  });

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // ❌ 不給返回鍵
        title: const Text('預約完成'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ),

              const SizedBox(height: 20),

              const Text(
                '預約成功 🎉',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '已送出至 $shopName',
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              /// 🔥 回店家
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('回到店家'),
                ),
              ),

              const SizedBox(height: 12),

              /// 🔥 查看訂單（未來用）
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                    // 👉 之後可以跳訂單頁
                  },
                  child: const Text('查看訂單'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}