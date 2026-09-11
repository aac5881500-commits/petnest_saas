// 檔案名稱：lib/core/widgets/petnest_cached_image.dart
// 功能說明：公開圖片磁碟快取；敏感圖不走公開長期快取。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PetNestImageCachePolicy {
  publicDisk,
  memoryOnly,
  none,
}

class PetNestCachedImage extends StatelessWidget {
  const PetNestCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.policy = PetNestImageCachePolicy.publicDisk,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final PetNestImageCachePolicy policy;

  Widget get _fallback {
    return errorWidget ??
        ColoredBox(
          color: const Color(0xFFF3EDE6),
          child: Icon(
            Icons.image_outlined,
            color: Colors.brown.shade300,
            size: 28,
          ),
        );
  }

  Widget get _busy {
    return placeholder ??
        const ColoredBox(
          color: Color(0xFFF7F1EA),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl.trim();
    Widget child;
    if (url.isEmpty) {
      child = _fallback;
    } else if (policy == PetNestImageCachePolicy.none ||
        policy == PetNestImageCachePolicy.memoryOnly ||
        kIsWeb) {
      child = Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        gaplessPlayback: true,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stack) =>
                _fallback,
        loadingBuilder:
            (BuildContext context, Widget image, ImageChunkEvent? progress) {
              if (progress == null) {
                return image;
              }
              return _busy;
            },
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (BuildContext context, String url) => _busy,
        errorWidget:
            (BuildContext context, String url, Object error) => _fallback,
      );
    }
    if (borderRadius == null) {
      return child;
    }
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}
