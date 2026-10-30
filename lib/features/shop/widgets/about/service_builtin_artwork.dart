// 檔案名稱：lib/features/shop/widgets/about/service_builtin_artwork.dart
// 功能說明：服務內建圖片集；三組真實點陣素材共用快取，依服務取各自場景，不需上傳。
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ServiceBuiltinArtwork extends StatefulWidget {
  const ServiceBuiltinArtwork({
    super.key,
    required this.serviceId,
    required this.variant,
    required this.accent,
    required this.fallbackIcon,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  final String serviceId, variant;
  final Color accent;
  final IconData fallbackIcon;
  final BoxFit fit;
  final Alignment alignment;
  static const assets = {
    'storybook': 'assets/images/service_showcase_storybook_v2.png',
    'sticker': 'assets/images/service_showcase_sticker_v2.png',
    'postcard': 'assets/images/service_showcase_postcard_v2.png',
  };
  static const serviceCells = {
    'cat_hotel': 0,
    'dog_hotel': 1,
    'grooming': 2,
    'hospital': 3,
    'store': 4,
  };
  @override
  State<ServiceBuiltinArtwork> createState() => _ServiceBuiltinArtworkState();
}

class _ServiceBuiltinArtworkState extends State<ServiceBuiltinArtwork> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant ServiceBuiltinArtwork old) {
    super.didUpdateWidget(old);
    if (old.variant != widget.variant) _bind();
  }

  void _bind() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _info?.dispose();
    _info = null;
    final path = ServiceBuiltinArtwork.assets[widget.variant];
    if (path == null) return;
    _stream = AssetImage(path).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (info, sync) {
        if (!mounted) {
          info.dispose();
          return;
        }
        setState(() {
          _info?.dispose();
          _info = info;
        });
      },
      onError: (Object error, StackTrace? stack) {
        debugPrint('Service photo asset failed: $path ($error)');
        if (mounted) {
          setState(() {
            _info?.dispose();
            _info = null;
          });
        }
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _info?.image;
    if (image == null) {
      return Center(
        child: Icon(
          widget.variant == 'simple'
              ? widget.fallbackIcon
              : Icons.image_outlined,
          size: 30,
          color: widget.accent,
        ),
      );
    }
    return CustomPaint(
      painter: ServiceAtlasPainter(
        image: image,
        cell: ServiceBuiltinArtwork.serviceCells[widget.serviceId] ?? 5,
        fit: widget.fit,
        alignment: widget.alignment,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// 圖片集為三欄兩列；只取單一服務場景，略去產圖時可能出現的細格線。
class ServiceAtlasPainter extends CustomPainter {
  const ServiceAtlasPainter({
    required this.image,
    required this.cell,
    required this.fit,
    required this.alignment,
  });
  final ui.Image image;
  final int cell;
  final BoxFit fit;
  final Alignment alignment;
  Rect get cellRect => Rect.fromLTWH(
    (cell % 3) * image.width / 3,
    (cell ~/ 3) * image.height / 2,
    image.width / 3,
    image.height / 2,
  ).deflate(image.width / 3 * .02);
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final source = cellRect;
    final fitted = applyBoxFit(fit, source.size, size);
    final src = alignment.inscribe(fitted.source, source);
    final dst = alignment.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant ServiceAtlasPainter old) =>
      old.image != image ||
      old.cell != cell ||
      old.fit != fit ||
      old.alignment != alignment;
}
