// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_strip.dart
// 功能說明：店主訂單寵物區：依內容區實際寬度排列，不預留固定高度，保留所有寵物的安全提醒

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
      return _withReminder(
        context,
        _grid(context, const <String, Map<String, dynamic>>{}),
      );
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
            return _withReminder(context, _grid(context, fallbacks));
          },
    );
  }

  Widget _withReminder(BuildContext context, Widget petsView) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[petsView],
    );
  }

  Widget _grid(
    BuildContext context,
    Map<String, Map<String, dynamic>> fallbacks,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 10;
        // Use the panel's actual width; never reserve a tall horizontal carousel.
        final int columns = (constraints.maxWidth / 260).floor().clamp(
          1,
          pets.length.clamp(1, 4),
        );
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Map<String, dynamic> pet in pets)
              SizedBox(width: width, child: _card(pet, fallbacks)),
          ],
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
