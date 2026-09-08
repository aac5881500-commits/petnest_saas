// 檔案名稱：lib/core/navigation/admin_booking_route.dart
// 功能說明：後台訂單導頁：依訂單種類開啟安親或住宿詳細頁，不依入口頁決定。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_detail_page.dart';

class AdminBookingRoute {
  AdminBookingRoute._();

  static bool isDaycareBooking(Map<String, dynamic>? data) {
    return BookingKind.isDaycare(data);
  }

  static Widget page({
    required String bookingId,
    Map<String, dynamic>? data,
    String shopId = '',
    bool canEdit = true,
  }) {
    final String resolvedShopId = shopId.trim().isNotEmpty
        ? shopId.trim()
        : (data?['shopId'] ?? '').toString().trim();
    if (isDaycareBooking(data)) {
      return AdminDaycareDetailPage(
        shopId: resolvedShopId,
        bookingId: bookingId,
        canEdit: canEdit,
      );
    }
    return AdminBookingDetailPage(bookingId: bookingId, canEdit: canEdit);
  }

  static Future<void> open(
    BuildContext context, {
    required String bookingId,
    Map<String, dynamic>? data,
    String shopId = '',
    bool canEdit = true,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) {
          if (data != null) {
            return page(
              bookingId: bookingId,
              data: data,
              shopId: shopId,
              canEdit: canEdit,
            );
          }
          return AdminBookingRouteGate(
            bookingId: bookingId,
            shopId: shopId,
            canEdit: canEdit,
          );
        },
      ),
    );
  }
}

class AdminBookingRouteGate extends StatelessWidget {
  const AdminBookingRouteGate({
    super.key,
    required this.bookingId,
    this.shopId = '',
    this.canEdit = true,
  });

  final String bookingId;
  final String shopId;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final Map<String, dynamic>? data = snapshot.data?.data();
            if (data == null) {
              return const Scaffold(body: Center(child: Text('找不到訂單')));
            }
            return AdminBookingRoute.page(
              bookingId: bookingId,
              data: data,
              shopId: shopId,
              canEdit: canEdit,
            );
          },
    );
  }
}
