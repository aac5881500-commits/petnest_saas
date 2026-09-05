// 檔案名稱：lib/features/shop/pages/shop_addon_report_page.dart
// 功能說明：加購服務統計：依訂單 snapshot 統計，封存後舊單仍可看。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopAddonReportPage extends StatefulWidget {
  const ShopAddonReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopAddonReportPage> createState() => _ShopAddonReportPageState();
}

class _ShopAddonReportPageState extends State<ShopAddonReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late Future<ShopReportBundle> _future;
  String _sortId = 'revenue';
  bool _sortAsc = false;

  static const List<ReportColumn> _columns = <ReportColumn>[
    ReportColumn(id: 'name', label: '服務名稱'),
    ReportColumn(id: 'type', label: '類型'),
    ReportColumn(id: 'purchases', label: '被購買次數', numeric: true),
    ReportColumn(id: 'qty', label: '總數量', numeric: true),
    ReportColumn(id: 'revenue', label: '總收入', money: true),
    ReportColumn(id: 'avg', label: '平均單價', money: true),
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

  List<AddonRow> _sorted(List<AddonRow> rows) {
    final List<AddonRow> copy = List<AddonRow>.from(rows);
    copy.sort((AddonRow a, AddonRow b) {
      final int c = ShopReportFormat.compare(_key(a), _key(b));
      return _sortAsc ? c : -c;
    });
    return copy;
  }

  dynamic _key(AddonRow row) {
    switch (_sortId) {
      case 'name':
        return row.name;
      case 'type':
        return row.typeLabel;
      case 'purchases':
        return row.purchaseCount;
      case 'qty':
        return row.quantity;
      case 'avg':
        return row.averagePrice;
      case 'revenue':
      default:
        return row.revenue;
    }
  }

  String _value(AddonRow row, String id) {
    switch (id) {
      case 'name':
        return row.name;
      case 'type':
        return row.typeLabel;
      case 'purchases':
        return ShopReportFormat.number(row.purchaseCount);
      case 'qty':
        return ShopReportFormat.number(row.quantity);
      case 'revenue':
        return ShopReportFormat.money(row.revenue);
      case 'avg':
        return ShopReportFormat.money(row.averagePrice);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加購服務統計')),
      body: FutureBuilder<ShopReportBundle>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ShopReportBundle> snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                '加購服務統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '時間加購、加值、客製、每日分時段服務',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ReportRangeSelector(range: _range, onChanged: _setRange),
              const SizedBox(height: 8),
              const ReportNote(
                '只統計期間內建立的有效住宿訂單上的 addons 快照。名稱與類型來自訂單當時資料，服務之後刪除或封存仍會列入。類型：時間加購、加值服務、客製服務、每日分時段服務。',
              ),
              ReportStatusBody(
                snapshot: snap,
                builder: () {
                  final List<AddonRow> rows = _sorted(snap.data!.addons);
                  final int purchases = rows.fold<int>(
                    0,
                    (int s, AddonRow e) => s + e.purchaseCount,
                  );
                  final int revenue = rows.fold<int>(
                    0,
                    (int s, AddonRow e) => s + e.revenue,
                  );
                  return Column(
                    children: <Widget>[
                      ReportKpiGrid(
                        items: <ReportKpiItem>[
                          ReportKpiItem(
                            label: '被購買次數',
                            value: ShopReportFormat.number(purchases),
                          ),
                          ReportKpiItem(
                            label: '加購收入',
                            value: ShopReportFormat.money(revenue),
                          ),
                          ReportKpiItem(
                            label: '服務項目',
                            value: ShopReportFormat.number(rows.length),
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
                        titleOf: (int i) => rows[i].name,
                        subtitleOf: (int i) => rows[i].typeLabel,
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
