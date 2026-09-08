// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_strip.dart
// 功能說明：店主訂單寵物區：桌面多欄小卡、手機橫向滑動，避免直排擠壓

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';

class AdminBookingPetStrip extends StatelessWidget {
  const AdminBookingPetStrip({
    super.key,
    required this.pets,
    this.shopId = '',
    this.userId = '',
  });

  final List<Map<String, dynamic>> pets;
  final String shopId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) {
      return const AdminBookingDetailCard(
        child: Text('沒有寵物資料', style: TextStyle(color: Colors.grey)),
      );
    }
    if (shopId.trim().isEmpty || userId.trim().isEmpty) {
      return _grid(context, const <String, Map<String, dynamic>>{});
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .collection('pets')
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
          ) {
            final Map<String, Map<String, dynamic>> fallbacks =
                <String, Map<String, dynamic>>{};
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in snap.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              fallbacks[doc.id] = doc.data();
            }
            return _grid(context, fallbacks);
          },
    );
  }

  Widget _grid(
    BuildContext context,
    Map<String, Map<String, dynamic>> fallbacks,
  ) {
    final AdminBookingDetailScope scope = AdminBookingDetailScope.of(context);
    if (scope.isPhone) {
      return SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pets.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 10),
          itemBuilder: (BuildContext context, int index) {
            return SizedBox(width: 220, child: _card(pets[index], fallbacks));
          },
        ),
      );
    }
    final int columns = scope.width >= 1200 ? 4 : (scope.width >= 900 ? 3 : 2);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = 10;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: pets
              .map(
                (Map<String, dynamic> pet) =>
                    SizedBox(width: width, child: _card(pet, fallbacks)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _card(
    Map<String, dynamic> pet,
    Map<String, Map<String, dynamic>> fallbacks,
  ) {
    final String petId = (pet['petId'] ?? pet['id'] ?? '').toString();
    return AdminBookingPetCard(
      pet: pet,
      fallback: fallbacks[petId],
      shopId: shopId,
      userId: userId,
      compact: true,
    );
  }
}
