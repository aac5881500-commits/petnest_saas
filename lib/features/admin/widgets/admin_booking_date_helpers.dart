// lib/features/admin/widgets/admin_booking_date_helpers.dart
// 🕒 後台訂單詳細頁：日期時間格式工具
// 功能：把 DateTime / Timestamp 轉成畫面顯示文字

import 'package:cloud_firestore/cloud_firestore.dart';

String adminBookingFormatDate(DateTime date) {
  return '${date.year}-${date.month}-${date.day}';
}

String adminBookingFormatDateTime(dynamic value) {
  if (value == null) return '-';

  final date = (value as Timestamp).toDate();

  return '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}';
}