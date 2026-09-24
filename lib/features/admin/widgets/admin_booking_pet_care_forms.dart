// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_care_forms.dart
// 功能說明：訂單「表單資料」中的寵物照護卡；解析與寵物卡 bottom sheet 相同。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/booking_pet_care_form_loader.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_focus.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_scope.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';

class AdminBookingPetCareForms extends StatelessWidget {
  const AdminBookingPetCareForms({
    super.key,
    required this.shopId,
    required this.userId,
    required this.pets,
    this.bookingId = '',
  });

  final String shopId;
  final String userId;
  final String bookingId;
  final List<Map<String, dynamic>> pets;

  @override
  Widget build(BuildContext context) {
    final AdminBookingPetCareScope? scope = AdminBookingPetCareScope.maybeOf(
      context,
    );
    if (scope != null) {
      return _cards(context, scope.items);
    }
    if (pets.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<BookingPetCareFormItem>>(
      future: BookingPetCareFormLoader.load(
        shopId: shopId,
        userId: userId,
        pets: pets,
        bookingId: bookingId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<BookingPetCareFormItem>> snap,
          ) {
            return _cards(
              context,
              snap.data ?? const <BookingPetCareFormItem>[],
            );
          },
    );
  }

  Widget _cards(BuildContext context, List<BookingPetCareFormItem> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final AdminBookingFormFocusScope? focus =
        AdminBookingFormFocusScope.maybeOf(context);
    final bool expanded =
        focus?.isExpanded(AdminBookingFormAnchor.petCare) ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            '寵物照護資料',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        for (final BookingPetCareFormItem item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminBookingDetailCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey<String>(
                    'pet-care-${item.petId}-${expanded ? 'open' : 'idle'}',
                  ),
                  initiallyExpanded: true,
                  leading: ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: item.photoUrl.trim().isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFE8DCC8),
                              child: Icon(Icons.pets, size: 20),
                            )
                          : Image.network(
                              item.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stack,
                                  ) {
                                    return const ColoredBox(
                                      color: Color(0xFFE8DCC8),
                                      child: Icon(Icons.pets, size: 20),
                                    );
                                  },
                            ),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('已填 ${item.filledCount} 題'),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: CustomFormAnswerView(
                        raw: item.raw,
                        title: '${item.name} 照護資料',
                        theme: HomeThemeModel.classicDefault,
                        collapsible: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminBookingPetCareFormsSummary extends StatelessWidget {
  const AdminBookingPetCareFormsSummary({
    super.key,
    required this.shopId,
    required this.userId,
    required this.pets,
    this.bookingId = '',
  });

  final String shopId;
  final String userId;
  final String bookingId;
  final List<Map<String, dynamic>> pets;

  @override
  Widget build(BuildContext context) {
    final AdminBookingPetCareScope? scope = AdminBookingPetCareScope.maybeOf(
      context,
    );
    if (scope != null) {
      return _label(scope.loading, scope.items.length);
    }
    return FutureBuilder<List<BookingPetCareFormItem>>(
      future: BookingPetCareFormLoader.load(
        shopId: shopId,
        userId: userId,
        pets: pets,
        bookingId: bookingId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<BookingPetCareFormItem>> snap,
          ) {
            return _label(
              snap.connectionState != ConnectionState.done,
              snap.data?.length ?? 0,
            );
          },
    );
  }

  Widget _label(bool loading, int count) {
    if (loading && count <= 0) {
      return const Text('讀取中', style: TextStyle(fontWeight: FontWeight.w700));
    }
    return Text(
      count > 0 ? '$count 隻已填' : '無',
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}
