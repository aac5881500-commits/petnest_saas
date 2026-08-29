// lib/features/shop/widgets/media/banner_image_crop_page.dart
// 活動海報 16:9 裁切畫面（Web / Android / iOS）
// 功能：店主拖曳、縮放後，輸出前台 Banner 使用的 16:9 圖片。
// 不依賴 image_cropper（該套件 Web 不相容）。

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class BannerImageCropPage extends StatefulWidget {
  const BannerImageCropPage({
    super.key,
    required this.imageBytes,
    this.cropAspectRatio = aspectRatio,
    this.outputWidth = 1600,
    this.outputHeight = 900,
    this.hintText =
        '框內區域就是前台活動海報主要顯示範圍。可拖曳、縮放圖片來選擇實際要顯示的內容。',
  });

  final Uint8List imageBytes;
  final double cropAspectRatio;
  final int outputWidth;
  final int outputHeight;
  final String hintText;

  static const double aspectRatio = 16 / 9;
  static const int jpegQuality = 85;

  static Future<Uint8List?> open({
    required BuildContext context,
    required Uint8List imageBytes,
    double cropAspectRatio = aspectRatio,
    int outputWidth = 1600,
    int outputHeight = 900,
    String hintText =
        '框內區域就是前台活動海報主要顯示範圍。可拖曳、縮放圖片來選擇實際要顯示的內容。',
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return BannerImageCropPage(
            imageBytes: imageBytes,
            cropAspectRatio: cropAspectRatio,
            outputWidth: outputWidth,
            outputHeight: outputHeight,
            hintText: hintText,
          );
        },
      ),
    );
  }

  @override
  State<BannerImageCropPage> createState() => _BannerImageCropPageState();
}

class _BannerImageCropPageState extends State<BannerImageCropPage> {
  final TransformationController _transform = TransformationController();

  img.Image? _workingImage;
  Uint8List? _previewBytes;
  String? _errorMessage;
  Size? _viewport;
  bool _preparing = true;
  bool _applying = false;
  bool _didInitTransform = false;
  bool _didPop = false;

