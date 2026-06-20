// lib/core/services/shop_report_service.dart
// 📊 店家營運報表統計服務
// 功能：從 bookings 計算日期統計、營收統計、房型統計、加購統計，未來 Excel 匯出也會共用這裡

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyShopReport {
  DailyShopReport({
    required this.date,
    required this.orderCount,
    required this.checkInCount,
    required this.checkOutCount,
    required this.cancelCount,
    required this.roomRevenue,
    required this.discountAmount,
    required this.addonRevenue,
    required this.extraChargeRevenue,
    required this.finalRevenue,
  });

  final DateTime date;
  final int orderCount;
  final int checkInCount;
  final int checkOutCount;
  final int cancelCount;
  final int roomRevenue;
  final int discountAmount;
  final int addonRevenue;
  final int extraChargeRevenue;
  final int finalRevenue;

  int get revenue => finalRevenue;
}

class MonthlyRevenueReport {
  MonthlyRevenueReport({
    required this.month,
    required this.orderCount,
    required this.cancelCount,
    required this.roomRevenue,
    required this.discountAmount,
    required this.addonRevenue,
    required this.extraChargeRevenue,
    required this.finalRevenue,
  });

  final String month;
  final int orderCount;
  final int cancelCount;
  final int roomRevenue;
  final int discountAmount;
  final int addonRevenue;
  final int extraChargeRevenue;
  final int finalRevenue;

  int get revenue => finalRevenue;

  int get averageOrderValue {
    final paidOrderCount = orderCount - cancelCount;
    if (paidOrderCount <= 0) return 0;
    return (finalRevenue / paidOrderCount).round();
  }
}

class RoomTypeReport {
  RoomTypeReport({
    required this.roomTypeName,
    required this.orderCount,
    required this.validOrderCount,
    required this.cancelCount,
    required this.roomRevenue,
    required this.discountAmount,
    required this.addonRevenue,
    required this.extraChargeRevenue,
    required this.finalRevenue,
  });

  final String roomTypeName;
  final int orderCount;
  final int validOrderCount;
  final int cancelCount;
  final int roomRevenue;
  final int discountAmount;
  final int addonRevenue;
  final int extraChargeRevenue;
  final int finalRevenue;

  int get revenue => finalRevenue;
}

class AddonReport {
  AddonReport({
    required this.name,
    required this.type,
    required this.saleCount,
    required this.revenue,
  });

  final String name;
  final String type;
  final int saleCount;
  final int revenue;
}

class ShopReportService {
  ShopReportService._();

  static final ShopReportService instance = ShopReportService._();

  Future<List<DailyShopReport>> getDailyReports({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    final Map<String, _ReportMoneyBuilder> map = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final createdAt = data['createdAt'];
      if (createdAt is! Timestamp) continue;

      final date = createdAt.toDate();

      if (date.isBefore(start) || date.isAfter(endDate)) {
        continue;
      }

      final key = _dateKey(date);

      map.putIfAbsent(
        key,
        () => _ReportMoneyBuilder(
          labelDate: DateTime(date.year, date.month, date.day),
        ),
      );

      final builder = map[key]!;
      final status = (data['status'] ?? '').toString();

      builder.orderCount++;

      if (status == 'cancelled') {
        builder.cancelCount++;
      }

      if (_isRevenueStatus(status)) {
        builder.addBookingMoney(data);
      }
    }

    final result = <DailyShopReport>[];

    var cursor = start;
    while (!cursor.isAfter(endDate)) {
      final key = _dateKey(cursor);
      final builder = map[key];

      result.add(
        DailyShopReport(
          date: DateTime(cursor.year, cursor.month, cursor.day),
          orderCount: builder?.orderCount ?? 0,
          checkInCount: builder?.checkInCount ?? 0,
          checkOutCount: builder?.checkOutCount ?? 0,
          cancelCount: builder?.cancelCount ?? 0,
          roomRevenue: builder?.roomRevenue ?? 0,
          discountAmount: builder?.discountAmount ?? 0,
          addonRevenue: builder?.addonRevenue ?? 0,
          extraChargeRevenue: builder?.extraChargeRevenue ?? 0,
          finalRevenue: builder?.finalRevenue ?? 0,
        ),
      );

      cursor = cursor.add(const Duration(days: 1));
    }

    return result.reversed.toList();
  }

  Future<List<MonthlyRevenueReport>> getMonthlyRevenueReports({
    required String shopId,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    final Map<String, _ReportMoneyBuilder> map = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final createdAt = data['createdAt'];
      if (createdAt is! Timestamp) continue;

      final date = createdAt.toDate();
      final monthKey = '${date.year}/${date.month.toString().padLeft(2, '0')}';

      final status = (data['status'] ?? '').toString();

      map.putIfAbsent(monthKey, () => _ReportMoneyBuilder(label: monthKey));

      final builder = map[monthKey]!;

      builder.orderCount++;

      if (status == 'cancelled') {
        builder.cancelCount++;
      }

      if (_isRevenueStatus(status)) {
        builder.addBookingMoney(data);
      }
    }

    final result = map.entries.map((entry) {
      final builder = entry.value;

      return MonthlyRevenueReport(
        month: entry.key,
        orderCount: builder.orderCount,
        cancelCount: builder.cancelCount,
        roomRevenue: builder.roomRevenue,
        discountAmount: builder.discountAmount,
        addonRevenue: builder.addonRevenue,
        extraChargeRevenue: builder.extraChargeRevenue,
        finalRevenue: builder.finalRevenue,
      );
    }).toList();

    result.sort((a, b) => b.month.compareTo(a.month));

    return result;
  }

