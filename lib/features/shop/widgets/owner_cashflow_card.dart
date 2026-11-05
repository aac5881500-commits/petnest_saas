import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/owner_cashflow_totals.dart';
import 'owner_finance_widgets.dart';

class OwnerCashflowCard extends StatelessWidget {
  const OwnerCashflowCard({
    super.key,
    required this.totals,
    required this.complete,
    required this.privateReady,
  });
  final OwnerCashflowTotals totals;
  final bool complete, privateReady;
  @override
  Widget build(BuildContext context) => OwnerReportSection(
    title: '整店收支總結',
    subtitle: privateReady
        ? (complete
              ? '整店總收入－員工薪資－其他支出＝本月結餘。系統收入採已反映退款的淨實收。'
              : '目前僅含可統計來源，部分服務項目尚未提供統計；下列為已知資料小計。')
        : '私人收支尚未載入，暫不計算總收入、總支出與結餘。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (privateReady) ...[
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth < 600
                  ? box.maxWidth
                  : (box.maxWidth - 24) / 3;
              Widget tile(
                String title,
                int value,
                Color color, {
                int direction = 0,
              }) => Container(
                width: width,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .07),
                  border: Border.all(color: color.withValues(alpha: .2)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ownerSignedMoney(
                          value,
                          direction: direction,
                          forceSign: true,
                        ),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  tile(
                    complete ? '整店總收入' : '已知收入小計',
                    totals.totalIncome,
                    const Color(0xff197b58),
                    direction: 1,
                  ),
                  tile(
                    '支出總計（含薪資）',
                    totals.totalExpense,
                    const Color(0xffb34c43),
                    direction: -1,
                  ),
                  tile(
                    complete ? '本月結餘' : '已知資料結餘（非完整）',
                    totals.balance,
                    totals.balance < 0
                        ? const Color(0xffb34c43)
                        : const Color(0xff375cad),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
        ],
        _row('系統實收收入（已反映退款）', totals.systemIncome, 1),
        if (privateReady) ...[
          _row('加：手動其他收入', totals.otherIncome, 1),
          _row('減：員工薪資', totals.salary, -1),
          _row('減：其他支出', totals.otherExpense, -1),
          const Divider(),
          _row(complete ? '收支結餘' : '已知資料結餘', totals.balance, 0, strong: true),
          const SizedBox(height: 10),
          Text(
            '${ownerMoney(totals.systemIncome)} ＋ ${ownerMoney(totals.otherIncome)} － ${ownerMoney(totals.salary)} － ${ownerMoney(totals.otherExpense)} ＝ ${ownerSignedMoney(totals.balance)}',
          ),
          const SizedBox(height: 6),
          const Text(
            '支出總計已含薪資，不會再扣一次。尚未填寫的成本不自動估算；此為收支結餘，非會計淨利。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    ),
  );
  Widget _row(String title, int value, int direction, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                ownerSignedMoney(value, direction: direction, forceSign: true),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.bold : FontWeight.w500,
                  color: (direction < 0 || (direction == 0 && value < 0))
                      ? const Color(0xffb34c43)
                      : const Color(0xff197b58),
                ),
              ),
            ),
          ],
        ),
      );
}
