// 檔案名稱：lib/features/admin/widgets/admin_booking_note_section.dart
// 功能說明：顯示並可編輯客戶備註（僅該筆訂單），留下操作紀錄。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';

class AdminBookingNoteSection extends StatelessWidget {
  const AdminBookingNoteSection({
    super.key,
    required this.data,
    required this.shopId,
    required this.bookingId,
  });

  final Map<String, dynamic> data;
  final String shopId;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final note = (data['note'] ?? '').toString().trim();
    final String source = (data['adminOrderSource'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '下單方式：$source',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            note.isEmpty ? '無備註' : note,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          if (!BookingSettlementMath.isSettlementLocked(data))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _edit(context, note),
                child: const Text('編輯'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, String current) async {
    final TextEditingController controller = TextEditingController(
      text: current,
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('編輯客戶備註'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '客戶交代內容'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    if (ok != true) {
      return;
    }
    final String next = controller.text.trim();
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update(<String, dynamic>{
          'note': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    final User? user = FirebaseAuth.instance.currentUser;
    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'booking',
      targetId: bookingId,
      action: 'customer_note_updated',
      operatorUid: user?.uid ?? '',
      operatorRole: 'staff',
      payload: <String, dynamic>{
        'before': current,
        'after': next,
        'operatorEmail': (user?.email ?? '').trim(),
      },
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('客戶備註已更新')));
    }
  }
}
