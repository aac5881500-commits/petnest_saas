// lib/features/admin/widgets/admin_booking_pet_card.dart
// 🐱 後台訂單詳細頁：寵物資訊卡片
// 功能：顯示寵物頭像、名字、年齡、品種、醫療狀態、客戶備註、員工備註、結紮狀態

import 'package:flutter/material.dart';

class AdminBookingPetCard extends StatelessWidget {
  const AdminBookingPetCard({super.key, required this.pet});

  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    final medical = pet['medicalStatus'] ?? '';
    final staffNote = pet['staffNote'] ?? '';
    final isNeutered = pet['isNeutered'] == true;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (pet['photoUrl'] != null && pet['photoUrl'] != '')
                ? NetworkImage(pet['photoUrl'])
                : null,
            child: (pet['photoUrl'] == null || pet['photoUrl'] == '')
                ? const Icon(Icons.pets)
                : null,
          ),

          const SizedBox(height: 6),

          Text(
            pet['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          if ((pet['age'] ?? '').toString().isNotEmpty)
            Text(
              pet['age'],
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),

          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              pet['breed'] ?? '',
              style: const TextStyle(fontSize: 11),
            ),
          ),

          const SizedBox(height: 4),

          if (medical.toString().isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, size: 14, color: Colors.red),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    medical,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          if ((pet['note'] ?? '').toString().isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📝 ', style: TextStyle(fontSize: 12)),
                Flexible(
                  child: Text(
                    '客戶：${pet['note']}',
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          if (staffNote.toString().isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📌 ', style: TextStyle(fontSize: 12)),
                Flexible(
                  child: Text(
                    '員工：$staffNote',
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 6),

          Text(
            isNeutered ? '已結紮' : '未結紮',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isNeutered ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
