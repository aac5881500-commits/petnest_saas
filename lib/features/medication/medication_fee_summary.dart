import '../../core/services/booking_settlement_math.dart';
import 'package:flutter/material.dart';

class MedicationFeeSummary extends StatefulWidget {
  const MedicationFeeSummary({
    super.key,
    required this.medication,
    required this.loadPreview,
    this.booking,
  });
  final Map<String, dynamic> medication;
  final Map<String, dynamic>? booking;
  final Future<Map<String, dynamic>> Function() loadPreview;
  @override
  State<MedicationFeeSummary> createState() => _MedicationFeeSummaryState();
}

class _MedicationFeeSummaryState extends State<MedicationFeeSummary> {
  late Future<Map<String, dynamic>>? preview = canPreview
      ? widget.loadPreview()
      : null;
  bool get pending =>
      (widget.medication['tasks'] as List? ?? []).whereType<Map>().any(
        (t) =>
            t['finished'] != true &&
            ['pending', 'mixed', 'partial'].contains(t['result']),
      );
  bool get canPreview => !pending && widget.medication['finalized'] != true;
  Widget orderSummary(int amount) {
    final booking = widget.booking!;
    final extras = [
      for (final entry in (booking['extraCharges'] as List? ?? []))
        if (entry is Map && entry['id'] != 'medication') entry,
    ];
    if (amount > 0) extras.add({'id': 'medication', 'amount': amount});
    final projected = {
      ...booking,
      'extraCharges': extras,
      'medication': {
        ...widget.medication,
        'finalized': true,
        'finalAmount': amount,
      },
    };
    final total = BookingSettlementMath.expectedTotal(data: projected);
    final due = BookingSettlementMath.remainingDue(data: projected);
    final refund = BookingSettlementMath.refundDue(data: projected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text(
          '整張訂單試算：NT\$ $total',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text('已收款：NT\$ ${BookingSettlementMath.paidAmount(projected)}'),
        Text(
          refund > 0 ? '預計應退：NT\$ $refund' : '預計還需收：NT\$ $due',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const Text('尚未結算入帳，最後以退房確認金額為準。', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: preview,
        builder: (context, snapshot) {
          final m = widget.medication;
          final finalized = m['finalized'] == true;
          final amount = finalized
              ? m['finalAmount']
              : snapshot.data?['amount'];
          final advance = (m['advanceAmount'] as num?)?.toInt() ?? 0;
          final original = m['estimate'] is Map
              ? (m['estimate'] as Map)['amount']
              : null;
          final agreed = m['agreedAmount'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                finalized ? '最終用藥費' : '依執行結果試算',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (amount is num)
                Text(
                  'NT\$ ${amount.toInt()}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else if (pending)
                const Text(
                  '待補齊結果',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                )
              else if (snapshot.hasError)
                const Text('試算未完成，請重試')
              else if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else
                Text(agreed is num ? '議定上限 NT\$ $agreed' : '需確認報價'),
              if (!finalized && amount is num)
                Text('${snapshot.data?['units'] ?? 0} 個計費單位・確認後帶入退房結算'),
              if (pending) const Text('尚有用藥未補登，不把預列費當成最終收費。'),
              if (snapshot.hasError)
                TextButton(
                  onPressed: () =>
                      setState(() => preview = widget.loadPreview()),
                  child: const Text('重新試算'),
                ),
              const Divider(height: 24),
              Text('原預估用藥費：${original is num ? 'NT\$ $original' : '待報價'}'),
              Text('預約應付已列入：NT\$ $advance'),
              if (amount is num)
                Text(
                  '用藥費差額：${amount - advance > 0 ? '+' : ''}NT\$ ${amount.toInt() - advance}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 6),
              if (amount is num && widget.booking != null)
                orderSummary(amount.toInt()),
              const Text(
                '此處僅為用藥費；已列入金額會由最終費用替代，整張訂單補收／退款請看退房結算。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    ),
  );
}