  Future<List<RoomTypeReport>> getRoomTypeReports({
    required String shopId,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    final Map<String, _ReportMoneyBuilder> map = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString();

      final roomTypeName =
          (data['roomTypeName'] ??
                  data['roomType'] ??
                  data['selectedRoomTypeName'] ??
                  '未指定房型')
              .toString();

      map.putIfAbsent(roomTypeName, () => _ReportMoneyBuilder());

      final builder = map[roomTypeName]!;

      builder.orderCount++;

      if (status == 'cancelled') {
        builder.cancelCount++;
      }

      if (_isRevenueStatus(status)) {
        builder.validOrderCount++;
        builder.addBookingMoney(data);
      }
    }

    final result = map.entries.map((entry) {
      final builder = entry.value;

      return RoomTypeReport(
        roomTypeName: entry.key,
        orderCount: builder.orderCount,
        validOrderCount: builder.validOrderCount,
        cancelCount: builder.cancelCount,
        roomRevenue: builder.roomRevenue,
        discountAmount: builder.discountAmount,
        addonRevenue: builder.addonRevenue,
        extraChargeRevenue: builder.extraChargeRevenue,
        finalRevenue: builder.finalRevenue,
      );
    }).toList();

    result.sort((a, b) => b.finalRevenue.compareTo(a.finalRevenue));

    return result;
  }

  Future<List<AddonReport>> getAddonReports({required String shopId}) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    final Map<String, AddonReport> map = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString();

      if (!_isRevenueStatus(status)) {
        continue;
      }

      final addons = data['addons'];

      if (addons is! List) {
        continue;
      }

      for (final rawAddon in addons) {
        if (rawAddon is! Map) continue;

        final name = (rawAddon['name'] ?? '未命名加購').toString();
        final type = (rawAddon['type'] ?? 'other').toString();

        final saleCount = _readInt(rawAddon['count'] ?? 1);
        final revenue = _readInt(rawAddon['total'] ?? rawAddon['price'] ?? 0);

        final key = '$type-$name';

        if (!map.containsKey(key)) {
          map[key] = AddonReport(
            name: name,
            type: type,
            saleCount: 0,
            revenue: 0,
          );
        }

        final item = map[key]!;

        map[key] = AddonReport(
          name: item.name,
          type: item.type,
          saleCount: item.saleCount + saleCount,
          revenue: item.revenue + revenue,
        );
      }
    }

    final result = map.values.toList();

    result.sort((a, b) => b.revenue.compareTo(a.revenue));

    return result;
  }

  static bool _isRevenueStatus(String status) {
    return status == 'confirmed' ||
        status == 'checked_in' ||
        status == 'completed';
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static int _readRoomRevenue(Map<String, dynamic> data) {
    final finalRevenue = _readFinalRevenue(data);
    final addonRevenue = _readAddonRevenue(data);
    final extraChargeRevenue = _readExtraChargeRevenue(data);
    final discountAmount = _readDiscountAmount(data);

    final roomRevenue =
        finalRevenue - addonRevenue - extraChargeRevenue + discountAmount;

    if (roomRevenue < 0) return 0;

    return roomRevenue;
  }

  static int _readDiscountAmount(Map<String, dynamic> data) {
    final directDiscount = _readInt(
      data['discountAmount'] ?? data['discountTotal'] ?? 0,
    );

    if (directDiscount > 0) {
      return directDiscount;
    }

    final originalTotal = _readInt(
      data['originalTotal'] ?? data['subtotal'] ?? 0,
    );

    final totalPrice = _readInt(data['totalPrice'] ?? data['totalAmount'] ?? 0);

    if (originalTotal > totalPrice) {
      return originalTotal - totalPrice;
    }

    return 0;
  }

  static int _readAddonRevenue(Map<String, dynamic> data) {
    final addons = data['addons'];

    if (addons is! List) {
      return _readInt(data['addonTotal'] ?? data['addonsTotal'] ?? 0);
    }

    var total = 0;

    for (final rawAddon in addons) {
      if (rawAddon is! Map) continue;

      total += _readInt(rawAddon['total'] ?? rawAddon['price'] ?? 0);
    }

    return total;
  }

  static int _readExtraChargeRevenue(Map<String, dynamic> data) {
    return _readInt(
      data['extraChargesTotal'] ??
          data['extraChargeTotal'] ??
          data['extraFeeTotal'] ??
          data['checkoutExtraTotal'] ??
          0,
    );
  }

  static int _readFinalRevenue(Map<String, dynamic> data) {
    final savedFinalRevenue = _readInt(
      data['finalRevenue'] ?? data['paidTotal'] ?? data['actualRevenue'] ?? 0,
    );

    if (savedFinalRevenue > 0) {
      return savedFinalRevenue;
    }

    return _readInt(
          data['totalAmount'] ??
              data['totalPrice'] ??
              data['total'] ??
              data['price'] ??
              0,
        ) +
        _readExtraChargeRevenue(data);
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class _ReportMoneyBuilder {
  _ReportMoneyBuilder({this.label, this.labelDate});

  final String? label;
  final DateTime? labelDate;

  int orderCount = 0;
  int validOrderCount = 0;
  int checkInCount = 0;
  int checkOutCount = 0;
  int cancelCount = 0;

  int roomRevenue = 0;
  int discountAmount = 0;
  int addonRevenue = 0;
  int extraChargeRevenue = 0;
  int finalRevenue = 0;

  void addBookingMoney(Map<String, dynamic> data) {
    roomRevenue += ShopReportService._readRoomRevenue(data);
    discountAmount += ShopReportService._readDiscountAmount(data);
    addonRevenue += ShopReportService._readAddonRevenue(data);
    extraChargeRevenue += ShopReportService._readExtraChargeRevenue(data);
    finalRevenue += ShopReportService._readFinalRevenue(data);
  }
}
