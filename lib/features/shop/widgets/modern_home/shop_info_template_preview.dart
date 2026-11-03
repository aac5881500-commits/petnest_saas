import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';

/// Reference footer only: exclude the bottom navigation regardless of card width.
class ShopInfoTemplatePreview extends StatelessWidget {
  const ShopInfoTemplatePreview({super.key, required this.preset});
  final ShopInfoPreset preset;
  @override
  Widget build(BuildContext context) {
    final (top, bottom) = preset.previewCrop;
    const width = 841.0;
    const height = 1870.0;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: width,
        height: height * (bottom - top),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: Transform.translate(
              offset: Offset(0, -height * top),
              child: Image.asset(
                preset.previewAsset,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
