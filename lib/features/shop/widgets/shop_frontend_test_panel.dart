// 檔案名稱：lib/features/shop/widgets/shop_frontend_test_panel.dart
// 功能說明：相容舊名稱，實際前台預覽外框見 shop_frontend_preview_frame.dart。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_preview_frame.dart';

export 'package:petnest_saas/features/shop/widgets/shop_frontend_preview_frame.dart'
    show ShopDashboardLiveFrontendOverlay, ShopFrontendPreviewFrame;

class ShopFrontendTestPanel extends StatelessWidget {
  const ShopFrontendTestPanel({
    super.key,
    required this.shopId,
    required this.shopCode,
    required this.onClose,
    this.homeResetToken = 0,
    this.showExpand = false,
    this.expanded = false,
    this.scaleToFit = true,
    this.onToggleExpand,
    this.previewBodyOverride,
  });

  static const Size liveFrontendSize =
      ShopFrontendPreviewFrame.phoneLogicalSize;
  static const Size dashboardFrontendPreviewSize =
      ShopFrontendPreviewFrame.phoneLogicalSize;

  final String shopId;
  final String shopCode;
  final VoidCallback onClose;
  final int homeResetToken;
  final bool showExpand;
  final bool expanded;
  final bool scaleToFit;
  final VoidCallback? onToggleExpand;

  @visibleForTesting
  final Widget? previewBodyOverride;

  static Widget liveRoot({
    required String shopId,
    VoidCallback? onClose,
    Widget? override,
  }) {
    return ShopFrontendPreviewFrame.liveRoot(
      shopId: shopId,
      onClose: onClose,
      override: override,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopFrontendPreviewFrame(
      shopId: shopId,
      shopCode: shopCode,
      onClose: onClose,
      homeResetToken: homeResetToken,
      showExpand: showExpand,
      expanded: expanded,
      scaleToFit: scaleToFit,
      onToggleExpand: onToggleExpand,
      previewBodyOverride: previewBodyOverride,
    );
  }
}
