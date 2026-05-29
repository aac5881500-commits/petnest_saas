// lib/features/booking/widgets/booking_detail/booking_detail_after_checkout_section.dart
// 🧾 客戶端訂單詳細頁：退房結算、訂單狀態、備註區塊

import 'package:flutter/material.dart';

class BookingDetailAfterCheckoutSection extends StatelessWidget {
  const BookingDetailAfterCheckoutSection({
    super.key,
    required this.data,
    required this.bookingStatus,
    required this.depositStatus,
    required this.formatDateTime,
  });

  final Map<String, dynamic> data;
  final String bookingStatus;
  final String depositStatus;
  final String? Function(dynamic value) formatDateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildExtraChargesSection(context),
        _buildStatusTimelineSection(),
        _sectionCard(title: '備註', children: [Text(data['note'] ?? '無')]),
      ],
    );
  }

  Widget _buildExtraChargesSection(BuildContext context) {
    final extraCharges = (data['extraCharges'] ?? []) as List;

    return _sectionCard(
      title: '退房結算明細',
      children: [
        if (extraCharges.isEmpty)
          const Text(
            '目前無額外費用',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),

        if (extraCharges.isNotEmpty)
          ...List.generate(extraCharges.length, (index) {
            final item = extraCharges[index];
            final title = item['title'] ?? '額外費用';
            final amount = item['amount'] ?? 0;
            final note = item['note'] ?? '';
            final imageUrls = (item['imageUrls'] ?? []) as List;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.shade100, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (note.toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  note,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        'NT\$ $amount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),

                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(color: Colors.red.shade100),
                    const SizedBox(height: 8),
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
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              url,
                              width: 96,
                              height: 96,
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
      ],
    );
  }

  Widget _buildStatusTimelineSection() {
    return _sectionCard(
      title: '訂單狀態',
      children: [
        _buildStatusStep(
          title: '已送出預約',
          active: true,
          time: formatDateTime(data['createdAt']),
        ),
        _buildStatusStep(
          title: depositStatus == 'pending' ? '訂金待店家確認' : '等待店家確認',
          active:
              bookingStatus == 'pending' ||
              bookingStatus == 'confirmed' ||
              bookingStatus == 'checked_in' ||
              bookingStatus == 'completed',
        ),
        _buildStatusStep(
          title: '店家已確認',
          active:
              bookingStatus == 'confirmed' ||
              bookingStatus == 'checked_in' ||
              bookingStatus == 'completed',
          time: formatDateTime(data['depositPaidAt'] ?? data['confirmedAt']),
        ),
        _buildStatusStep(
          title: '入住中',
          active: bookingStatus == 'checked_in' || bookingStatus == 'completed',
          time: formatDateTime(data['checkInAt']),
        ),
        _buildStatusStep(
          title: '已完成',
          active: bookingStatus == 'completed',
          time: formatDateTime(data['checkOutAt']),
          isLast: bookingStatus != 'cancelled',
        ),
        if (bookingStatus == 'cancelled')
          _buildStatusStep(
            title: '訂單已取消',
            active: true,
            time: formatDateTime(data['cancelledAt']),
            isLast: true,
          ),
      ],
    );
  }

  Widget _buildStatusStep({
    required String title,
    required bool active,
    String? time,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: active ? Colors.green : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: active
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: active
                            ? Colors.blue.shade800
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
