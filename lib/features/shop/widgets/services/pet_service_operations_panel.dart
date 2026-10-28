import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/core/models/pet_service_workflow.dart';

class PetServiceOperationsPanel extends StatelessWidget {
  const PetServiceOperationsPanel({
    super.key,
    required this.module,
    required this.rows,
    required this.onOpen,
    required this.onFilter,
    this.loading = false,
    this.failed = false,
    this.showMetrics = true,
    this.showHeading = true,
    this.maxUpcoming = 5,
  });
  final PetServiceModule module;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final void Function(String) onFilter;
  final bool loading, failed, showMetrics, showHeading;
  final int maxUpcoming;
  @override
  Widget build(BuildContext context) {
    final today = serviceDate(serviceTaipeiNow());
    final pending = rows.where((e) => e['status'] == 'pending').length;
    final committed = rows
        .where(
          (e) =>
              ['confirmed', 'arrived'].contains(e['status']) &&
              petRequestOnDate(e, today),
        )
        .length;
    final active = rows.where((e) => e['status'] == 'arrived').length;
    final upcoming = petServiceUpcoming(rows, today).take(maxUpcoming).toList();
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (failed)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('預約暫時無法讀取，工作數量尚未取得。'),
          ),
        if (showMetrics)
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [
                  ('待確認', pending, 'pending', Icons.inbox_outlined),
                  (
                    module.isDog ? '今日接待' : '今日已排程',
                    committed,
                    'today',
                    Icons.today_outlined,
                  ),
                  (
                    module.isDog
                        ? '入住／安親中'
                        : module.isHospital
                        ? '門診處理中'
                        : '美容服務中',
                    active,
                    'arrived',
                    Icons.timelapse,
                  ),
                ])
                  SizedBox(
                    width: box.maxWidth >= 620
                        ? (box.maxWidth - 24) / 3
                        : box.maxWidth,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onFilter(item.$3),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(item.$4, color: color),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.$1),
                                    Text(
                                      loading || failed ? '—' : '${item.$2}',
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (showMetrics) const SizedBox(height: 20),
        if (showHeading)
          const Text(
            '接下來的工作',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        if (showHeading) const SizedBox(height: 8),
        if (!loading && !failed && upcoming.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('目前沒有待處理預約，可先完善服務與人員設定。'),
          ),
        if (!failed)
          for (final row in upcoming)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(module.icon, size: 20)),
              title: Text('${row['petName']} · ${row['serviceName']}'),
              subtitle: Text(
                '${row['date']} ${row['time']} · ${row['staffName']}\n${petServiceStatus(module, '${row['status']}')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(row),
            ),
      ],
    );
  }
}
