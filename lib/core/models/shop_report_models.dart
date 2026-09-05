// 檔案名稱：lib/core/models/shop_report_models.dart
// 功能說明：營運報表唯讀資料列。金額單位為整數新台幣。

import 'package:petnest_saas/core/services/report_range.dart';

class DailyOpsRow {
  const DailyOpsRow({
    required this.date,
    required this.newOrders,
    required this.confirmedOrders,
    required this.cancelledOrders,
    required this.checkIns,
    required this.checkOuts,
    required this.nights,
    required this.pets,
    required this.orderAmount,
    required this.paidAmount,
  });

  final DateTime date;
  final int newOrders;
  final int confirmedOrders;
  final int cancelledOrders;
  final int checkIns;
  final int checkOuts;
  final int nights;
  final int pets;
  final int orderAmount;
  final int paidAmount;

  int get averageOrderAmount =>
      confirmedOrders <= 0 ? 0 : (orderAmount / confirmedOrders).round();

  double get cancelRate => newOrders <= 0 ? 0 : cancelledOrders / newOrders;

  bool get hasActivity =>
      newOrders > 0 ||
      checkIns > 0 ||
      checkOuts > 0 ||
      orderAmount > 0 ||
      paidAmount > 0;
}

class DailyOpsSummary {
  const DailyOpsSummary({
    required this.orders,
    required this.nights,
    required this.orderAmount,
    required this.paidAmount,
    required this.averageOrderAmount,
    required this.cancelRate,
  });

  final int orders;
  final int nights;
  final int orderAmount;
  final int paidAmount;
  final int averageOrderAmount;
  final double cancelRate;
}

class RevenuePeriodRow {
  const RevenuePeriodRow({
    required this.label,
    required this.orderCount,
    required this.stayRevenue,
    required this.addonRevenue,
    required this.storeRevenue,
    required this.discountAmount,
    required this.couponAmount,
    required this.surchargeAmount,
    required this.orderAmount,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.refundAmount,
  });

  final String label;
  final int orderCount;
  final int stayRevenue;
  final int addonRevenue;
  final int storeRevenue;
  final int discountAmount;
  final int couponAmount;
  final int surchargeAmount;
  final int orderAmount;
  final int paidAmount;
  final int unpaidAmount;
  final int refundAmount;

  int get totalRevenue => stayRevenue + addonRevenue + storeRevenue;

  bool get hasActivity =>
      orderCount > 0 || paidAmount > 0 || refundAmount > 0 || orderAmount > 0;
}

class RevenueKpi {
  const RevenueKpi({
    required this.orderAmount,
    required this.stayRevenue,
    required this.addonRevenue,
    required this.storeRevenue,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.refundAmount,
    required this.discountAmount,
    required this.couponAmount,
    required this.surchargeAmount,
    required this.stayOrderCount,
    required this.storeOrderCount,
  });

  final int orderAmount;
  final int stayRevenue;
  final int addonRevenue;
  final int storeRevenue;
  final int paidAmount;
  final int unpaidAmount;
  final int refundAmount;
  final int discountAmount;
  final int couponAmount;
  final int surchargeAmount;
  final int stayOrderCount;
  final int storeOrderCount;

  int get totalRevenue => stayRevenue + addonRevenue + storeRevenue;
}

class RoomTypeRow {
  const RoomTypeRow({
    required this.roomTypeName,
    required this.orderCount,
    required this.nights,
    required this.pets,
    required this.revenue,
  });

  final String roomTypeName;
  final int orderCount;
  final int nights;
  final int pets;
  final int revenue;

  int get averageOrderRevenue =>
      orderCount <= 0 ? 0 : (revenue / orderCount).round();
}

class AddonRow {
  const AddonRow({
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.purchaseCount,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final String type;
  final String typeLabel;
  final int purchaseCount;
  final int quantity;
  final int revenue;

  int get averagePrice => quantity <= 0 ? 0 : (revenue / quantity).round();
}

class MemberRow {
  const MemberRow({
    required this.userId,
    required this.name,
    required this.phone,
    this.firstOrderAt,
    this.lastOrderAt,
    required this.completedOrders,
    required this.spend,
    required this.spentLast30,
    required this.spentLast90,
    required this.isVip,
    required this.isBlacklisted,
  });

  final String userId;
  final String name;
  final String phone;
  final DateTime? firstOrderAt;
  final DateTime? lastOrderAt;
  final int completedOrders;
  final int spend;
  final bool spentLast30;
  final bool spentLast90;
  final bool isVip;
  final bool isBlacklisted;

  int get averageSpend =>
      completedOrders <= 0 ? 0 : (spend / completedOrders).round();
}

class MemberKpi {
  const MemberKpi({
    required this.total,
    required this.newInRange,
    required this.spending,
    required this.returning,
    required this.vip,
    required this.blacklisted,
  });

  final int total;
  final int newInRange;
  final int spending;
  final int returning;
  final int vip;
  final int blacklisted;
}

class NamedMoneyRow {
  const NamedMoneyRow({
    required this.name,
    required this.count,
    required this.revenue,
  });

  final String name;
  final int count;
  final int revenue;
}

class MonthTrendRow {
  const MonthTrendRow({
    required this.month,
    required this.orderCount,
    required this.revenue,
  });

  final String month;
  final int orderCount;
  final int revenue;
}

class BookingMoneyBreakdown {
  const BookingMoneyBreakdown({
    required this.orderAmount,
    required this.room,
    required this.addon,
    required this.discount,
    required this.coupon,
    required this.surcharge,
  });

  final int orderAmount;
  final int room;
  final int addon;
  final int discount;
  final int coupon;
  final int surcharge;
}

class OverviewKpi {
  const OverviewKpi({
    required this.orders,
    required this.orderAmount,
    required this.paidAmount,
    required this.nights,
    required this.pets,
    required this.averageOrderAmount,
    required this.cancelRate,
    required this.newMembers,
  });

  final int orders;
  final int orderAmount;
  final int paidAmount;
  final int nights;
  final int pets;
  final int averageOrderAmount;
  final double cancelRate;
  final int newMembers;
}

class ShopReportBundle {
  const ShopReportBundle({
    required this.range,
    required this.daily,
    required this.dailySummary,
    required this.revenueByDay,
    required this.revenueByMonth,
    required this.revenueKpi,
    required this.roomTypes,
    required this.addons,
    required this.members,
    required this.memberKpi,
    required this.overview,
    required this.topRooms,
    required this.topAddons,
    required this.monthTrend,
  });

  final ReportRange range;
  final List<DailyOpsRow> daily;
  final DailyOpsSummary dailySummary;
  final List<RevenuePeriodRow> revenueByDay;
  final List<RevenuePeriodRow> revenueByMonth;
  final RevenueKpi revenueKpi;
  final List<RoomTypeRow> roomTypes;
  final List<AddonRow> addons;
  final List<MemberRow> members;
  final MemberKpi memberKpi;
  final OverviewKpi overview;
  final List<NamedMoneyRow> topRooms;
  final List<NamedMoneyRow> topAddons;
  final List<MonthTrendRow> monthTrend;
}
