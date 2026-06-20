// lib/features/shop/pages/shop_daily_report_page.dart
// 📅 日期統計報表
// 功能：顯示店家每日訂單數、取消數與營收統計，支援期間篩選

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';

class ShopDailyReportPage extends StatefulWidget {
  const ShopDailyReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopDailyReportPage> createState() => _ShopDailyReportPageState();
}

class _ShopDailyReportPageState extends State<ShopDailyReportPage> {
  ReportRange _range = ReportRange.thisMonth();

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('日期統計報表')),
      body: FutureBuilder<List<DailyShopReport>>(
        future: ShopReportService.instance.getDailyReports(
          shopId: widget.shopId,
          startDate: _range.startDate,
          endDate: _range.endDate,
        ),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? [];

          final totalOrder = reports.fold<int>(
            0,
            (sum, item) => sum + item.orderCount,
          );
          final totalCancel = reports.fold<int>(
            0,
            (sum, item) => sum + item.cancelCount,
          );
          final totalRoomRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.roomRevenue,
          );

          final totalDiscount = reports.fold<int>(
            0,
            (sum, item) => sum + item.discountAmount,
          );

          final totalAddonRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.addonRevenue,
          );

          final totalExtraChargeRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.extraChargeRevenue,
          );

          final totalFinalRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.finalRevenue,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '日期統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(
                '每日訂單、取消、營收統計',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 12),

              ReportRangeSelector(
                range: _range,
                onChanged: (value) {
                  setState(() {
                    _range = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Center(child: Text('讀取失敗：${snapshot.error}'))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: '訂單總數',
                        value: '$totalOrder',
                        unit: '筆',
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: '取消總數',
                        value: '$totalCancel',
                        unit: '筆',
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: '房費',
                        value: '\$${moneyFormat.format(totalRoomRevenue)}',
                        unit: '',
                        icon: Icons.home_work,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: '折扣',
                        value: '-\$${moneyFormat.format(totalDiscount)}',
                        unit: '',
                        icon: Icons.discount,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: '加購',
                        value: '\$${moneyFormat.format(totalAddonRevenue)}',
                        unit: '',
                        icon: Icons.add_box,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: '額外收費',
                        value:
                            '\$${moneyFormat.format(totalExtraChargeRevenue)}',
                        unit: '',
                        icon: Icons.cleaning_services,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                _SummaryCard(
                  title: '實收總額',
                  value: '\$${moneyFormat.format(totalFinalRevenue)}',
                  unit: '',
                  icon: Icons.attach_money,
                ),

                const SizedBox(height: 16),

                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        Colors.grey.shade100,
                      ),
                      columns: const [
                        DataColumn(label: Text('日期')),
                        DataColumn(label: Text('訂單數'), numeric: true),
                        DataColumn(label: Text('取消數'), numeric: true),
                        DataColumn(label: Text('房費'), numeric: true),
                        DataColumn(label: Text('折扣'), numeric: true),
                        DataColumn(label: Text('加購'), numeric: true),
                        DataColumn(label: Text('額外收費'), numeric: true),
                        DataColumn(label: Text('實收總額'), numeric: true),
                      ],
                      rows: [
                        ...reports.map((report) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat('yyyy/MM/dd').format(report.date),
                                ),
                              ),
                              DataCell(Text('${report.orderCount}')),
                              DataCell(Text('${report.cancelCount}')),
                              DataCell(
                                Text(
                                  '\$${moneyFormat.format(report.roomRevenue)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '-\$${moneyFormat.format(report.discountAmount)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${moneyFormat.format(report.addonRevenue)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${moneyFormat.format(report.extraChargeRevenue)}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${moneyFormat.format(report.finalRevenue)}',
                                ),
                              ),
                            ],
                          );
                        }),
                        DataRow(
                          cells: [
                            const DataCell(
                              Text(
                                '總計',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataCell(
                              Text(
                                '$totalOrder',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            DataCell(
                              Text(
                                '$totalCancel',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            DataCell(
                              Text(
                                '\$${moneyFormat.format(totalRoomRevenue)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            DataCell(
                              Text(
                                '-\$${moneyFormat.format(totalDiscount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            DataCell(
                              Text(
                                '\$${moneyFormat.format(totalAddonRevenue)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            DataCell(
                              Text(
                                '\$${moneyFormat.format(totalExtraChargeRevenue)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            DataCell(
                              Text(
                                '\$${moneyFormat.format(totalFinalRevenue)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.08),
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    '$value$unit',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
