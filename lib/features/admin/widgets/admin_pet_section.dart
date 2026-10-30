import 'package:petnest_saas/core/models/pet_species.dart';
// 檔案名稱：lib/features/admin/widgets/admin_pet_section.dart
// 功能說明：顯示會員寵物、勾選寵物、新增寵物（支援暫存會員）
// 🐾 後台新增訂單：寵物選擇區塊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPetSection extends StatelessWidget {
  const AdminPetSection({
    super.key,
    required this.shopId,
    required this.member,
    required this.selectedPetIds,
    required this.tempPets,
    required this.onCreatePet,
    required this.onTogglePet,
  });

  final String shopId;
  final Map<String, dynamic>? member;
  final Set<String> selectedPetIds;
  final List<Map<String, dynamic>> tempPets;

  final VoidCallback onCreatePet;

  final void Function({
    required String petId,
    required Map<String, dynamic> petData,
    required bool selected,
  })
  onTogglePet;

  @override
  Widget build(BuildContext context) {
    if (member == null) return const SizedBox();

    final userId = member!['userId']?.toString() ?? '';
    final isTempMember = member!['isTempAdminMember'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第二步：選擇入住貓咪',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 8),

        Text(
          '目前會員：${member!['name'] ?? '未填姓名'}',
          style: const TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCreatePet,
            icon: const Icon(Icons.add),
            label: const Text('新增寵物'),
          ),
        ),

        const SizedBox(height: 12),

        // ===== 暫存會員 =====
        if (isTempMember)
          Builder(
            builder: (context) {
              if (tempPets.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text('此會員目前沒有符合種類的貓咪，請先新增或補齊寵物種類。'),
                );
              }

              return Column(
                children: tempPets.where((p) => PetSpecies.of(p) == 'cat').map((
                  pet,
                ) {
                  final petId = pet['petId'].toString();

                  final isSelected = selectedPetIds.contains(petId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      secondary: const CircleAvatar(child: Icon(Icons.pets)),
                      title: Text(pet['name'] ?? '未命名寵物'),
                      subtitle: Text(
                        '${pet['type'] ?? '未填種類'}｜${PetSpecies.genderLabel(pet['gender'])}',
                      ),
                      onChanged: (value) {
                        onTogglePet(
                          petId: petId,
                          petData: pet,
                          selected: value == true,
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          )
        // ===== 正式會員 =====
        else
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .collection('members')
                .doc(userId)
                .collection('pets')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pets = snapshot.data!.docs
                  .where(
                    (d) =>
                        PetSpecies.of(d.data() as Map<String, dynamic>) ==
                        'cat',
                  )
                  .toList();

              if (pets.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text('此會員目前沒有符合種類的貓咪，請先新增或補齊寵物種類。'),
                );
              }

              return Column(
                children: pets.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final isSelected = selectedPetIds.contains(doc.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      secondary: const CircleAvatar(child: Icon(Icons.pets)),
                      title: Text(data['name'] ?? '未命名寵物'),
                      subtitle: Text(
                        '${data['type'] ?? '未填種類'}｜${PetSpecies.genderLabel(data['gender'])}',
                      ),
                      onChanged: (value) {
                        onTogglePet(
                          petId: doc.id,
                          petData: data,
                          selected: value == true,
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}
