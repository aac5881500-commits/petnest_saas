// lib/features/shop/pages/shop_revenue_report_page.dart
// 💰 營收統計報表
// 功能：顯示每月訂單數、取消數、總營收與平均客單價

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

class ShopRevenueReportPage extends StatelessWidget {
  const ShopRevenueReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('營收統計報表')),
      body: FutureBuilder<List<MonthlyRevenueReport>>(
        future: ShopReportService.instance.getMonthlyRevenueReports(
          shopId: shopId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          final totalOrder = reports.fold<int>(
            0,
            (sum, item) => sum + item.orderCount,
          );

          final totalCancel = reports.fold<int>(
            0,
            (sum, item) => sum + item.cancelCount,
          );

          final totalRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.revenue,
          );

          final paidOrderCount = totalOrder - totalCancel;
          final averageOrderValue = paidOrderCount <= 0
              ? 0
              : (totalRevenue / paidOrderCount).round();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '月份營收統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(
                '依月份統計訂單、取消、營收與平均客單價',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: '總訂單',
                      value: '$totalOrder',
                      unit: '筆',
                      icon: Icons.receipt_long,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: '取消訂單',
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
                      title: '總營收',
                      value: '\$${moneyFormat.format(totalRevenue)}',
                      unit: '',
                      icon: Icons.attach_money,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: '平均客單價',
                      value: '\$${moneyFormat.format(averageOrderValue)}',
                      unit: '',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
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
                      DataColumn(label: Text('月份')),
                      DataColumn(label: Text('訂單數'), numeric: true),
                      DataColumn(label: Text('取消數'), numeric: true),
                      DataColumn(label: Text('總營收'), numeric: true),
                      DataColumn(label: Text('平均客單價'), numeric: true),
                    ],
                    rows: [
                      ...reports.map((report) {
                        return DataRow(
                          cells: [
                            DataCell(Text(report.month)),
                            DataCell(Text('${report.orderCount}')),
                            DataCell(Text('${report.cancelCount}')),
                            DataCell(
                              Text('\$${moneyFormat.format(report.revenue)}'),
                            ),
                            DataCell(
                              Text(
                                '\$${moneyFormat.format(report.averageOrderValue)}',
                              ),
                            ),
                          ],
                        );
                      }),

                      DataRow(
                        color: WidgetStatePropertyAll(Colors.grey.shade100),
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
                              '\$${moneyFormat.format(totalRevenue)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '\$${moneyFormat.format(averageOrderValue)}',
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
              backgroundColor: Colors.green.withOpacity(0.08),
              child: Icon(icon, color: Colors.green),
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
                      fontSize: 18,
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
