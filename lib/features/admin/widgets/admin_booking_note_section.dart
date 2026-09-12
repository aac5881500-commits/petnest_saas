// 檔案名稱：lib/features/admin/widgets/admin_booking_note_section.dart
// 功能說明：店家後台顯示客戶備註（唯讀，不提供編輯）。

import 'package:flutter/material.dart';

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
        ],
      ),
    );
  }
}
