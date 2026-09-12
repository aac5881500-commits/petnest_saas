// 檔案名稱：lib/features/admin/widgets/admin_booking_form_focus.dart
// 功能說明：桌機表單摘要點擊後展開並捲動到左側完整表單，不開新頁。

import 'package:flutter/material.dart';

enum AdminBookingFormAnchor { petCare, customerSubmit, adminCreate }

class AdminBookingFormFocusScope extends InheritedWidget {
  const AdminBookingFormFocusScope({
    super.key,
    required this.requestFocus,
    required this.expanded,
    required this.desktop,
    required this.anchorKeys,
    required super.child,
  });

  final void Function(AdminBookingFormAnchor anchor) requestFocus;
  final Set<AdminBookingFormAnchor> expanded;
  final bool desktop;
  final Map<AdminBookingFormAnchor, GlobalKey> anchorKeys;

  static AdminBookingFormFocusScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminBookingFormFocusScope>();
  }

  bool isExpanded(AdminBookingFormAnchor anchor) {
    if (!desktop) {
      return true;
    }
    return expanded.contains(anchor);
  }

  @override
  bool updateShouldNotify(AdminBookingFormFocusScope oldWidget) {
    return desktop != oldWidget.desktop ||
        expanded != oldWidget.expanded ||
        requestFocus != oldWidget.requestFocus;
  }
}
