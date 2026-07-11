// lib/features/admin/widgets/admin_booking_pet_card.dart
// 🐱 後台訂單詳細頁：寵物資訊卡片
// 功能：顯示寵物頭像、名字、種類、性別、年齡、品種、醫療狀態、貓砂、客戶備註、員工備註、結紮狀態

import 'package:flutter/material.dart';

class AdminBookingPetCard extends StatelessWidget {
  const AdminBookingPetCard({super.key, required this.pet});

  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    final name = (pet['name'] ?? '').toString();
    final photoUrl = (pet['photoUrl'] ?? pet['imageUrl'] ?? '').toString();

    final type = (pet['type'] ?? '').toString();
    final gender = (pet['gender'] ?? '').toString();
    final breed = (pet['breed'] ?? '').toString();
    final age = (pet['age'] ?? '').toString();

    final medical = (pet['medicalStatus'] ?? pet['vaccine'] ?? '').toString();
    final litterType = (pet['litterType'] ?? '').toString();
    final note = (pet['note'] ?? '').toString();
    final staffNote = (pet['staffNote'] ?? '').toString();
    final isNeutered = pet['isNeutered'] == true;

    return Container(
      width: 290,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty ? const Icon(Icons.pets) : null,
          ),

          const SizedBox(height: 8),

          Text(
            name.isEmpty ? '未命名寵物' : name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          if (age.isNotEmpty)
            Text(age, style: const TextStyle(fontSize: 11, color: Colors.grey)),

          const SizedBox(height: 10),

          _infoRow('種類', type),
          _infoRow('性別', gender),
          _infoRow('品種', breed),
          _infoRow('結紮', isNeutered ? '已結紮' : '未結紮'),
          _infoRow('疫苗', medical),
          _infoRow('貓砂', litterType),
          if (note.isNotEmpty) _infoRow('客戶備註', note),
          if (staffNote.isNotEmpty)
            _infoRow('員工備註', staffNote, color: Colors.red),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    final text = value.trim().isEmpty ? '未填' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label：',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
