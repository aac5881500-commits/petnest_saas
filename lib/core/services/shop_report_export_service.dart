// 檔案名稱：lib/core/services/shop_report_export_service.dart
// 功能說明：依 ShopReportBundle 產生 Excel（可多工作表）。

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

enum ShopReportExportKind { daily, revenue, room, addon, member, all }

extension ShopReportExportKindX on ShopReportExportKind {
  String get label {
    switch (this) {
      case ShopReportExportKind.daily:
        return '日期統計';
      case ShopReportExportKind.revenue:
        return '營收統計';
      case ShopReportExportKind.room:
        return '房型統計';
      case ShopReportExportKind.addon:
        return '加購統計';
      case ShopReportExportKind.member:
        return '會員統計';
      case ShopReportExportKind.all:
        return '全部營運資料';
    }
  }

  String get subtitle {
    switch (this) {
      case ShopReportExportKind.daily:
        return '每天訂單、入住退房與住宿晚數';
      case ShopReportExportKind.revenue:
        return '住宿、加購、商城與已付款';
      case ShopReportExportKind.room:
        return '各房型訂單與房費收入';
      case ShopReportExportKind.addon:
        return '加購服務次數與收入';
      case ShopReportExportKind.member:
        return '會員消費與回訪';
      case ShopReportExportKind.all:
        return '總覽、日期、營收、房型、加購、會員';
    }
  }

  String get fileLabel => label;
}

class ShopReportExportService {
  ShopReportExportService._();

  static final ShopReportExportService instance = ShopReportExportService._();

