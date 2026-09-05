// 檔案名稱：lib/features/admin/widgets/admin_booking_extra_charge_section.dart
// 功能說明：顯示退房額外費用、備註與照片預覽
// 💸 後台訂單詳細頁：退房額外費用區塊

import 'package:flutter/material.dart';

class AdminBookingExtraChargeSection extends StatelessWidget {
  const AdminBookingExtraChargeSection({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final extraCharges = data['extraCharges'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: (extraCharges ?? []).isEmpty
          ? const Text('目前無額外費用', style: TextStyle(color: Colors.grey))
          : Column(
              children: List.generate((extraCharges as List).length, (index) {
                final item = extraCharges[index];
                final title = item['title'] ?? '額外費用';
                final amount = item['amount'] ?? 0;
                final note = item['note'] ?? '';
                final imageUrls = (item['imageUrls'] ?? []) as List;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'NT\$ $amount',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      if (note.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          note.toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],

                      if (imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(imageUrls.length, (imgIndex) {
                            final url = imageUrls[imgIndex].toString();

                            return GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  url,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
    );
  }
}
