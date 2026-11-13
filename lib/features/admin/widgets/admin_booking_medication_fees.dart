import 'package:flutter/material.dart';
import '../../../core/models/booking_medication_task.dart';
import '../../medication/medication_task_page.dart';

import '../../../core/services/booking_settlement_math.dart';
import '../../medication/medication_widgets.dart' show medMap, medicationStates;

/// Display the recorded amounts; the booking settlement remains the source of truth.
class AdminBookingMedicationFees extends StatelessWidget {
  const AdminBookingMedicationFees({
    super.key,
    required this.booking,
    this.inFinance = false,
    this.canEdit = false,
    this.shopId = '',
    this.bookingId = '',
  });

  final Map<String, dynamic> booking;
  final bool inFinance, canEdit;
  final String shopId, bookingId;

  static bool hasFeeData(Map<String, dynamic> booking) =>
      medMap(booking['medication']).isNotEmpty ||
      medMap(booking['medicationRequest']).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final medication = medMap(booking['medication']);
    final state = '${medication['state'] ?? ''}';
    final inactive =
        const {'declined', 'cancelled'}.contains(state) ||
        booking['status'] == 'cancelled';
    final finalized = medication['finalized'] == true;
    final canRecord = inFinance && canEdit && shopId.isNotEmpty && bookingId.isNotEmpty &&
        BookingMedicationTask.canRecord(booking);
    final pending = canRecord
        ? BookingMedicationTask.fromBooking(booking).where((task) => task.pending).toList()
        : const <BookingMedicationTask>[];
    final estimate = medMap(medication['estimate'])['amount'];
    final agreed = medication['agreedAmount'];
    final finalAmount = medication['finalAmount'];
    final advance = BookingSettlementMath.advanceMedicationAmount(booking);
    final colors = Theme.of(context).colorScheme;
    final status = finalized ? '已確認最終費用' : medicationStates[state] ?? '待店家確認';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 19,
                  color: colors.primary,
                ),
                Text(
                  inFinance ? '用藥費與退房結算' : '用藥確認與費用',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (estimate is num) _amount('預估用藥費', estimate),
            if (agreed is num) _amount('店家提出的報價', agreed),
            if (advance > 0) _amount('已列入預約應付', advance),
            if (finalized && finalAmount is num) _amount('最終用藥費', finalAmount),
            if (finalized && finalAmount is num && advance > 0)
              _amount('用藥差額（併入整筆結算）', finalAmount - advance),
            if (pending.isNotEmpty) ...[
              const Divider(height: 24),
              Text('待補登用藥 · ${pending.length} 筆', style: Theme.of(context).textTheme.titleSmall),
              for (final task in pending)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text([task.pet, task.types].where((part) => part.isNotEmpty).join(' · ')),
                  subtitle: Text('${BookingMedicationTask.dateKey(BookingMedicationTask.taipei(task.scheduledAt))}  ${BookingMedicationTask.timeLabel(task.scheduledAt)}'),
                  trailing: const Icon(Icons.edit_note),
                  onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
                    builder: (_) => MedicationTaskPage(
                      shopId: shopId,
                      bookingId: bookingId,
                      taskId: task.id,
                      scheduledAt: task.scheduledAt.toIso8601String(),
                    ),
                  )),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              inactive
                  ? '此用藥協助未成立或已取消，請在帳務核對整筆應收及退款。'
                  : finalized
                  ? (finalAmount == 0
                        ? '最終用藥費為零。若預約時已列入用藥費，差額由整筆退房結算調整。'
                        : '最終用藥費已帶入退房結算。若預約時已列入用藥費，只核算差額。')
                  : state == 'pending_customer'
                  ? '等飼主同意時程與收費後才成立。退房前依執行結果確認最終用藥費。'
                  : state == 'confirmed'
                  ? '雙方已確認安排。記錄每次結果後，請在退房前確認最終用藥費。'
                  : '店家需先核對日期、時段、藥品、用量與收費，再送飼主確認。退房前依執行結果確認最終用藥費。',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, num amount) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Text(
          'NT\$ ${amount.toInt()}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
