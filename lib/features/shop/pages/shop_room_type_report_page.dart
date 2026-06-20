// lib/features/shop/pages/shop_room_type_report_page.dart
// 🏠 房型統計報表
// 功能：統計各房型訂單數、有效訂單數、取消數與營收

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

class ShopRoomTypeReportPage extends StatelessWidget {
  const ShopRoomTypeReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('房型統計報表')),
      body: FutureBuilder<List<RoomTypeReport>>(
        future: ShopReportService.instance.getRoomTypeReports(shopId: shopId),
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
          final totalValid = reports.fold<int>(
            0,
            (sum, item) => sum + item.validOrderCount,
          );
          final totalCancel = reports.fold<int>(
            0,
            (sum, item) => sum + item.cancelCount,
          );
          final totalRevenue = reports.fold<int>(
            0,
            (sum, item) => sum + item.revenue,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '房型銷售統計',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(
                '依房型統計訂單、有效訂單、取消與營收',
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
                      title: '有效訂單',
                      value: '$totalValid',
                      unit: '筆',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: '取消訂單',
                      value: '$totalCancel',
                      unit: '筆',
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: '房型營收',
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
                      DataColumn(label: Text('房型')),
                      DataColumn(label: Text('訂單數'), numeric: true),
                      DataColumn(label: Text('有效訂單'), numeric: true),
                      DataColumn(label: Text('取消數'), numeric: true),
                      DataColumn(label: Text('營收'), numeric: true),
                    ],
                    rows: [
                      ...reports.map((report) {
                        return DataRow(
                          cells: [
                            DataCell(Text(report.roomTypeName)),
                            DataCell(Text('${report.orderCount}')),
                            DataCell(Text('${report.validOrderCount}')),
                            DataCell(Text('${report.cancelCount}')),
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
                              '$totalValid',
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
              backgroundColor: Colors.orange.withOpacity(0.08),
              child: Icon(icon, color: Colors.orange),
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
