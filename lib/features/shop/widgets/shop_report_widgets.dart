// lib/features/shop/widgets/shop_report_widgets.dart
// 📊 報表共用：KPI、Loading / Error / 空資料、手機卡與寬版表格。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';

class ReportNote extends StatelessWidget {
  const ReportNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          height: 1.4,
        ),
      ),
    );
  }
}

class ReportKpiGrid extends StatelessWidget {
  const ReportKpiGrid({super.key, required this.items});

  final List<ReportKpiItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (BuildContext context, int i) {
            final ReportKpiItem item = items[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ReportKpiItem {
  const ReportKpiItem({required this.label, required this.value});

  final String label;
  final String value;
}

class ReportStatusBody extends StatelessWidget {
  const ReportStatusBody({
    super.key,
    required this.snapshot,
    required this.builder,
  });

  final AsyncSnapshot<dynamic> snapshot;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('讀取失敗：${snapshot.error}'),
      );
    }
    if (!snapshot.hasData) {
      return const ReportEmpty();
    }
    return builder();
  }
}

class ReportSectionLabel extends StatelessWidget {
  const ReportSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class ReportEmpty extends StatelessWidget {
  const ReportEmpty({super.key, this.text = '這個期間沒有資料'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }
}

class ReportColumn {
  const ReportColumn({
    required this.id,
    required this.label,
    this.numeric = false,
    this.money = false,
  });

  final String id;
  final String label;
  final bool numeric;
  final bool money;
}

class ReportResponsiveTable extends StatelessWidget {
  const ReportResponsiveTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.valueOf,
    required this.sortId,
    required this.sortAsc,
    required this.onSort,
    this.onRowTap,
    this.titleOf,
    this.subtitleOf,
  });

  final List<ReportColumn> columns;
  final int rowCount;
  final String Function(int row, String columnId) valueOf;
  final String sortId;
  final bool sortAsc;
  final void Function(String columnId) onSort;
  final ValueChanged<int>? onRowTap;
  final String Function(int row)? titleOf;
  final String Function(int row)? subtitleOf;

  @override
  Widget build(BuildContext context) {
    if (rowCount <= 0) {
      return const ReportEmpty();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth < 720) {
          return Column(
            children: List<Widget>.generate(rowCount, (int i) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: onRowTap == null ? null : () => onRowTap!(i),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          titleOf?.call(i) ?? valueOf(i, columns.first.id),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (subtitleOf != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitleOf!(i),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ...columns.skip(1).map((ReportColumn col) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    col.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Text(
                                  valueOf(i, col.id),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            sortColumnIndex: columns
                .indexWhere((ReportColumn c) => c.id == sortId)
                .clamp(0, columns.length - 1),
            sortAscending: sortAsc,
            columns: columns.map((ReportColumn col) {
              return DataColumn(
                label: Text(col.label),
                numeric: col.numeric || col.money,
                onSort: (_, _) => onSort(col.id),
              );
            }).toList(),
            rows: List<DataRow>.generate(rowCount, (int i) {
              return DataRow(
                onSelectChanged: onRowTap == null ? null : (_) => onRowTap!(i),
                cells: columns.map((ReportColumn col) {
                  return DataCell(Text(valueOf(i, col.id)));
                }).toList(),
              );
            }),
          ),
        );
      },
    );
  }
}

class ReportMoneyText {
  static String of(int amount) => ShopReportFormat.money(amount);
}
