// 檔案名稱：lib/features/shop/pages/shop_revenue_report_page.dart
// 功能說明：營收統計：住宿 / 加購 / 商城分開，訂單應收與實際已付款分開。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopRevenueReportPage extends StatefulWidget {
  const ShopRevenueReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopRevenueReportPage> createState() => _ShopRevenueReportPageState();
}

class _ShopRevenueReportPageState extends State<ShopRevenueReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late Future<ShopReportBundle> _future;
  bool _byMonth = false;
  String _sortId = 'label';
  bool _sortAsc = false;

  static const List<ReportColumn> _columns = <ReportColumn>[
    ReportColumn(id: 'label', label: '期間'),
    ReportColumn(id: 'orders', label: '訂單數', numeric: true),
    ReportColumn(id: 'stay', label: '住宿營收', money: true),
    ReportColumn(id: 'addon', label: '加購營收', money: true),
    ReportColumn(id: 'store', label: '商城營收', money: true),
    ReportColumn(id: 'discount', label: '訂單折扣', money: true),
    ReportColumn(id: 'coupon', label: '優惠券折抵', money: true),
    ReportColumn(id: 'surcharge', label: '特殊日期加價', money: true),
    ReportColumn(id: 'orderAmount', label: '訂單金額', money: true),
    ReportColumn(id: 'paid', label: '已付款', money: true),
    ReportColumn(id: 'unpaid', label: '待收款', money: true),
    ReportColumn(id: 'refund', label: '退款', money: true),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ShopReportBundle> _load() {
    return ShopReportService.instance.load(
      shopId: widget.shopId,
      range: _range,
    );
  }

  void _setRange(ReportRange range) {
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  void _toggleSort(String id) {
    setState(() {
      if (_sortId == id) {
        _sortAsc = !_sortAsc;
      } else {
        _sortId = id;
        _sortAsc = false;
      }
    });
  }

  List<RevenuePeriodRow> _sorted(List<RevenuePeriodRow> rows) {
    final List<RevenuePeriodRow> copy = List<RevenuePeriodRow>.from(rows);
    copy.sort((RevenuePeriodRow a, RevenuePeriodRow b) {
      final int c = ShopReportFormat.compare(_key(a), _key(b));
      return _sortAsc ? c : -c;
    });
    return copy;
  }

  dynamic _key(RevenuePeriodRow row) {
    switch (_sortId) {
      case 'orders':
        return row.orderCount;
      case 'stay':
        return row.stayRevenue;
      case 'addon':
        return row.addonRevenue;
      case 'store':
        return row.storeRevenue;
      case 'discount':
        return row.discountAmount;
      case 'coupon':
        return row.couponAmount;
      case 'surcharge':
        return row.surchargeAmount;
      case 'orderAmount':
        return row.orderAmount;
      case 'paid':
        return row.paidAmount;
      case 'unpaid':
        return row.unpaidAmount;
      case 'refund':
        return row.refundAmount;
      case 'label':
      default:
        return row.label;
    }
  }

  String _value(RevenuePeriodRow row, String id) {
    switch (id) {
      case 'label':
        return row.label;
      case 'orders':
        return ShopReportFormat.number(row.orderCount);
      case 'stay':
        return ShopReportFormat.money(row.stayRevenue);
      case 'addon':
        return ShopReportFormat.money(row.addonRevenue);
      case 'store':
        return ShopReportFormat.money(row.storeRevenue);
      case 'discount':
        return ShopReportFormat.money(row.discountAmount);
      case 'coupon':
        return ShopReportFormat.money(row.couponAmount);
      case 'surcharge':
        return ShopReportFormat.money(row.surchargeAmount);
      case 'orderAmount':
        return ShopReportFormat.money(row.orderAmount);
      case 'paid':
        return ShopReportFormat.money(row.paidAmount);
      case 'unpaid':
        return ShopReportFormat.money(row.unpaidAmount);
      case 'refund':
        return ShopReportFormat.money(row.refundAmount);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('營收統計報表')),
      body: FutureBuilder<ShopReportBundle>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ShopReportBundle> snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                '營收統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '住宿、加購與商城分開，訂單金額與已付款分開',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ReportRangeSelector(range: _range, onChanged: _setRange),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, label: Text('依日期')),
                  ButtonSegment<bool>(value: true, label: Text('依月份')),
                ],
                selected: <bool>{_byMonth},
                onSelectionChanged: (Set<bool> value) {
                  setState(() {
                    _byMonth = value.first;
                    _sortId = 'label';
                    _sortAsc = false;
                  });
                },
              ),
              const SizedBox(height: 8),
              const ReportNote(
                '訂單金額：期間內建立的有效住宿訂單（確認 / 入住 / 完成）+ 有效商城訂單，取消與待付款不算。已付款：payments 狀態為已付款（部分退款計剩餘額）且付款時間落在期間內。待收款：該筆有效訂單尚未付清的餘額。舊訂單沒有加價 / 折扣 / 優惠券欄位時視為 0。',
              ),
              ReportStatusBody(
                snapshot: snap,
                builder: () {
                  final ShopReportBundle bundle = snap.data!;
                  final RevenueKpi kpi = bundle.revenueKpi;
                  final List<RevenuePeriodRow> source = _byMonth
                      ? bundle.revenueByMonth
                      : bundle.revenueByDay;
                  final List<RevenuePeriodRow> rows = _sorted(
                    source
                        .where((RevenuePeriodRow e) => e.hasActivity)
                        .toList(),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ReportKpiGrid(
                        items: <ReportKpiItem>[
                          ReportKpiItem(
                            label: '總營收',
                            value: ShopReportFormat.money(kpi.totalRevenue),
                          ),
                          ReportKpiItem(
                            label: '住宿營收',
                            value: ShopReportFormat.money(kpi.stayRevenue),
                          ),
                          ReportKpiItem(
                            label: '加購營收',
                            value: ShopReportFormat.money(kpi.addonRevenue),
                          ),
                          ReportKpiItem(
                            label: '商城營收',
                            value: ShopReportFormat.money(kpi.storeRevenue),
                          ),
                          ReportKpiItem(
                            label: '已付款',
                            value: ShopReportFormat.money(kpi.paidAmount),
                          ),
                          ReportKpiItem(
                            label: '待收款',
                            value: ShopReportFormat.money(kpi.unpaidAmount),
                          ),
                          ReportKpiItem(
                            label: '訂單折扣',
                            value: ShopReportFormat.money(kpi.discountAmount),
                          ),
                          ReportKpiItem(
                            label: '優惠券折抵',
                            value: ShopReportFormat.money(kpi.couponAmount),
                          ),
                          ReportKpiItem(
                            label: '特殊日期加價',
                            value: ShopReportFormat.money(kpi.surchargeAmount),
                          ),
                          ReportKpiItem(
                            label: '退款',
                            value: ShopReportFormat.money(kpi.refundAmount),
                          ),
                          ReportKpiItem(
                            label: '住宿訂單',
                            value: ShopReportFormat.number(kpi.stayOrderCount),
                          ),
                          ReportKpiItem(
                            label: '商城訂單',
                            value: ShopReportFormat.number(kpi.storeOrderCount),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ReportResponsiveTable(
                        columns: _columns,
                        rowCount: rows.length,
                        sortId: _sortId,
                        sortAsc: _sortAsc,
                        onSort: _toggleSort,
                        titleOf: (int i) => rows[i].label,
                        subtitleOf: (int i) =>
                            '住宿 ${ShopReportFormat.money(rows[i].stayRevenue)}　商城 ${ShopReportFormat.money(rows[i].storeRevenue)}',
                        valueOf: (int i, String id) => _value(rows[i], id),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
