// lib/features/shop/widgets/booking/booking_pet_section.dart
// 🔥 前台預約寵物選擇區塊：顯示我的寵物、新增寵物、選擇入住寵物

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class BookingPetSection extends StatefulWidget {
  const BookingPetSection({
    super.key,
    required this.selectedPetIds,
    required this.onPetsLoaded,
    required this.onTogglePet,
    this.theme = HomeThemeModel.classicDefault,
    this.title,
  });

  final List<String> selectedPetIds;
  final ValueChanged<List<Map<String, dynamic>>> onPetsLoaded;
  final void Function(String petId, bool selected) onTogglePet;
  final HomeThemeModel theme;
  final String? title;

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
    final HomeThemeModel theme = widget.theme;

    return BookingThemedCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.title ?? '選擇入住貓咪（已選 ${widget.selectedPetIds.length} 隻）',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '可複選，並可新增寵物資料。',
            style: TextStyle(
              fontSize: 12,
              color: theme.textColor.withValues(alpha: 0.7),
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _petsStream,
            builder:
                (
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
                        style: TextStyle(
                          fontSize: 14,
                          color: isLimitReached
                              ? theme.textColor.withValues(alpha: 0.4)
                              : theme.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _petsStream,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                ) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
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
                    return Text(
                      '尚未新增寵物',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textColor.withValues(alpha: 0.7),
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: pets.map((Map<String, dynamic> pet) {
                      final petId = pet['petId'];
                      final bool selected = widget.selectedPetIds.contains(
                        petId,
                      );

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
                          children: <Widget>[
                            Text(
                              pet['name'] ?? '未命名',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: theme.textColor,
                              ),
                            ),
                            Text(
                              '性別：${pet['gender'] ?? '-'} ｜ 貓砂：${pet['litterType'] ?? '-'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFFEAF8EE),
                        checkmarkColor: const Color(0xFF2E8B47),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF2E8B47)
                              : theme.cardBorderColor,
                        ),
                        onSelected: (bool value) {
                          widget.onTogglePet(petId, value);
                        },
                      );
                    }).toList(),
                  );
                },
          ),
        ],
      ),
    );
  }
}