  static const int _previewMaxSide = 2400;
  static const double _maxZoomMultiplier = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prepareImage();
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _prepareImage() {
    try {
      img.Image? decoded = img.decodeImage(widget.imageBytes);
      if (decoded == null) {
        _errorMessage = '圖片格式不支援，請使用 JPG、PNG 或 WEBP';
        return;
      }

      decoded = img.bakeOrientation(decoded);

      if (decoded.width <= 0 || decoded.height <= 0) {
        _errorMessage = '圖片讀取失敗，請換一張照片再試';
        return;
      }

      if (decoded.width > _previewMaxSide || decoded.height > _previewMaxSide) {
        if (decoded.width >= decoded.height) {
          decoded = img.copyResize(decoded, width: _previewMaxSide);
        } else {
          decoded = img.copyResize(decoded, height: _previewMaxSide);
        }
      }

      _workingImage = decoded;
      _previewBytes = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 92),
      );
    } catch (_) {
      _errorMessage = '圖片讀取失敗，請換一張照片再試';
    } finally {
      if (mounted) {
        setState(() {
          _preparing = false;
        });
      }
    }
  }

  double get _imageWidth => (_workingImage?.width ?? 1).toDouble();

  double get _imageHeight => (_workingImage?.height ?? 1).toDouble();

  double _coverScale(Size viewport) {
    return math.max(
      viewport.width / _imageWidth,
      viewport.height / _imageHeight,
    );
  }

  void _initTransformIfNeeded(Size viewport) {
    if (_didInitTransform && _viewport == viewport) {
      return;
    }

    _viewport = viewport;
    _didInitTransform = true;

    final double coverScale = _coverScale(viewport);
    final double scaledWidth = _imageWidth * coverScale;
    final double scaledHeight = _imageHeight * coverScale;
    final double dx = (viewport.width - scaledWidth) / 2;
    final double dy = (viewport.height - scaledHeight) / 2;

    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(coverScale, coverScale, coverScale, 1);
  }

  void _clampTransform() {
    final Size? viewport = _viewport;
    if (viewport == null) {
      return;
    }

    final double coverScale = _coverScale(viewport);
    final double maxScale = coverScale * _maxZoomMultiplier;
    final Matrix4 matrix = _transform.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    final double scale = currentScale.clamp(coverScale, maxScale);

    double tx = matrix.storage[12];
    double ty = matrix.storage[13];

    if ((currentScale - scale).abs() > 0.0001) {
      final double ratio = scale / currentScale;
      final Offset center = Offset(viewport.width / 2, viewport.height / 2);
      tx = center.dx - (center.dx - tx) * ratio;
      ty = center.dy - (center.dy - ty) * ratio;
    }

    final double scaledWidth = _imageWidth * scale;
    final double scaledHeight = _imageHeight * scale;
    final double minTx = math.min(0, viewport.width - scaledWidth);
    final double minTy = math.min(0, viewport.height - scaledHeight);

    tx = tx.clamp(minTx, 0);
    ty = ty.clamp(minTy, 0);

    _transform.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _zoomBy(double factor) {
    final Size? viewport = _viewport;
    if (viewport == null) {
      return;
    }

    final double coverScale = _coverScale(viewport);
    final double currentScale = _transform.value.getMaxScaleOnAxis();
    final double nextScale = (currentScale * factor).clamp(
      coverScale,
      coverScale * _maxZoomMultiplier,
    );

    if (nextScale == currentScale) {
      return;
    }

    final double ratio = nextScale / currentScale;
    final Offset center = Offset(viewport.width / 2, viewport.height / 2);
    final double tx = _transform.value.storage[12];
    final double ty = _transform.value.storage[13];

    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - (center.dx - tx) * ratio,
        center.dy - (center.dy - ty) * ratio,
        0,
        1,
      )
      ..scaleByDouble(nextScale, nextScale, nextScale, 1);
    _clampTransform();
  }

  Future<void> _apply() async {
    if (_applying || _preparing || _didPop) {
      return;
    }

    final img.Image? workingImage = _workingImage;
    final Size? viewport = _viewport;
    if (workingImage == null || viewport == null) {
      return;
    }

    setState(() {
      _applying = true;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) {
        return;
      }

      _clampTransform();

      final Matrix4 inverse = Matrix4.inverted(_transform.value);
      final Offset topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
      final Offset bottomRight = MatrixUtils.transformPoint(
        inverse,
        Offset(viewport.width, viewport.height),
      );

      int x = topLeft.dx.round();
      int y = topLeft.dy.round();
      int width = (bottomRight.dx - topLeft.dx).round();
      int height = (bottomRight.dy - topLeft.dy).round();

      x = x.clamp(0, workingImage.width - 1);
      y = y.clamp(0, workingImage.height - 1);
      width = width.clamp(1, workingImage.width - x);
      height = height.clamp(1, workingImage.height - y);

      final img.Image cropped = img.copyCrop(
        workingImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      final img.Image output = img.copyResize(
        cropped,
        width: widget.outputWidth,
        height: widget.outputHeight,
        interpolation: img.Interpolation.cubic,
      );

      final Uint8List bytes = Uint8List.fromList(
        img.encodeJpg(output, quality: BannerImageCropPage.jpegQuality),
      );

      if (!mounted) {
        return;
      }

      _didPop = true;
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圖片處理失敗，請重新選擇圖片。')),
      );
    } finally {
      if (mounted && !_didPop) {
        setState(() {
          _applying = false;
        });
      }
    }
  }

  bool get _interactionLocked => _preparing || _applying;

  Widget _buildBusyOverlay({required String message}) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_interactionLocked,
      child: Material(
        color: Colors.black,
        child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('選擇顯示範圍'),
              leading: TextButton(
                onPressed: _interactionLocked
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: _interactionLocked
                        ? Colors.white38
                        : Colors.white,
                  ),
                ),
              ),
              leadingWidth: 72,
              actions: <Widget>[
                TextButton(
                  onPressed: _interactionLocked || _workingImage == null
                      ? null
                      : _apply,
                  child: Text(
                    '套用',
                    style: TextStyle(
                      color: _interactionLocked || _workingImage == null
                          ? Colors.white38
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: _errorMessage != null
                  ? _buildError()
                  : Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            widget.hintText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Expanded(child: _buildCropViewport()),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _interactionLocked
                                      ? null
                                      : () => _zoomBy(1 / 1.2),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                  ),
                                  icon: const Icon(Icons.zoom_out),
                                  label: const Text('縮小'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _interactionLocked
                                      ? null
                                      : () => _zoomBy(1.2),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                  ),
                                  icon: const Icon(Icons.zoom_in),
                                  label: const Text('放大'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_preparing)
            _buildBusyOverlay(message: '正在讀取圖片…'),
          if (_applying)
            _buildBusyOverlay(message: '正在處理圖片…'),
        ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? '圖片讀取失敗',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildCropViewport() {
    final Uint8List? previewBytes = _previewBytes;
    if (previewBytes == null || _workingImage == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth - 32;
        final double maxHeight = constraints.maxHeight;
        double cropWidth = maxWidth;
        double cropHeight = cropWidth / widget.cropAspectRatio;

        if (cropHeight > maxHeight) {
          cropHeight = maxHeight;
          cropWidth = cropHeight * widget.cropAspectRatio;
        }

        if (cropWidth <= 0 || cropHeight <= 0) {
          return const SizedBox.shrink();
        }

        final Size viewport = Size(cropWidth, cropHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _initTransformIfNeeded(viewport);
        });

        final double coverScale = _coverScale(viewport);

        return Center(
          child: SizedBox(
            width: cropWidth,
            height: cropHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: Colors.grey.shade900,
                    child: InteractiveViewer(
                      transformationController: _transform,
                      constrained: false,
                      panEnabled: !_interactionLocked,
                      scaleEnabled: !_interactionLocked,
                      minScale: coverScale,
                      maxScale: coverScale * _maxZoomMultiplier,
                      onInteractionEnd: (ScaleEndDetails details) {
                        if (_interactionLocked) {
                          return;
                        }
                        _clampTransform();
                      },
                      child: SizedBox(
                        width: _imageWidth,
                        height: _imageHeight,
                        child: Image.memory(
                          previewBytes,
                          width: _imageWidth,
                          height: _imageHeight,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
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
