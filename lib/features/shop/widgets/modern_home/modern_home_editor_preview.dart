// 檔案名稱：lib/features/shop/widgets/modern_home/modern_home_editor_preview.dart
// 功能說明：新版 Beta 外觀設定的手機預覽。內容就是正式新版首頁。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_modern_page.dart';

class ModernHomeEditorPreview extends StatelessWidget {
  const ModernHomeEditorPreview({
    super.key,
    required this.shopId,
    this.draftModernAppearance,
    this.draftLogoUrl,
    this.showCaption = true,
    this.showPhoneChrome = true,
    this.frameWidth = 390,
    this.draftHomeBanners,
    this.initialPreviewBannerId,
    this.onPreviewBannerChanged,
    this.onPreviewTextSelected,
    this.onPreviewCtaSelected,
    this.previewImageBytes,
    this.previewSelectedTextId,
    this.previewCtaSelected = false,
  });

  final String shopId;
  final Map<String, dynamic>? draftModernAppearance;
  final String? draftLogoUrl;
  final bool showCaption;
  final bool showPhoneChrome;
  final double frameWidth;
  final List<StoreBannerModel>? draftHomeBanners;
  final String? initialPreviewBannerId;
  final ValueChanged<StoreBannerModel>? onPreviewBannerChanged;
  final ValueChanged<String?>? onPreviewTextSelected;
  final VoidCallback? onPreviewCtaSelected;
  final Uint8List? previewImageBytes;
  final String? previewSelectedTextId;
  final bool previewCtaSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showCaption) ...<Widget>[
          const Text(
            '即時預覽',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '調整右側設定後立即查看新版首頁效果',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(child: _frame()),
      ],
    );
  }

  Widget _page() {
    return ShopPublicModernPage(
      key: ValueKey<String>('modern-home-preview-$shopId'),
      shopId: shopId,
      isPreview: true,
      draftModernAppearance: draftModernAppearance,
      draftLogoUrl: draftLogoUrl,
      draftHomeBanners: draftHomeBanners,
      initialPreviewBannerId: initialPreviewBannerId,
      onPreviewBannerChanged: onPreviewBannerChanged,
      onPreviewTextSelected: onPreviewTextSelected,
      onPreviewCtaSelected: onPreviewCtaSelected,
      previewImageBytes: previewImageBytes,
      previewSelectedTextId: previewSelectedTextId,
      previewCtaSelected: previewCtaSelected,
    );
  }

  Widget _frame() {
    if (!showPhoneChrome) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = frameWidth > constraints.maxWidth
              ? constraints.maxWidth
              : frameWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, child: _page()),
          );
        },
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390, maxHeight: 780),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD0D5DD)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Navigator(
                pages: <Page<void>>[
                  MaterialPage<void>(
                    key: const ValueKey<String>('modern-home-preview'),
                    child: _page(),
                  ),
                ],
                onDidRemovePage: (Page<Object?> page) {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
