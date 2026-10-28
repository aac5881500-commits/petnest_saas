import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/report_table_spec.dart';

/// One renderer for every preset, custom view and export preview.
class ReportDataGrid extends StatefulWidget {
  const ReportDataGrid({
    super.key,
    required this.spec,
    required this.rows,
    required this.sortId,
    required this.ascending,
    required this.onSort,
    this.rowsPerPage = 25,
  });
  final ReportTableSpec spec;
  final List<Map<String, Object?>> rows;
  final String sortId;
  final bool ascending;
  final ValueChanged<String> onSort;
  final int rowsPerPage;
  @override
  State<ReportDataGrid> createState() => _ReportDataGridState();
}

class _ReportDataGridState extends State<ReportDataGrid> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  int _page = 0;
  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReportDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows ||
        oldWidget.spec.kind != widget.spec.kind) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.spec.visibleFields;
    final pages = (widget.rows.length / widget.rowsPerPage).ceil().clamp(
      1,
      100000,
    );
    final page = _page.clamp(0, pages - 1);
    final visible = widget.rows
        .skip(page * widget.rowsPerPage)
        .take(widget.rowsPerPage)
        .toList();
    if (fields.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('請選擇至少一個可用欄位。'),
      );
    }
    if (widget.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.table_chart_outlined, size: 36),
            SizedBox(height: 12),
            Text('沒有符合條件的資料；可調整日期、資料來源或清除搜尋。', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '表格可左右捲動；點欄位標題可排序。',
            style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
        ),
        Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height * .55).clamp(
                  300.0,
                  650.0,
                ),
              ),
              child: SingleChildScrollView(
                controller: _vertical,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xFFEDF2FA),
                  ),
                  headingTextStyle: const TextStyle(
                    color: Color(0xFF33466D),
                    fontWeight: FontWeight.w800,
                  ),
                  dataRowMinHeight: widget.spec.compact ? 36 : 48,
                  dataRowMaxHeight: widget.spec.compact ? 40 : 56,
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  sortAscending: widget.ascending,
                  sortColumnIndex:
                      fields.indexWhere((f) => f.id == widget.sortId) < 0
                      ? null
                      : fields.indexWhere((f) => f.id == widget.sortId),
                  columns: [
                    for (final field in fields)
                      DataColumn(
                        label: Text(field.label),
                        numeric: field.isNumeric,
                        onSort: (columnIndex, ascending) =>
                            widget.onSort(field.id),
                      ),
                  ],
                  rows: [
                    for (var i = 0; i < visible.length; i++)
                      DataRow(
                        color: WidgetStatePropertyAll(
                          i.isEven ? Colors.white : const Color(0xFFF8FAFD),
                        ),
                        cells: [
                          for (final field in fields)
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: SelectableText(
                                  ReportDataset.display(
                                    visible[i][field.id],
                                    field,
                                  ),
                                  maxLines: widget.spec.compact ? 1 : 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    DataRow(
                      color: const WidgetStatePropertyAll(Color(0xFFEAF0FA)),
                      cells: [
                        for (var i = 0; i < fields.length; i++)
                          DataCell(
                            Text(
                              fields[i].total
                                  ? ReportDataset.display(
                                      widget.rows.fold<num>(
                                        0,
                                        (sum, row) =>
                                            sum +
                                            (row[fields[i].id] is num
                                                ? row[fields[i].id] as num
                                                : 0),
                                      ),
                                      fields[i],
                                    )
                                  : i == 0
                                  ? '篩選後合計'
                                  : '—',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '共 ${widget.rows.length} 筆 · 第 ${page + 1} / $pages 頁',
              style: const TextStyle(fontSize: 12),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '上一頁',
                  onPressed: page > 0
                      ? () => setState(() => _page = page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '下一頁',
                  onPressed: page + 1 < pages
                      ? () => setState(() => _page = page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
