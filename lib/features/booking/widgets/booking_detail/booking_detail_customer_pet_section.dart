// lib/features/booking/widgets/booking_detail/booking_detail_customer_pet_section.dart
// 👤🐾 客戶端訂單詳細頁：顧客與寵物資訊區塊
// 功能：顯示顧客姓名、電話、地址與寵物照片列表

import 'package:flutter/material.dart';

class BookingDetailCustomerPetSection extends StatelessWidget {
  const BookingDetailCustomerPetSection({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pets = (data['pets'] ?? []) as List;

    return Column(children: [_buildCustomerCard(), _buildPetCard(pets)]);
  }

  Widget _buildCustomerCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '顧客資訊',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data['customerName'] ?? '-',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      data['customerPhone'] ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data['address'] ?? '未填寫地址',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ),
          if (data['emergencyContact'] is Map) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '緊急聯絡人：${(data['emergencyContact']['name'] ?? '-')}　${data['emergencyContact']['phone'] ?? ''}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if ((data['emergencyContact']['relation'] ?? '')
                .toString()
                .trim()
                .isNotEmpty)
              Text(
                '關係：${data['emergencyContact']['relation']}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPetCard(List pets) {
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
            '寵物資訊 (${pets.length}隻)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final pet = pets[index];

              final image =
                  pet['imageUrl'] ?? pet['photoUrl'] ?? pet['image'] ?? '';

              final name = pet['name'] ?? '';

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFF), Color(0xFFEFF3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          color: Colors.grey.shade100,
                          child: image.toString().isNotEmpty
                              ? Image.network(image, fit: BoxFit.cover)
                              : const Icon(
                                  Icons.pets,
                                  size: 36,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
