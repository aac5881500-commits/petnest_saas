import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';

final _currency = NumberFormat('#,##0', 'zh_TW');
String ownerMoney(num value) => 'NT\$ ${_currency.format(value)}';

Map<String, int> ownerGroupAmounts(
  List<Map<String, dynamic>> entries,
  String kind,
) {
  final groups = <String, int>{};
  for (final entry in entries.where((e) => e['kind'] == kind)) {
    final name = (entry['name'] as String? ?? '').trim();
    groups.update(
      name,
      (v) => v + (entry['amount'] as num).toInt(),
      ifAbsent: () => (entry['amount'] as num).toInt(),
    );
  }
  return Map.fromEntries(
    groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );
}

class OwnerReportSection extends StatelessWidget {
  const OwnerReportSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}

/// The legend and accessible text share the exact values drawn on the ring.
class OwnerDonut extends StatefulWidget {
  const OwnerDonut({
    super.key,
    required this.title,
    required this.values,
    required this.caption,
  });
  final String title, caption;
  final Map<String, int> values;
  @override
  State<OwnerDonut> createState() => _OwnerDonutState();
}

class _OwnerDonutState extends State<OwnerDonut> {
  String? _selected;
  static const colors = [
    Color(0xff5368bd),
    Color(0xff32a898),
    Color(0xffe8ad55),
    Color(0xffb981b9),
    Color(0xff6e9bce),
    Color(0xffd47676),
    Color(0xff8d9b55),
    Color(0xff9b8ac6),
  ];
  @override
  Widget build(BuildContext context) {
    final entries = widget.values.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (v, e) => v + e.value);
    final selected = entries.where((e) => e.key == _selected).firstOrNull;
    return OwnerReportSection(
      title: widget.title,
      subtitle: widget.caption,
      child: total == 0
          ? const SizedBox(
              height: 160,
              child: Center(child: Text('本月尚無可繪製的金額資料')),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final ring = Semantics(
                  label: '${widget.title}，總計 ${ownerMoney(total)}',
                  child: SizedBox(
                    width: 210,
                    height: 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DonutPainter(
                              entries.map((e) => e.value).toList(),
                              colors,
                              entries.indexWhere((e) => e.key == _selected),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 126,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selected?.key ?? '合計',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                child: Text(
                                  ownerMoney(selected?.value ?? total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              if (selected != null)
                                Text(
                                  '${(selected.value / total * 100).toStringAsFixed(1)}%',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                final legend = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      InkWell(
                        onTap: () => setState(
                          () => _selected = _selected == entries[i].key
                              ? null
                              : entries[i].key,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entries[i].key)),
                              Text(
                                '${ownerMoney(entries[i].value)}  ·  ${(entries[i].value / total * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
                return box.maxWidth >= 520
                    ? Row(
                        children: [
                          ring,
                          const SizedBox(width: 28),
                          Expanded(child: legend),
                        ],
                      )
                    : Column(
                        children: [ring, const SizedBox(height: 16), legend],
                      );
              },
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.selected);
  final List<int> values;
  final List<Color> colors;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 17,
    );
    var angle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        angle,
        sweep > .025 ? sweep - .025 : sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = (i == selected ? 30 : 23),
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

class OwnerFinanceInsights extends StatelessWidget {
  const OwnerFinanceInsights({
    super.key,
    required this.report,
    required this.entries,
    required this.ledgerReady,
    required this.sections,
  });
  final ShopReportBundle report;
  final List<Map<String, dynamic>> entries;
  final bool ledgerReady;
  final Set<String> sections;
  @override
  Widget build(BuildContext context) {
    final k = report.revenueKpi;
    final salaries = ownerGroupAmounts(entries, 'salary');
    final expenses = ownerGroupAmounts(entries, 'expense');
    final payroll = salaries.values.fold<int>(0, (a, b) => a + b);
    final costs = payroll + expenses.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.contains('charts'))
          LayoutBuilder(
            builder: (context, box) {
              final income = OwnerDonut(
                title: '營收來源占比',
                caption: '系統有效訂單的住宿／日托、加購與商城原始組成，未扣折扣；不等於淨實收。點選圖例查看占比。',
                values: {
                  '住宿／日托': k.stayRevenue,
                  '加購服務': k.addonRevenue,
                  '商城商品': k.storeRevenue,
                },
              );
              final expense = ledgerReady
                  ? OwnerDonut(
                      title: '成本結構占比',
                      caption: '已填寫的薪資與各項支出；同名項目自動合併。點選圖例查看占比。',
                      values: {
                        '員工薪資': payroll,
                        for (final e in expenses.entries)
                          '支出・${e.key}': e.value,
                      },
                    )
                  : const OwnerReportSection(
                      title: '成本結構占比',
                      subtitle: '私人資料尚未載入',
                      child: Text('取得薪資與支出後才會繪製成本圓環圖。'),
                    );
              return box.maxWidth >= 1050
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: income),
                        const SizedBox(width: 12),
                        Expanded(child: expense),
                      ],
                    )
                  : Column(children: [income, expense]);
            },
          ),
        if (sections.contains('operations'))
          OwnerReportSection(
            title: '營運指標',
            subtitle: '依所選月份的既有訂單資料統計；取消率與客單價沿用營運報表口徑。',
            child: Wrap(
              spacing: 30,
              runSpacing: 20,
              children: [
                _stat('有效訂單', '${report.overview.orders} 筆'),
                _stat('住宿晚數', '${report.overview.nights} 晚'),
                _stat('服務寵物數', '${report.overview.pets} 隻'),
                _stat('平均訂單金額', ownerMoney(report.overview.averageOrderAmount)),
                _stat(
                  '取消率',
                  '${(report.overview.cancelRate * 100).toStringAsFixed(1)}%',
                ),
                _stat('折扣／優惠券', ownerMoney(k.discountAmount + k.couponAmount)),
                _stat('加價金額', ownerMoney(k.surchargeAmount)),
              ],
            ),
          ),
        if (sections.contains('daily'))
          OwnerReportSection(
            title: '每日收款與訂單',
            subtitle: '訂單按建立日；淨實收按付款日。可橫向捲動完整表格。',
            child: _table(
              ['日期', '訂單數', '訂單金額', '淨實收', '未收款', '退款'],
              report.revenueByDay
                  .where((r) => r.hasActivity)
                  .map(
                    (r) => [
                      r.label,
                      '${r.orderCount}',
                      ownerMoney(r.orderAmount),
                      ownerMoney(r.paidAmount),
                      ownerMoney(r.unpaidAmount),
                      ownerMoney(r.refundAmount),
                    ],
                  )
                  .toList(),
            ),
          ),
        if (sections.contains('salary') && ledgerReady)
          OwnerReportSection(
            title: '員工薪資明細',
            subtitle: '同名員工當月多筆金額合併。占比以已填薪資合計為分母，未包含未填項目。',
            child: _table(
              ['員工姓名', '本月薪資', '薪資占比'],
              salaries.entries
                  .map(
                    (e) => [
                      e.key,
                      ownerMoney(e.value),
                      '${(e.value / payroll * 100).toStringAsFixed(1)}%',
                    ],
                  )
                  .toList(),
            ),
          ),
        if (sections.contains('costs') && ledgerReady)
          OwnerReportSection(
            title: '成本與經營觀察',
            subtitle: '僅依本月已填收支，不自動推算尚未填寫的房租、稅金或其他成本。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 30,
                  runSpacing: 20,
                  children: [
                    _stat('已填薪資人數', '${salaries.length} 人'),
                    _stat(
                      '平均每人薪資',
                      salaries.isEmpty
                          ? '—'
                          : ownerMoney(payroll / salaries.length),
                    ),
                    _stat(
                      '薪資／系統淨實收',
                      k.paidAmount <= 0
                          ? '無法計算'
                          : '${(payroll / k.paidAmount * 100).toStringAsFixed(1)}%',
                    ),
                    _stat(
                      '已填成本／系統淨實收',
                      k.paidAmount <= 0
                          ? '無法計算'
                          : '${(costs / k.paidAmount * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (k.unpaidAmount > 0)
                  Text('待追蹤：系統未收款 ${ownerMoney(k.unpaidAmount)}，請回訂單明細核對催收。'),
                if (entries.isEmpty) const Text('尚未填寫成本，目前結餘不足以反映實際經營成果。'),
                if (costs > k.paidAmount)
                  const Text('已填支出超過系統淨實收，請一併核對其他收入與付款時點。'),
                const SizedBox(height: 12),
                _table(
                  ['支出項目', '本月金額', '占總成本'],
                  expenses.entries
                      .map(
                        (e) => [
                          e.key,
                          ownerMoney(e.value),
                          '${(e.value / costs * 100).toStringAsFixed(1)}%',
                        ],
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        if (sections.contains('ranking'))
          OwnerReportSection(
            title: '熱銷房型與加購',
            subtitle: '依所選月份的收入由高至低排列；不代表房間住房率。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _table(
                  ['房型', '訂單數', '晚數', '收入'],
                  (report.roomTypes.toList()
                        ..sort((a, b) => b.revenue.compareTo(a.revenue)))
                      .take(10)
                      .map(
                        (r) => [
                          r.roomTypeName,
                          '${r.orderCount}',
                          '${r.nights}',
                          ownerMoney(r.revenue),
                        ],
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _table(
                  ['加購項目', '購買次數', '數量', '收入'],
                  (report.addons.toList()
                        ..sort((a, b) => b.revenue.compareTo(a.revenue)))
                      .take(10)
                      .map(
                        (r) => [
                          r.name,
                          '${r.purchaseCount}',
                          '${r.quantity}',
                          ownerMoney(r.revenue),
                        ],
                      )
                      .toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(String name, String value) => SizedBox(
    width: 165,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  Widget _table(List<String> headers, List<List<String>> rows) => rows.isEmpty
      ? const Text('本月尚無資料')
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xfff2f4fb)),
            columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
            rows: rows
                .map(
                  (r) =>
                      DataRow(cells: r.map((c) => DataCell(Text(c))).toList()),
                )
                .toList(),
          ),
        );
}
