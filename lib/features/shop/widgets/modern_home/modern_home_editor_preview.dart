// 檔案名稱：lib/features/shop/widgets/modern_home/modern_home_editor_preview.dart
// 功能說明：新版 Beta 外觀設定的手機預覽。內容就是正式新版首頁。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_modern_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

class ModernHomeEditorPreview extends StatelessWidget {
  const ModernHomeEditorPreview({
    super.key,
    required this.shopId,
    this.draftModernAppearance,
    this.draftLogoUrl,
    this.showCaption = true,
    this.showPhoneChrome = true,
    this.layoutCanvas = false,
    this.isEmbeddedAdminPreview = false,
    this.canvasMode = 'canvas',
    this.frameWidth = 390,
    this.selectedSectionId,
    this.onSelectSection,
    this.onBrandStyleChanged,
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

  /// 前台外觀設定用的首頁編排畫布，不縮小完整前台。
  final bool layoutCanvas;
  final bool isEmbeddedAdminPreview;

  /// 區分桌面、手機與對話框畫布，避免同一份 key 被掛兩次。
  final String canvasMode;
  final double frameWidth;
  final String? selectedSectionId;
  final ValueChanged<String>? onSelectSection;
  final ValueChanged<StoreBrandStyle>? onBrandStyleChanged;
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
          Text(
            layoutCanvas ? '首頁編排畫布' : '即時預覽',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            layoutCanvas ? '點選區塊後，在另一側調整該區塊設定' : '調整右側設定後立即查看新版首頁效果',
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
      key: ValueKey<String>(
        layoutCanvas
            ? 'home-canvas-$canvasMode-$shopId'
            : 'modern-home-preview-$shopId',
      ),
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
      layoutCanvas: layoutCanvas,
      isEmbeddedAdminPreview: isEmbeddedAdminPreview,
      canvasMode: canvasMode,
      selectedSectionId: selectedSectionId,
      onSelectSection: onSelectSection,
      onBrandStyleChanged: onBrandStyleChanged,
    );
  }

  Widget _frame() {
    if (layoutCanvas) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 640;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: frameWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(frameWidth, height),
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                      textScaler: TextScaler.noScaling,
                    ),
                    child: _page(),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
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
