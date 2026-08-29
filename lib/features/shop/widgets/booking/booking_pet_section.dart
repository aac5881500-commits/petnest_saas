// lib/features/shop/widgets/booking/booking_pet_section.dart
// 🔥 前台預約寵物選擇區塊：顯示我的寵物、新增寵物、選擇入住寵物

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';

class BookingPetSection extends StatefulWidget {
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
  State<BookingPetSection> createState() => _BookingPetSectionState();
}

class _BookingPetSectionState extends State<BookingPetSection> {
  late final Stream<List<Map<String, dynamic>>> _petsStream;

  @override
  void initState() {
    super.initState();
    _petsStream = PetService.instance.streamMyPets();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選擇入住寵物（已選 ${widget.selectedPetIds.length} 隻）',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _petsStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            final List<Map<String, dynamic>> allPets =
                snapshot.data ?? <Map<String, dynamic>>[];
            final bool isLimitReached = allPets.length >= 10;

            return Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLimitReached
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AddPetPage(),
                          ),
                        );
                      },
                child: Text(
                  isLimitReached ? '已達上限（10隻）' : '+ 新增寵物',
                  style: TextStyle(color: isLimitReached ? Colors.grey : null),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _petsStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final List<Map<String, dynamic>> allPets = snapshot.data!;
            final List<Map<String, dynamic>> pets = allPets.where((
              Map<String, dynamic> pet,
            ) {
              final String type = (pet['type'] ?? '').toString();
              final String species = (pet['species'] ?? '').toString();
              return type == 'cat' || species == 'cat';
            }).toList();

            widget.onPetsLoaded(pets);
            if (pets.isEmpty) {
              return const Text('尚未新增寵物');
            }

            return Wrap(
              spacing: 8,
              children: pets.map((Map<String, dynamic> pet) {
                final petId = pet['petId'];
                final bool selected = widget.selectedPetIds.contains(petId);

                return FilterChip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        (pet['photoUrl'] != null &&
                            pet['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(pet['photoUrl'])
                        : null,
                    child:
                        (pet['photoUrl'] == null ||
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
                  onSelected: (bool value) {
                    widget.onTogglePet(petId, value);
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
