// 檔案名稱：lib/features/shop/pages/shop_overview_report_page.dart
// 功能說明：營運總覽：快速看期間數字、熱門房型 / 加購、近 6 個月。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopOverviewReportPage extends StatefulWidget {
  const ShopOverviewReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopOverviewReportPage> createState() => _ShopOverviewReportPageState();
}

class _ShopOverviewReportPageState extends State<ShopOverviewReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late Future<ShopReportBundle> _future;

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
      includeTrend: true,
    );
  }

  void _setRange(ReportRange range) {
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('營運總覽')),
      body: FutureBuilder<ShopReportBundle>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ShopReportBundle> snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                '營運總覽',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '快速查看期間訂單、營收與熱門項目。預設本月。',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ReportRangeSelector(range: _range, onChanged: _setRange),
              const SizedBox(height: 8),
              const ReportNote(
                '訂單數依訂單建立時間。住宿營收只計確認 / 入住 / 完成，不含待確認與取消。已付款依 payments 成功付款時間（paidAt，沒有則用建立時間）。商城只計已付款之後的有效訂單，不含待付款與取消。',
              ),
              ReportStatusBody(
                snapshot: snap,
                builder: () {
                  final ShopReportBundle bundle = snap.data!;
                  final OverviewKpi kpi = bundle.overview;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ReportKpiGrid(
                        items: <ReportKpiItem>[
                          ReportKpiItem(
                            label: '訂單數',
                            value: ShopReportFormat.number(kpi.orders),
                          ),
                          ReportKpiItem(
                            label: '營收',
                            value: ShopReportFormat.money(kpi.orderAmount),
                          ),
                          ReportKpiItem(
                            label: '已付款',
                            value: ShopReportFormat.money(kpi.paidAmount),
                          ),
                          ReportKpiItem(
                            label: '住宿晚數',
                            value: ShopReportFormat.number(kpi.nights),
                          ),
                          ReportKpiItem(
                            label: '入住寵物數',
                            value: ShopReportFormat.number(kpi.pets),
                          ),
                          ReportKpiItem(
                            label: '平均客單',
                            value: ShopReportFormat.money(
                              kpi.averageOrderAmount,
                            ),
                          ),
                          ReportKpiItem(
                            label: '取消率',
                            value: ShopReportFormat.percent(kpi.cancelRate),
                          ),
                          ReportKpiItem(
                            label: '新會員數',
                            value: ShopReportFormat.number(kpi.newMembers),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '熱門房型 Top 5',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (bundle.topRooms.isEmpty)
                        const ReportEmpty(text: '這個期間沒有房型銷售')
                      else
                        ...bundle.topRooms.map(_namedCard),
                      const SizedBox(height: 16),
                      const Text(
                        '熱門加購 Top 5',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (bundle.topAddons.isEmpty)
                        const ReportEmpty(text: '這個期間沒有加購銷售')
                      else
                        ...bundle.topAddons.map(_namedCard),
                      const SizedBox(height: 16),
                      const Text(
                        '最近 6 個月',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const ReportNote('月份營收 = 該月建立的有效住宿訂單金額 + 有效商城訂單金額。'),
                      if (bundle.monthTrend.isEmpty)
                        const ReportEmpty()
                      else
                        Card(
                          child: Column(
                            children: bundle.monthTrend.map((
                              MonthTrendRow row,
                            ) {
                              return ListTile(
                                title: Text(row.month),
                                subtitle: Text(
                                  '訂單 ${ShopReportFormat.number(row.orderCount)} 筆',
                                ),
                                trailing: Text(
                                  ShopReportFormat.money(row.revenue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
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

  Widget _namedCard(NamedMoneyRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(row.name),
        subtitle: Text('${ShopReportFormat.number(row.count)} 筆'),
        trailing: Text(
          ShopReportFormat.money(row.revenue),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
