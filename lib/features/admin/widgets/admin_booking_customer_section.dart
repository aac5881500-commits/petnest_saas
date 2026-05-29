// lib/features/admin/widgets/admin_booking_customer_section.dart
// 👤 後台訂單詳細頁：顧客資訊區塊
// 功能：顯示顧客資料與緊急聯絡人資料

import 'package:flutter/material.dart';

class AdminBookingCustomerSection extends StatelessWidget {
  const AdminBookingCustomerSection({
    super.key,
    required this.data,
    required this.emergency,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic> emergency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoItem('姓名', data['customerName']),
                    const SizedBox(height: 6),
                    _infoItem('地址', data['address']),
                  ],
                ),
              ),
              Expanded(child: _infoItem('電話', data['customerPhone'])),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _infoItem('緊急聯絡人', emergency['name'])),
              Expanded(child: _infoItem('緊急電話', emergency['phone'])),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _infoItem('關係', emergency['relation'])),
              Expanded(child: _infoItem('緊急地址', emergency['address'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value?.toString() ?? '-',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}