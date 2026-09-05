// 檔案名稱：lib/features/admin/widgets/admin_booking_date_section.dart
// 功能說明：顯示入住 / 退房日期，呼叫月曆選擇彈窗
// 📅 後台手動新增訂單：日期選擇區塊

import 'package:flutter/material.dart';

class AdminBookingDateSection extends StatelessWidget {
  const AdminBookingDateSection({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onOpenCalendar,
    required this.formatDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onOpenCalendar;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第三步：選擇日期',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 8),

        const Text(
          '使用前台同一套月曆，休假日、滿房、剩餘房數會一致。',
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onOpenCalendar,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              startDate == null || endDate == null
                  ? '選擇入住 / 退房日期'
                  : '${formatDate(startDate!)} ～ ${formatDate(endDate!)}',
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (startDate != null && endDate != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              '已選擇：${formatDate(startDate!)} ～ ${formatDate(endDate!)}，共 ${endDate!.difference(startDate!).inDays} 晚',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
