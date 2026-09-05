// 檔案名稱：lib/features/shop/pages/shop_room_type_report_page.dart
// 功能說明：房型統計：以訂單 snapshot 的房型名稱統計，避免改名失真。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopRoomTypeReportPage extends StatefulWidget {
  const ShopRoomTypeReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopRoomTypeReportPage> createState() => _ShopRoomTypeReportPageState();
}

class _ShopRoomTypeReportPageState extends State<ShopRoomTypeReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late Future<ShopReportBundle> _future;
  String _sortId = 'revenue';
  bool _sortAsc = false;

  static const List<ReportColumn> _columns = <ReportColumn>[
    ReportColumn(id: 'name', label: '房型名稱'),
    ReportColumn(id: 'orders', label: '訂單數', numeric: true),
    ReportColumn(id: 'nights', label: '住宿晚數', numeric: true),
    ReportColumn(id: 'pets', label: '入住寵物數', numeric: true),
    ReportColumn(id: 'revenue', label: '房型收入', money: true),
    ReportColumn(id: 'avg', label: '平均每筆訂單收入', money: true),
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

  List<RoomTypeRow> _sorted(List<RoomTypeRow> rows) {
    final List<RoomTypeRow> copy = List<RoomTypeRow>.from(rows);
    copy.sort((RoomTypeRow a, RoomTypeRow b) {
      final int c = ShopReportFormat.compare(_key(a), _key(b));
      return _sortAsc ? c : -c;
    });
    return copy;
  }

  dynamic _key(RoomTypeRow row) {
    switch (_sortId) {
      case 'name':
        return row.roomTypeName;
      case 'orders':
        return row.orderCount;
      case 'nights':
        return row.nights;
      case 'pets':
        return row.pets;
      case 'avg':
        return row.averageOrderRevenue;
      case 'revenue':
      default:
        return row.revenue;
    }
  }

  String _value(RoomTypeRow row, String id) {
    switch (id) {
      case 'name':
        return row.roomTypeName;
      case 'orders':
        return ShopReportFormat.number(row.orderCount);
      case 'nights':
        return ShopReportFormat.number(row.nights);
      case 'pets':
        return ShopReportFormat.number(row.pets);
      case 'revenue':
        return ShopReportFormat.money(row.revenue);
      case 'avg':
        return ShopReportFormat.money(row.averageOrderRevenue);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房型統計報表')),
      body: FutureBuilder<ShopReportBundle>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ShopReportBundle> snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                '房型統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '依訂單當時保存的房型名稱統計',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ReportRangeSelector(range: _range, onChanged: _setRange),
              const SizedBox(height: 8),
              const ReportNote(
                '只統計期間內建立、且狀態為確認 / 入住 / 完成的住宿訂單。房型名稱優先用訂單 snapshot（roomTypeName），避免後台改名後舊單失真。房型收入 = 房費小計 + 特殊日期加價，不含加購。目前無法可靠取得「房間數 × 可售晚數」（含維修 / 停用），因此不顯示入住率。',
              ),
              ReportStatusBody(
                snapshot: snap,
                builder: () {
                  final List<RoomTypeRow> rows = _sorted(snap.data!.roomTypes);
                  final int orders = rows.fold<int>(
                    0,
                    (int s, RoomTypeRow e) => s + e.orderCount,
                  );
                  final int nights = rows.fold<int>(
                    0,
                    (int s, RoomTypeRow e) => s + e.nights,
                  );
                  final int revenue = rows.fold<int>(
                    0,
                    (int s, RoomTypeRow e) => s + e.revenue,
                  );
                  return Column(
                    children: <Widget>[
                      ReportKpiGrid(
                        items: <ReportKpiItem>[
                          ReportKpiItem(
                            label: '有效訂單',
                            value: ShopReportFormat.number(orders),
                          ),
                          ReportKpiItem(
                            label: '住宿晚數',
                            value: ShopReportFormat.number(nights),
                          ),
                          ReportKpiItem(
                            label: '房型收入',
                            value: ShopReportFormat.money(revenue),
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
                        titleOf: (int i) => rows[i].roomTypeName,
                        subtitleOf: (int i) =>
                            '${rows[i].orderCount} 筆　${ShopReportFormat.money(rows[i].revenue)}',
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
