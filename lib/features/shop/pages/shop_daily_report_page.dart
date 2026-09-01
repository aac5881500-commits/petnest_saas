// lib/features/shop/pages/shop_daily_report_page.dart
// 📅 日期統計報表：每天訂單、入住退房、住宿晚數與訂單金額。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopDailyReportPage extends StatefulWidget {
  const ShopDailyReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopDailyReportPage> createState() => _ShopDailyReportPageState();
}

class _ShopDailyReportPageState extends State<ShopDailyReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late Future<ShopReportBundle> _future;
  String _sortId = 'date';
  bool _sortAsc = false;

  static const List<ReportColumn> _columns = <ReportColumn>[
    ReportColumn(id: 'date', label: '日期'),
    ReportColumn(id: 'newOrders', label: '新增訂單', numeric: true),
    ReportColumn(id: 'confirmed', label: '確認訂單', numeric: true),
    ReportColumn(id: 'cancelled', label: '取消訂單', numeric: true),
    ReportColumn(id: 'checkIns', label: '入住數', numeric: true),
    ReportColumn(id: 'checkOuts', label: '退房完成', numeric: true),
    ReportColumn(id: 'nights', label: '住宿晚數', numeric: true),
    ReportColumn(id: 'pets', label: '住宿寵物', numeric: true),
    ReportColumn(id: 'orderAmount', label: '訂單總金額', money: true),
    ReportColumn(id: 'paidAmount', label: '已付款金額', money: true),
    ReportColumn(id: 'avg', label: '平均訂單金額', money: true),
    ReportColumn(id: 'cancelRate', label: '取消率', numeric: true),
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
        _sortAsc = id == 'date';
      }
    });
  }

  List<DailyOpsRow> _sorted(List<DailyOpsRow> rows) {
    final List<DailyOpsRow> copy = List<DailyOpsRow>.from(rows);
    copy.sort((DailyOpsRow a, DailyOpsRow b) {
      final int c = ShopReportFormat.compare(_key(a), _key(b));
      return _sortAsc ? c : -c;
    });
    return copy;
  }

  dynamic _key(DailyOpsRow row) {
    switch (_sortId) {
      case 'newOrders':
        return row.newOrders;
      case 'confirmed':
        return row.confirmedOrders;
      case 'cancelled':
        return row.cancelledOrders;
      case 'checkIns':
        return row.checkIns;
      case 'checkOuts':
        return row.checkOuts;
      case 'nights':
        return row.nights;
      case 'pets':
        return row.pets;
      case 'orderAmount':
        return row.orderAmount;
      case 'paidAmount':
        return row.paidAmount;
      case 'avg':
        return row.averageOrderAmount;
      case 'cancelRate':
        return row.cancelRate;
      case 'date':
      default:
        return row.date;
    }
  }

  String _value(DailyOpsRow row, String id) {
    switch (id) {
      case 'date':
        return ShopReportFormat.date.format(row.date);
      case 'newOrders':
        return ShopReportFormat.number(row.newOrders);
      case 'confirmed':
        return ShopReportFormat.number(row.confirmedOrders);
      case 'cancelled':
        return ShopReportFormat.number(row.cancelledOrders);
      case 'checkIns':
        return ShopReportFormat.number(row.checkIns);
      case 'checkOuts':
        return ShopReportFormat.number(row.checkOuts);
      case 'nights':
        return ShopReportFormat.number(row.nights);
      case 'pets':
        return ShopReportFormat.number(row.pets);
      case 'orderAmount':
        return ShopReportFormat.money(row.orderAmount);
      case 'paidAmount':
        return ShopReportFormat.money(row.paidAmount);
      case 'avg':
        return ShopReportFormat.money(row.averageOrderAmount);
      case 'cancelRate':
        return ShopReportFormat.percent(row.cancelRate);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日期統計報表')),
      body: FutureBuilder<ShopReportBundle>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ShopReportBundle> snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                '日期統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '查看每天住宿訂單與入住退房變化',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ReportRangeSelector(range: _range, onChanged: _setRange),
              const SizedBox(height: 8),
              const ReportNote(
                '新增 / 確認 / 取消 / 訂單金額依訂單建立日。住宿晚數與寵物數來自當日建立的有效訂單（確認、入住、完成）。入住依 checkInAt（沒有則用 startDate），退房依 checkOutAt（沒有則用 endDate）。已付款依當日實際付款，不與訂單金額混用。不含商城。因可售房晚無法可靠計算，本頁不顯示入住率。',
              ),
              ReportStatusBody(
                snapshot: snap,
                builder: () {
                  final ShopReportBundle bundle = snap.data!;
                  final DailyOpsSummary s = bundle.dailySummary;
                  final List<DailyOpsRow> rows = _sorted(bundle.daily);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ReportKpiGrid(
                        items: <ReportKpiItem>[
                          ReportKpiItem(
                            label: '總訂單',
                            value: ShopReportFormat.number(s.orders),
                          ),
                          ReportKpiItem(
                            label: '總住宿晚數',
                            value: ShopReportFormat.number(s.nights),
                          ),
                          ReportKpiItem(
                            label: '總營收',
                            value: ShopReportFormat.money(s.orderAmount),
                          ),
                          ReportKpiItem(
                            label: '已付款',
                            value: ShopReportFormat.money(s.paidAmount),
                          ),
                          ReportKpiItem(
                            label: '平均訂單金額',
                            value: ShopReportFormat.money(s.averageOrderAmount),
                          ),
                          ReportKpiItem(
                            label: '取消率',
                            value: ShopReportFormat.percent(s.cancelRate),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!bundle.daily.any((DailyOpsRow e) => e.hasActivity))
                        const ReportEmpty()
                      else
                        ReportResponsiveTable(
                          columns: _columns,
                          rowCount: rows.length,
                          sortId: _sortId,
                          sortAsc: _sortAsc,
                          onSort: _toggleSort,
                          titleOf: (int i) =>
                              ShopReportFormat.date.format(rows[i].date),
                          subtitleOf: (int i) =>
                              '新增 ${rows[i].newOrders}　確認 ${rows[i].confirmedOrders}',
                          valueOf: (int i, String id) => _value(rows[i], id),
                          onRowTap: (int i) => _showDay(rows[i]),
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

  void _showDay(DailyOpsRow row) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(ShopReportFormat.date.format(row.date)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('新增訂單 ${row.newOrders}'),
              Text('確認訂單 ${row.confirmedOrders}'),
              Text('取消訂單 ${row.cancelledOrders}'),
              Text('入住 ${row.checkIns}　退房 ${row.checkOuts}'),
              Text('住宿晚數 ${row.nights}　寵物 ${row.pets}'),
              Text('訂單金額 ${ShopReportFormat.money(row.orderAmount)}'),
              Text('已付款 ${ShopReportFormat.money(row.paidAmount)}'),
              Text('取消率 ${ShopReportFormat.percent(row.cancelRate)}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }
}
