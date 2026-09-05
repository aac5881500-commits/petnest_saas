// 檔案名稱：lib/features/booking/pages/pre_arrival_guide_page.dart
// 功能說明：客戶端入住前準備完整內容（標題／文字／圖片），不需勾選確認。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

class PreArrivalGuidePage extends StatelessWidget {
  const PreArrivalGuidePage({super.key, required this.guide});

  final PreArrivalGuideModel guide;

  @override
  Widget build(BuildContext context) {
    final List<PreArrivalGuideBlock> blocks = guide.visibleBlocks;
    return ShopFrontendThemeScope(
      shopId: guide.shopId,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: BookingDetailUi.of(context).background,
          appBar: AppBar(
            title: Text(guide.displayTitle),
            backgroundColor: BookingDetailUi.of(context).background,
          ),
          body: BookingDetailUi.constrain(
            ListView(
              padding: const EdgeInsets.all(BookingDetailUi.pagePadding),
              children: <Widget>[
                for (final PreArrivalGuideBlock block in blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _block(context, block),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _block(BuildContext context, PreArrivalGuideBlock block) {
    if (block.type == PreArrivalGuideBlockType.heading) {
      return Text(
        block.text,
        style: TextStyle(
          fontSize: BookingDetailUi.sectionTitleSize,
          fontWeight: FontWeight.w700,
          color: BookingDetailUi.of(context).text,
        ),
      );
    }
    if (block.type == PreArrivalGuideBlockType.text) {
      return Text(
        block.text,
        style: TextStyle(
          fontSize: BookingDetailUi.bodySize,
          color: BookingDetailUi.of(context).text,
          height: 1.5,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: BookingDetailSoftNetworkImage(
                    url: block.imageUrl,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.broken_image_outlined,
                  ),
                ),
              ),
            );
          },
          child: BookingDetailSoftNetworkImage(
            url: block.imageUrl,
            height: 220,
            fit: BoxFit.cover,
            fallbackIcon: Icons.broken_image_outlined,
          ),
        ),
        if (block.caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              block.caption,
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ),
      ],
    );
  }
}
