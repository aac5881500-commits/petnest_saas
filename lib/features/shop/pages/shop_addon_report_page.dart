// lib/features/shop/pages/shop_addon_report_page.dart
// 🛒 加購服務統計報表
// 功能：統計各加購服務銷售次數與營收

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

class ShopAddonReportPage extends StatelessWidget {
  const ShopAddonReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('加購服務統計')),
      body: FutureBuilder<List<AddonReport>>(
        future: ShopReportService.instance.getAddonReports(shopId: shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          final totalSaleCount = reports.fold<int>(
            0,
            (sum, item) => sum + item.saleCount,
          );

          final totalRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.revenue,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '加購服務統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(
                '依加購服務統計銷售次數與營收',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: '銷售總次數',
                      value: '$totalSaleCount',
                      unit: '次',
                      icon: Icons.add_shopping_cart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: '加購營收',
                      value: '\$${moneyFormat.format(totalRevenue)}',
                      unit: '',
                      icon: Icons.attach_money,
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
                      DataColumn(label: Text('服務名稱')),
                      DataColumn(label: Text('類型')),
                      DataColumn(label: Text('銷售次數'), numeric: true),
                      DataColumn(label: Text('營收'), numeric: true),
                    ],
                    rows: [
                      ...reports.map((report) {
                        return DataRow(
                          cells: [
                            DataCell(Text(report.name)),
                            DataCell(Text(_typeLabel(report.type))),
                            DataCell(Text('${report.saleCount}')),
                            DataCell(
                              Text('\$${moneyFormat.format(report.revenue)}'),
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
                          const DataCell(Text('-')),
                          DataCell(
                            Text(
                              '$totalSaleCount',
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

  String _typeLabel(String type) {
    switch (type) {
      case 'time':
        return '時間加購';
      case 'value':
        return '加值服務';
      case 'custom':
        return '自訂服務';
      default:
        return '其他';
    }
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
              backgroundColor: Colors.purple.withOpacity(0.08),
              child: Icon(icon, color: Colors.purple),
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
