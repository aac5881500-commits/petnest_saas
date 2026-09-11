// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_care_forms.dart
// 功能說明：訂單內每隻寵物的照護表單答案（新子集合路徑與舊 nested map 相容）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';

class AdminBookingPetCareForms extends StatelessWidget {
  const AdminBookingPetCareForms({
    super.key,
    required this.shopId,
    required this.userId,
    required this.pets,
  });

  final String shopId;
  final String userId;
  final List<Map<String, dynamic>> pets;

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        for (final Map<String, dynamic> pet in pets)
          _PetCareCard(shopId: shopId, userId: userId, pet: pet),
      ],
    );
  }
}

class _PetCareCard extends StatelessWidget {
  const _PetCareCard({
    required this.shopId,
    required this.userId,
    required this.pet,
  });

  final String shopId;
  final String userId;
  final Map<String, dynamic> pet;

  String get _petId {
    return (pet['petId'] ?? pet['id'] ?? '').toString().trim();
  }

  String get _petName {
    final String name = (pet['name'] ?? pet['petName'] ?? '').toString().trim();
    return name.isEmpty ? '未命名寵物' : name;
  }

  Future<Map<String, dynamic>?> _load() async {
    Map<String, dynamic>? livePet;
    Map<String, dynamic>? sub;
    if (userId.isNotEmpty && _petId.isNotEmpty && shopId.isNotEmpty) {
      final DocumentSnapshot<Map<String, dynamic>> petSnap =
          await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(userId)
              .collection('pets')
              .doc(_petId)
              .get();
      livePet = petSnap.data();
      final DocumentSnapshot<Map<String, dynamic>> ansSnap =
          await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(userId)
              .collection('pets')
              .doc(_petId)
              .collection(PetShopFormAnswers.collectionName)
              .doc(shopId)
              .get();
      sub = ansSnap.data();
    }
    return PetShopFormAnswers.resolve(
      shopId: shopId,
      subcollectionData: sub ??
          (pet['shopFormAnswers'] is Map
              ? Map<String, dynamic>.from(pet['shopFormAnswers'] as Map)
              : null),
      petData: livePet ?? pet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _load(),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snap) {
            final Map<String, dynamic>? raw = snap.data;
            final CustomFormAnswerSnapshot? parsed =
                CustomFormAnswerSnapshot.tryParse(raw);
            final bool visible =
                parsed != null &&
                parsed.answers.any(
                  (CustomFormAnswerItem item) =>
                      item.displayValue.trim().isNotEmpty,
                );
            if (!visible) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AdminBookingDetailSection(
                title: '寵物照護資料・$_petName',
                collapsible: true,
                initiallyExpanded: false,
                child: CustomFormAnswerView(
                  raw: raw,
                  title: '$_petName 照護資料',
                  theme: HomeThemeModel.classicDefault,
                  collapsible: false,
                ),
              ),
            );
          },
    );
  }
}
