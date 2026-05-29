// lib/features/admin/widgets/admin_booking_note_section.dart
// 📝 後台訂單詳細頁：訂單備註區塊
// 功能：顯示訂單備註，沒有備註時顯示無備註

import 'package:flutter/material.dart';

class AdminBookingNoteSection extends StatelessWidget {
  const AdminBookingNoteSection({
    super.key,
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final note = (data['note'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        note.isEmpty ? '無備註' : note,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}