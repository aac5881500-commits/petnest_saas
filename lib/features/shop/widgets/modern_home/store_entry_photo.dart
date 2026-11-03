import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_entry_builtin_images.dart';

/// Same photo source in the editor and public storefront; accepts only known assets.
class StoreEntryPhoto extends StatelessWidget {
  const StoreEntryPhoto(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.gaplessPlayback = true,
    this.errorBuilder,
  });
  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width, height;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  Widget build(BuildContext context) {
    final asset = StoreEntryBuiltinImages.asset(url);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        gaplessPlayback: gaplessPlayback,
        errorBuilder: errorBuilder,
      );
    }
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      gaplessPlayback: gaplessPlayback,
      errorBuilder: errorBuilder,
    );
  }
}
