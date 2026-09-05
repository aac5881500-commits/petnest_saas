// 檔案名稱：lib/features/shop/widgets/booking/booking_pet_section.dart
// 功能說明：前台預約寵物選擇區塊：顯示我的寵物、新增寵物、選擇入住寵物

import 'package:firebase_auth/firebase_auth.dart';
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
    this.petsStream,
    this.isLoggedIn,
  });

  final List<String> selectedPetIds;
  final ValueChanged<List<Map<String, dynamic>>> onPetsLoaded;
  final void Function(String petId, bool selected) onTogglePet;
  final HomeThemeModel theme;
  final String? title;
  final Stream<List<Map<String, dynamic>>>? petsStream;
  final bool? isLoggedIn;

  @override
  State<BookingPetSection> createState() => _BookingPetSectionState();
}

class _BookingPetSectionState extends State<BookingPetSection> {
  late Stream<List<Map<String, dynamic>>> _petsStream;
  int _streamEpoch = 0;
  List<String> _lastNotifiedPetIds = const <String>[];

  @override
  void initState() {
    super.initState();
    try {
      _petsStream = widget.petsStream ?? PetService.instance.streamMyPets();
    } catch (error) {
      _petsStream = Stream<List<Map<String, dynamic>>>.error(error);
    }
  }

  void _reloadPets() {
    setState(() {
      _streamEpoch += 1;
      _lastNotifiedPetIds = const <String>[];
      try {
        _petsStream = widget.petsStream ?? PetService.instance.streamMyPets();
      } catch (error) {
        _petsStream = Stream<List<Map<String, dynamic>>>.error(error);
      }
    });
  }

  bool _readLoggedIn() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  void _notifyPetsLoaded(List<Map<String, dynamic>> pets) {
    final List<String> ids = pets
        .map((Map<String, dynamic> pet) => (pet['petId'] ?? '').toString())
        .toList();
    if (ids.length == _lastNotifiedPetIds.length) {
      var same = true;
      for (int i = 0; i < ids.length; i++) {
        if (ids[i] != _lastNotifiedPetIds[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        return;
      }
    }
    _lastNotifiedPetIds = ids;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onPetsLoaded(pets);
    });
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
            key: ValueKey<int>(_streamEpoch),
            stream: _petsStream,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                ) {
                  final bool loggedOut =
                      !(widget.isLoggedIn ?? _readLoggedIn());
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '寵物列表載入失敗，請再試一次。',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _reloadPets,
                            child: const Text('重新載入寵物'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final List<Map<String, dynamic>> allPets =
                      snapshot.data ?? <Map<String, dynamic>>[];
                  final List<Map<String, dynamic>> pets = allPets.where((
                    Map<String, dynamic> pet,
                  ) {
                    final String type = (pet['type'] ?? '').toString();
                    final String species = (pet['species'] ?? '').toString();
                    return type == 'cat' || species == 'cat';
                  }).toList();
                  _notifyPetsLoaded(pets);

                  final bool isLimitReached = allPets.length >= 10;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLimitReached || loggedOut
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const AddPetPage(),
                                    ),
                                  );
                                  if (mounted) {
                                    _reloadPets();
                                  }
                                },
                          child: Text(
                            loggedOut
                                ? '登入後可新增寵物'
                                : (isLimitReached ? '已達上限（10隻）' : '+ 新增寵物'),
                            style: TextStyle(
                              fontSize: 14,
                              color: isLimitReached || loggedOut
                                  ? theme.textColor.withValues(alpha: 0.4)
                                  : theme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      if (loggedOut)
                        Text(
                          '目前尚未登入。請先選擇安親日期與時段；登入後即可選擇寵物並繼續預約。',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textColor.withValues(alpha: 0.7),
                          ),
                        )
                      else if (pets.isEmpty)
                        Text(
                          '尚未新增寵物',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textColor.withValues(alpha: 0.7),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pets.map((Map<String, dynamic> pet) {
                            final String petId = (pet['petId'] ?? '')
                                .toString();
                            final bool selected = widget.selectedPetIds
                                .contains(petId);

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
                              label: Text(
                                pet['name'] ?? '未命名',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: theme.textColor,
                                ),
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
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}
