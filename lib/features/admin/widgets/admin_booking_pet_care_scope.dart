// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_care_scope.dart
// 功能說明：訂單詳細頁共用一次載入的寵物照護表單，給表單分頁與桌機摘要使用。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_pet_care_form_loader.dart';

class AdminBookingPetCareScope extends InheritedWidget {
  const AdminBookingPetCareScope({
    super.key,
    required this.items,
    required this.loading,
    required super.child,
  });

  final List<BookingPetCareFormItem> items;
  final bool loading;

  BookingPetCareFormItem? itemOf(String petId) {
    final String id = petId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final BookingPetCareFormItem item in items) {
      if (item.petId.trim() == id) {
        return item;
      }
    }
    return null;
  }

  static AdminBookingPetCareScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminBookingPetCareScope>();
  }

  @override
  bool updateShouldNotify(AdminBookingPetCareScope oldWidget) {
    return loading != oldWidget.loading || items != oldWidget.items;
  }
}

class AdminBookingPetCareGate extends StatelessWidget {
  const AdminBookingPetCareGate({
    super.key,
    required this.future,
    required this.child,
  });

  final Future<List<BookingPetCareFormItem>>? future;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return AdminBookingPetCareScope(
        items: const <BookingPetCareFormItem>[],
        loading: false,
        child: child,
      );
    }
    return FutureBuilder<List<BookingPetCareFormItem>>(
      future: future,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<BookingPetCareFormItem>> snap,
          ) {
            return AdminBookingPetCareScope(
              items: snap.data ?? const <BookingPetCareFormItem>[],
              loading: snap.connectionState != ConnectionState.done,
              child: child,
            );
          },
    );
  }
}
