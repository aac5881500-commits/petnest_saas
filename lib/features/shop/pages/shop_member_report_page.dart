// 檔案名稱：lib/features/shop/pages/shop_member_report_page.dart
// 功能說明：會員統計：店家後台可見的姓名 / 電話與消費摘要。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopMemberReportPage extends StatefulWidget {
  const ShopMemberReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopMemberReportPage> createState() => _ShopMemberReportPageState();
}

class _ShopMemberReportPageState extends State<ShopMemberReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late Future<ShopReportBundle> _future;
  String _sortId = 'spend';
  bool _sortAsc = false;
  String _keyword = '';

  static const List<ReportColumn> _columns = <ReportColumn>[
    ReportColumn(id: 'name', label: '會員姓名'),
    ReportColumn(id: 'phone', label: '電話'),
    ReportColumn(id: 'first', label: '首次訂單日'),
    ReportColumn(id: 'last', label: '最近訂單日'),
    ReportColumn(id: 'orders', label: '完成訂單數', numeric: true),
    ReportColumn(id: 'spend', label: '累積消費', money: true),
    ReportColumn(id: 'avg', label: '平均客單', money: true),
    ReportColumn(id: 'd30', label: '近 30 天'),
    ReportColumn(id: 'd90', label: '近 90 天'),
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
      includeMembers: true,
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

  List<MemberRow> _sorted(List<MemberRow> rows) {
    final String q = _keyword.trim().toLowerCase();
    final List<MemberRow> filtered = q.isEmpty
        ? List<MemberRow>.from(rows)
        : rows
              .where(
                (MemberRow e) =>
                    e.name.toLowerCase().contains(q) || e.phone.contains(q),
              )
              .toList();
    filtered.sort((MemberRow a, MemberRow b) {
      final int c = ShopReportFormat.compare(_key(a), _key(b));
      return _sortAsc ? c : -c;
    });
    return filtered;
  }

  dynamic _key(MemberRow row) {
    switch (_sortId) {
      case 'name':
        return row.name;
      case 'phone':
        return row.phone;
      case 'first':
        return row.firstOrderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      case 'last':
        return row.lastOrderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      case 'orders':
        return row.completedOrders;
      case 'avg':
        return row.averageSpend;
      case 'd30':
        return row.spentLast30 ? 1 : 0;
      case 'd90':
        return row.spentLast90 ? 1 : 0;
      case 'spend':
      default:
        return row.spend;
    }
  }

  String _value(MemberRow row, String id) {
    switch (id) {
      case 'name':
        return row.name;
      case 'phone':
        return row.phone.isEmpty ? '—' : row.phone;
      case 'first':
        return row.firstOrderAt == null
            ? '—'
            : ShopReportFormat.date.format(row.firstOrderAt!);
      case 'last':
        return row.lastOrderAt == null
            ? '—'
            : ShopReportFormat.date.format(row.lastOrderAt!);
      case 'orders':
        return ShopReportFormat.number(row.completedOrders);
      case 'spend':
        return ShopReportFormat.money(row.spend);
      case 'avg':
        return ShopReportFormat.money(row.averageSpend);
      case 'd30':
        return row.spentLast30 ? '有' : '無';
      case 'd90':
        return row.spentLast90 ? '有' : '無';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員統計報表')),
      body: FutureBuilder<ShopReportBundle>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ShopReportBundle> snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                '會員統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '會員人數、期間消費與回訪',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ReportRangeSelector(range: _range, onChanged: _setRange),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: '搜尋姓名或電話',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (String value) {
                  setState(() {
                    _keyword = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              const ReportNote(
                '會員總數為本店未封存會員。期間新增依會員建立時間。有消費會員：期間內至少 1 筆有效住宿訂單。回訪會員：期間開始前就已是會員且期間內有消費，或期間新會員有 2 筆以上有效訂單。只顯示後台會員列表本來就有的姓名與電話。',
              ),
              ReportStatusBody(
                snapshot: snap,
                builder: () {
                  final MemberKpi kpi = snap.data!.memberKpi;
                  final List<MemberRow> rows = _sorted(snap.data!.members);
                  return Column(
                    children: <Widget>[
                      ReportKpiGrid(
                        items: <ReportKpiItem>[
                          ReportKpiItem(
                            label: '會員總數',
                            value: ShopReportFormat.number(kpi.total),
                          ),
                          ReportKpiItem(
                            label: '期間新增',
                            value: ShopReportFormat.number(kpi.newInRange),
                          ),
                          ReportKpiItem(
                            label: '有消費會員',
                            value: ShopReportFormat.number(kpi.spending),
                          ),
                          ReportKpiItem(
                            label: '回訪會員',
                            value: ShopReportFormat.number(kpi.returning),
                          ),
                          ReportKpiItem(
                            label: 'VIP',
                            value: ShopReportFormat.number(kpi.vip),
                          ),
                          ReportKpiItem(
                            label: '黑名單',
                            value: ShopReportFormat.number(kpi.blacklisted),
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
                        subtitleOf: (int i) => rows[i].phone.isEmpty
                            ? '累積 ${ShopReportFormat.money(rows[i].spend)}'
                            : rows[i].phone,
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