  Future<Uint8List> buildExcel({
    required String shopId,
    required ReportRange range,
    required ShopReportExportKind kind,
  }) async {
    final ShopReportBundle bundle = await ShopReportService.instance.load(
      shopId: shopId,
      range: range,
      includeMembers:
          kind == ShopReportExportKind.member ||
          kind == ShopReportExportKind.all,
      includeTrend: kind == ShopReportExportKind.all,
    );

    final Excel excel = Excel.createExcel();

    switch (kind) {
      case ShopReportExportKind.daily:
        _daily(excel, bundle);
      case ShopReportExportKind.revenue:
        _revenue(excel, bundle);
      case ShopReportExportKind.room:
        _rooms(excel, bundle);
      case ShopReportExportKind.addon:
        _addons(excel, bundle);
      case ShopReportExportKind.member:
        _members(excel, bundle);
      case ShopReportExportKind.all:
        _overview(excel, bundle);
        _daily(excel, bundle);
        _revenue(excel, bundle);
        _rooms(excel, bundle);
        _addons(excel, bundle);
        _members(excel, bundle);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final List<int>? bytes = excel.encode();
    return Uint8List.fromList(bytes ?? <int>[]);
  }

  void _overview(Excel excel, ShopReportBundle bundle) {
    final Sheet sheet = excel['營運總覽'];
    final OverviewKpi kpi = bundle.overview;
    sheet.appendRow(<CellValue>[TextCellValue('項目'), TextCellValue('數值')]);
    _kv(sheet, '期間', bundle.range.label);
    _kv(sheet, '開始日', ShopReportFormat.date.format(bundle.range.startDate));
    _kv(sheet, '結束日', ShopReportFormat.date.format(bundle.range.endDate));
    _kvNum(sheet, '訂單數', kpi.orders);
    _kvNum(sheet, '營收', kpi.orderAmount);
    _kvNum(sheet, '已付款', kpi.paidAmount);
    _kvNum(sheet, '住宿晚數', kpi.nights);
    _kvNum(sheet, '入住寵物數', kpi.pets);
    _kvNum(sheet, '平均客單', kpi.averageOrderAmount);
    sheet.appendRow(<CellValue>[
      TextCellValue('取消率(%)'),
      DoubleCellValue(kpi.cancelRate * 100),
    ]);
    _kvNum(sheet, '新會員數', kpi.newMembers);
    sheet.appendRow(const <CellValue>[]);
    sheet.appendRow(<CellValue>[
      TextCellValue('熱門房型'),
      TextCellValue('筆數'),
      TextCellValue('收入'),
    ]);
    for (final NamedMoneyRow row in bundle.topRooms) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.name),
        IntCellValue(row.count),
        IntCellValue(row.revenue),
      ]);
    }
    sheet.appendRow(const <CellValue>[]);
    sheet.appendRow(<CellValue>[
      TextCellValue('熱門加購'),
      TextCellValue('筆數'),
      TextCellValue('收入'),
    ]);
    for (final NamedMoneyRow row in bundle.topAddons) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.name),
        IntCellValue(row.count),
        IntCellValue(row.revenue),
      ]);
    }
    sheet.appendRow(const <CellValue>[]);
    sheet.appendRow(<CellValue>[
      TextCellValue('月份'),
      TextCellValue('訂單數'),
      TextCellValue('營收'),
    ]);
    for (final MonthTrendRow row in bundle.monthTrend) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.month),
        IntCellValue(row.orderCount),
        IntCellValue(row.revenue),
      ]);
    }
  }

  void _daily(Excel excel, ShopReportBundle bundle) {
    final Sheet sheet = excel['日期統計'];
    sheet.appendRow(<CellValue>[
      TextCellValue('日期'),
      TextCellValue('新增訂單數'),
      TextCellValue('確認訂單數'),
      TextCellValue('取消訂單數'),
      TextCellValue('入住數'),
      TextCellValue('退房完成數'),
      TextCellValue('住宿晚數'),
      TextCellValue('住宿寵物數'),
      TextCellValue('訂單總金額'),
      TextCellValue('已付款金額'),
      TextCellValue('平均訂單金額'),
      TextCellValue('取消率(%)'),
    ]);
    for (final DailyOpsRow row in bundle.daily) {
      sheet.appendRow(<CellValue>[
        TextCellValue(ShopReportFormat.date.format(row.date)),
        IntCellValue(row.newOrders),
        IntCellValue(row.confirmedOrders),
        IntCellValue(row.cancelledOrders),
        IntCellValue(row.checkIns),
        IntCellValue(row.checkOuts),
        IntCellValue(row.nights),
        IntCellValue(row.pets),
        IntCellValue(row.orderAmount),
        IntCellValue(row.paidAmount),
        IntCellValue(row.averageOrderAmount),
        DoubleCellValue(row.cancelRate * 100),
      ]);
    }
  }

  void _revenue(Excel excel, ShopReportBundle bundle) {
    final Sheet sheet = excel['營收'];
    sheet.appendRow(<CellValue>[
      TextCellValue('期間'),
      TextCellValue('訂單數'),
      TextCellValue('住宿營收'),
      TextCellValue('加購營收'),
      TextCellValue('商城營收'),
      TextCellValue('訂單折扣'),
      TextCellValue('優惠券折抵'),
      TextCellValue('特殊日期加價'),
      TextCellValue('訂單金額'),
      TextCellValue('已付款'),
      TextCellValue('待收款'),
      TextCellValue('退款'),
    ]);
    for (final RevenuePeriodRow row in bundle.revenueByMonth) {
      _revenueRow(sheet, row);
    }
    sheet.appendRow(const <CellValue>[]);
    sheet.appendRow(<CellValue>[TextCellValue('依日期')]);
    sheet.appendRow(<CellValue>[
      TextCellValue('日期'),
      TextCellValue('訂單數'),
      TextCellValue('住宿營收'),
      TextCellValue('加購營收'),
      TextCellValue('商城營收'),
      TextCellValue('訂單折扣'),
      TextCellValue('優惠券折抵'),
      TextCellValue('特殊日期加價'),
      TextCellValue('訂單金額'),
      TextCellValue('已付款'),
      TextCellValue('待收款'),
      TextCellValue('退款'),
    ]);
    for (final RevenuePeriodRow row in bundle.revenueByDay.where(
      (RevenuePeriodRow e) => e.hasActivity,
    )) {
      _revenueRow(sheet, row);
    }
  }

  void _revenueRow(Sheet sheet, RevenuePeriodRow row) {
    sheet.appendRow(<CellValue>[
      TextCellValue(row.label),
      IntCellValue(row.orderCount),
      IntCellValue(row.stayRevenue),
      IntCellValue(row.addonRevenue),
      IntCellValue(row.storeRevenue),
      IntCellValue(row.discountAmount),
      IntCellValue(row.couponAmount),
      IntCellValue(row.surchargeAmount),
      IntCellValue(row.orderAmount),
      IntCellValue(row.paidAmount),
      IntCellValue(row.unpaidAmount),
      IntCellValue(row.refundAmount),
    ]);
  }

  void _rooms(Excel excel, ShopReportBundle bundle) {
    final Sheet sheet = excel['房型'];
    sheet.appendRow(<CellValue>[
      TextCellValue('房型名稱'),
      TextCellValue('訂單數'),
      TextCellValue('住宿晚數'),
      TextCellValue('入住寵物數'),
      TextCellValue('房型收入'),
      TextCellValue('平均每筆訂單收入'),
    ]);
    for (final RoomTypeRow row in bundle.roomTypes) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.roomTypeName),
        IntCellValue(row.orderCount),
        IntCellValue(row.nights),
        IntCellValue(row.pets),
        IntCellValue(row.revenue),
        IntCellValue(row.averageOrderRevenue),
      ]);
    }
  }

  void _addons(Excel excel, ShopReportBundle bundle) {
    final Sheet sheet = excel['加購'];
    sheet.appendRow(<CellValue>[
      TextCellValue('服務名稱'),
      TextCellValue('類型'),
      TextCellValue('被購買次數'),
      TextCellValue('總數量'),
      TextCellValue('總收入'),
      TextCellValue('平均單價'),
    ]);
    for (final AddonRow row in bundle.addons) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.name),
        TextCellValue(row.typeLabel),
        IntCellValue(row.purchaseCount),
        IntCellValue(row.quantity),
        IntCellValue(row.revenue),
        IntCellValue(row.averagePrice),
      ]);
    }
  }

  void _members(Excel excel, ShopReportBundle bundle) {
    final Sheet sheet = excel['會員'];
    sheet.appendRow(<CellValue>[
      TextCellValue('會員姓名'),
      TextCellValue('電話'),
      TextCellValue('首次訂單日'),
      TextCellValue('最近訂單日'),
      TextCellValue('完成訂單數'),
      TextCellValue('累積消費'),
      TextCellValue('平均客單'),
      TextCellValue('近30天有消費'),
      TextCellValue('近90天有消費'),
      TextCellValue('VIP'),
      TextCellValue('黑名單'),
    ]);
    for (final MemberRow row in bundle.members) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.name),
        TextCellValue(row.phone),
        TextCellValue(
          row.firstOrderAt == null
              ? ''
              : ShopReportFormat.date.format(row.firstOrderAt!),
        ),
        TextCellValue(
          row.lastOrderAt == null
              ? ''
              : ShopReportFormat.date.format(row.lastOrderAt!),
        ),
        IntCellValue(row.completedOrders),
        IntCellValue(row.spend),
        IntCellValue(row.averageSpend),
        TextCellValue(row.spentLast30 ? '是' : '否'),
        TextCellValue(row.spentLast90 ? '是' : '否'),
        TextCellValue(row.isVip ? '是' : '否'),
        TextCellValue(row.isBlacklisted ? '是' : '否'),
      ]);
    }
  }

  void _kv(Sheet sheet, String key, String value) {
    sheet.appendRow(<CellValue>[TextCellValue(key), TextCellValue(value)]);
  }

  void _kvNum(Sheet sheet, String key, int value) {
    sheet.appendRow(<CellValue>[TextCellValue(key), IntCellValue(value)]);
  }
}
