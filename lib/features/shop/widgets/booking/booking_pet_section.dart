// lib/features/shop/widgets/booking/booking_pet_section.dart
// 🔥 前台預約寵物選擇區塊：顯示我的寵物、新增寵物、選擇入住寵物

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';

class BookingPetSection extends StatelessWidget {
  const BookingPetSection({
    super.key,
    required this.selectedPetIds,
    required this.onPetsLoaded,
    required this.onTogglePet,
  });

  final List<String> selectedPetIds;
  final ValueChanged<List<Map<String, dynamic>>> onPetsLoaded;
  final void Function(String petId, bool selected) onTogglePet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選擇入住寵物（已選 ${selectedPetIds.length} 隻）',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: PetService.instance.streamMyPets(),
          builder: (context, snapshot) {
            final pets = snapshot.data ?? [];
            final isLimitReached = pets.length >= 5;

            return Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLimitReached
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddPetPage(),
                          ),
                        );
                      },
                child: Text(
                  isLimitReached ? '已達上限（5隻）' : '+ 新增寵物',
                  style: TextStyle(
                    color: isLimitReached ? Colors.grey : null,
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: PetService.instance.streamMyPets(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final pets = snapshot.data!;
            onPetsLoaded(pets);

            if (pets.isEmpty) {
              return const Text('尚未新增寵物');
            }

            return Wrap(
              spacing: 8,
              children: pets.map((pet) {
                final petId = pet['petId'];
                final selected = selectedPetIds.contains(petId);

                return FilterChip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (pet['photoUrl'] != null &&
                            pet['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(pet['photoUrl'])
                        : null,
                    child: (pet['photoUrl'] == null ||
                            pet['photoUrl'].toString().isEmpty)
                        ? const Icon(Icons.pets, size: 16)
                        : null,
                  ),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet['name'] ?? '未命名',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '性別：${pet['gender'] ?? '-'} ｜ 貓砂：${pet['litterType'] ?? '-'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  selected: selected,
                  onSelected: (value) {
                    onTogglePet(petId, value);
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}