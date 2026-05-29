// lib/features/booking/widgets/booking_detail/booking_detail_price_section.dart
// 💰 客戶端訂單詳細頁：價格與加值服務區塊
// 功能：顯示房費、寵物加價、加值服務、總金額與訂金

import 'package:flutter/material.dart';

class BookingDetailPriceSection extends StatelessWidget {
  const BookingDetailPriceSection({
    super.key,
    required this.data,
    required this.basePrice,
    required this.nights,
    required this.extraPetPrice,
    required this.extraPetCount,
    required this.roomPriceTotal,
    required this.petPriceTotal,
    required this.correctSubtotal,
    required this.addonTotal,
    required this.finalTotal,
  });

  final Map<String, dynamic> data;
  final dynamic basePrice;
  final dynamic nights;
  final dynamic extraPetPrice;
  final dynamic extraPetCount;
  final dynamic roomPriceTotal;
  final dynamic petPriceTotal;
  final dynamic correctSubtotal;
  final int addonTotal;
  final dynamic finalTotal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('房費'),
                  Text(
                    '$basePrice × $nights 晚',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'NT\$ $roomPriceTotal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('寵物加價'),
                  Text(
                    extraPetCount > 0
                        ? '$extraPetPrice × $extraPetCount 隻 × $nights 晚'
                        : '-',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'NT\$ $petPriceTotal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '小計',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'NT\$ $correctSubtotal',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if ((data['addons'] ?? []).isNotEmpty)
          _sectionCard(
            title: '加值服務',
            children: [
              ...List.generate((data['addons'] as List).length, (index) {
                final item = data['addons'][index];
                final pets = (data['pets'] ?? []) as List;
                final petIds = (item['petNames'] ?? []) as List;

                final petNames = petIds
                    .map((id) {
                      final match = pets
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (p) => p?['name'] == id || p?['petId'] == id,
                            orElse: () => null,
                          );
                      return match != null ? match['name'] : id;
                    })
                    .where((e) => e != null && e.toString().isNotEmpty)
                    .toList();

                final price = (item['price'] ?? 0) as num;
                final count = (item['count'] ?? 1) as num;
                final total = (item['total'] ?? (price * count)) as num;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '+ NT\$ ${total.toInt()}',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      if (count > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${price.toInt()} x ${count.toInt()} = ${total.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      if (petNames.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '👉 ${petNames.join('、')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              const Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '加值服務小計',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'NT\$ $addonTotal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('總金額', style: TextStyle(color: Colors.white70)),
                  Text(
                    'NT\$ $finalTotal',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('需支付訂金', style: TextStyle(color: Colors.white70)),
                  Text(
                    'NT\$ ${data['depositAmount'] ?? 0}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (data['depositStatus'] == 'confirmed')
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
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
