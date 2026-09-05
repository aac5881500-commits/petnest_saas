// 檔案名稱：lib/features/booking/pages/booking_success_page.dart
// 功能說明：顯示預約成功結果，並提供回到店家首頁、查看我的訂單
// 🎉 訂單成功頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';

class BookingSuccessPage extends StatelessWidget {
  const BookingSuccessPage({
    super.key,
    required this.shopName,
    required this.shopId,
    this.message,
    this.bookingId,
  });

  final String shopName;
  final String shopId;
  final String? message;
  final String? bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('預約完成'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text(
                '預約成功 🎉',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? '已送出至 $shopName',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text('已送出至 $shopName', style: const TextStyle(fontSize: 16)),
              ],
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopPublicPage(shopId: shopId),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('回到店家'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    if ((bookingId ?? '').trim().isNotEmpty) {
                      final DocumentSnapshot<Map<String, dynamic>> snap =
                          await FirebaseFirestore.instance
                              .collection('bookings')
                              .doc(bookingId)
                              .get();
                      if (!context.mounted) {
                        return;
                      }
                      final Map<String, dynamic>? data = snap.data();
                      if (data != null) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => BookingDetailPage(
                              data: data,
                              docId: bookingId!,
                            ),
                          ),
                          (Route<dynamic> route) => false,
                        );
                        return;
                      }
                    }
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyBookingsPage(returnShopId: shopId),
                      ),
                      (route) => false,
                    );
                  },
                  child: Text(
                    (bookingId ?? '').trim().isNotEmpty ? '查看此訂單' : '查看訂單',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
