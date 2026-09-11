// 檔案名稱：lib/features/shop/widgets/media/shop_banner_device_preview.dart
// 功能說明：後台預覽框：固定 16:9，重用前台 StoreBannerView，只改容器寬度

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

enum BannerPreviewSize { phone, tablet, desktop }

class ShopBannerDevicePreview extends StatelessWidget {
  const ShopBannerDevicePreview({
    super.key,
    required this.banner,
    required this.theme,
    required this.size,
    this.scope = PetNestBannerScope.home,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final BannerPreviewSize size;
  final PetNestBannerScope scope;

  static double widthOf(BannerPreviewSize size) {
    switch (size) {
      case BannerPreviewSize.tablet:
        return 720;
      case BannerPreviewSize.desktop:
        return 840;
      case BannerPreviewSize.phone:
        return 390;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double frameWidth = widthOf(size);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth.clamp(0, frameWidth);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(
                  size == BannerPreviewSize.phone ? 28 : 16,
                ),
                border: Border.all(color: Colors.black54),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (size == BannerPreviewSize.phone)
                    Container(
                      width: 72,
                      height: 8,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  AspectRatio(
                    aspectRatio: StoreBannerSafeLayout.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: banner.hasImage
                          ? StoreBannerView(
                              banner: banner,
                              theme: theme,
                              scope: scope,
                              borderRadius: 12,
                            )
                          : const ColoredBox(
                              color: Color(0xFF2C2C2E),
                              child: Center(
                                child: Text(
                                  '尚未上傳圖片',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
