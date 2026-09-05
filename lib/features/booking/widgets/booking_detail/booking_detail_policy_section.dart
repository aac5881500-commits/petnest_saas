// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_policy_section.dart
// 功能說明：條款確認精簡入口：顯示該筆訂單快照狀態，不讀後台最新條款覆蓋。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailPolicySection extends StatelessWidget {
  const BookingDetailPolicySection({
    super.key,
    required this.view,
    required this.onOpen,
  });

  final BookingDetailViewData view;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bool confirmed = view.termsState == BookingDetailTermsState.confirmed;
    final String subtitle = switch (view.termsState) {
      BookingDetailTermsState.confirmed =>
        '已確認 v${view.termsVersion}${view.termsAcceptedAt == null ? '' : '・${view.formatDateTime(view.termsAcceptedAt)}'}',
      BookingDetailTermsState.needsReconfirm => '條款已更新，請重新確認',
      BookingDetailTermsState.unconfirmed => '尚未確認條款',
    };

    return BookingDetailEntryRow(
      icon: Icons.gavel_outlined,
      title: view.policySectionTitle,
      subtitle: subtitle,
      done: confirmed,
      badge: confirmed
          ? null
          : (view.termsState == BookingDetailTermsState.needsReconfirm
                ? '待完成'
                : null),
      onTap: onOpen,
    );
  }
}
