import '../widgets/booking_success_content.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
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
    this.appearance,
    this.theme,
    this.frontendTheme,
    this.startDate,
    this.endDate,
    this.petCount,
    this.roomTypeName,
    this.totalPrice,
  });

  final String shopName;
  final String shopId;
  final String? message;
  final String? bookingId;

  final BookingPageAppearance? appearance;
  final HomeThemeModel? theme, frontendTheme;
  final DateTime? startDate, endDate;
  final int? petCount, totalPrice;
  final String? roomTypeName;
  @override
  Widget build(BuildContext context) {
    final t = BookingSuccessContent.resolveTheme(
      appearance,
      theme,
      frontendTheme,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: BookingSuccessContent.font(appearance),
          bodyColor: t.textColor,
          displayColor: t.textColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: t.backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: t.backgroundColor,
          foregroundColor: t.textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '預約完成',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: BookingSuccessContent(
          shopName: shopName,
          message: message,
          bookingId: bookingId,
          appearance: appearance,
          theme: theme,
          frontendTheme: frontendTheme,
          startDate: startDate,
          endDate: endDate,
          petCount: petCount,
          roomTypeName: roomTypeName,
          totalPrice: totalPrice,
          onReturnToShop: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => ShopPublicPage(shopId: shopId)),
              (route) => false,
            );
          },
          onViewOrder: () async {
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
                    builder: (_) =>
                        BookingDetailPage(data: data, docId: bookingId!),
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
        ),
      ),
    );
  }
}
