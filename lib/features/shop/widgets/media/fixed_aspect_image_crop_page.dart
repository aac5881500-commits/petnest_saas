// 檔案名稱：lib/features/shop/widgets/media/fixed_aspect_image_crop_page.dart
// 功能說明：固定比例圖片裁切：拖曳、縮放、輸出指定像素。App／Web 共用，不依賴 image_cropper。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/services/fixed_aspect_crop_math.dart';

class FixedAspectImageCropPage extends StatefulWidget {
  const FixedAspectImageCropPage({
    super.key,
    required this.imageBytes,
    required this.cropAspectRatio,
    required this.outputWidth,
    required this.outputHeight,
    this.title = '選擇顯示範圍',
    this.usageText = '',
    this.suggestedSizeText = '',
    this.hintText = '',
    this.keepTransparency = false,
  });

  final Uint8List imageBytes;
  final double cropAspectRatio;
  final int outputWidth;
  final int outputHeight;
  final String title;
  final String usageText;
  final String suggestedSizeText;
  final String hintText;
  final bool keepTransparency;

  static const int jpegQuality = 85;

  static Future<Uint8List?> open({
    required BuildContext context,
    required Uint8List imageBytes,
    double? cropAspectRatio,
    int? outputWidth,
    int? outputHeight,
    FixedImageSpec? spec,
    String title = '選擇顯示範圍',
    String usageText = '',
    String suggestedSizeText = '',
    String hintText = '',
    bool keepTransparency = false,
  }) {
    final FixedImageSpec resolved = spec ?? FixedImageSpec.homeBanner;
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return FixedAspectImageCropPage(
            imageBytes: imageBytes,
            cropAspectRatio: cropAspectRatio ?? resolved.cropAspectRatio,
            outputWidth: outputWidth ?? resolved.outputWidth,
            outputHeight: outputHeight ?? resolved.outputHeight,
            title: title,
            usageText: usageText.isEmpty ? resolved.cropUsageText : usageText,
            suggestedSizeText: suggestedSizeText.isEmpty
                ? '輸出 ${resolved.outputSizeLabel}'
                : suggestedSizeText,
            hintText: hintText,
            keepTransparency: keepTransparency,
          );
        },
      ),
    );
  }

  @override
  State<FixedAspectImageCropPage> createState() =>
      _FixedAspectImageCropPageState();
}

class _FixedAspectImageCropPageState extends State<FixedAspectImageCropPage> {
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

  String get _bodyHint {
    final List<String> parts = <String>[
      if (widget.usageText.trim().isNotEmpty) widget.usageText.trim(),
      if (widget.suggestedSizeText.trim().isNotEmpty)
        widget.suggestedSizeText.trim(),
      if (widget.hintText.trim().isNotEmpty) widget.hintText.trim(),
    ];
    if (parts.isEmpty) {
      return '框內區域就是前台主要顯示範圍。可拖曳、縮放圖片來選擇實際要顯示的內容。';
    }
    return parts.join('\n');
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
        widget.keepTransparency
            ? img.encodePng(decoded)
            : img.encodeJpg(decoded, quality: 92),
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

  Size get _imageSize => Size(_imageWidth, _imageHeight);

  void _applyClamped(ClampedCropTransform clamped) {
    _transform.value = Matrix4.identity()
      ..translateByDouble(clamped.tx, clamped.ty, 0, 1)
      ..scaleByDouble(clamped.scale, clamped.scale, clamped.scale, 1);
  }

  void _initTransformIfNeeded(Size viewport) {
    if (_didInitTransform && _viewport == viewport) {
      return;
    }
    _viewport = viewport;
    _didInitTransform = true;
    _applyClamped(
      FixedAspectCropMath.initialCover(image: _imageSize, viewport: viewport),
    );
  }

  void _clampTransform() {
    final Size? viewport = _viewport;
    if (viewport == null) {
      return;
    }
    final Matrix4 matrix = _transform.value.clone();
    _applyClamped(
      FixedAspectCropMath.clampTransform(
        image: _imageSize,
        viewport: viewport,
        scale: matrix.getMaxScaleOnAxis(),
        tx: matrix.storage[12],
        ty: matrix.storage[13],
      ),
    );
  }

  void _zoomBy(double factor) {
    final Size? viewport = _viewport;
    if (viewport == null) {
      return;
    }
    final double currentScale = _transform.value.getMaxScaleOnAxis();
    _applyClamped(
      FixedAspectCropMath.clampTransform(
        image: _imageSize,
        viewport: viewport,
        scale: currentScale * factor,
        tx: _transform.value.storage[12],
        ty: _transform.value.storage[13],
      ),
    );
  }

  void _reset() {
    final Size? viewport = _viewport;
    if (viewport == null) {
      return;
    }
    _didInitTransform = false;
    _initTransformIfNeeded(viewport);
    setState(() {});
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
      final Matrix4 matrix = _transform.value;
      final Rect crop = FixedAspectCropMath.cropRectInImage(
        image: _imageSize,
        viewport: viewport,
        scale: matrix.getMaxScaleOnAxis(),
        tx: matrix.storage[12],
        ty: matrix.storage[13],
      );
      int x = crop.left.round();
      int y = crop.top.round();
      int width = crop.width.round();
      int height = crop.height.round();
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
        widget.keepTransparency
            ? img.encodePng(output)
            : img.encodeJpg(
                output,
                quality: FixedAspectImageCropPage.jpegQuality,
              ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片處理失敗，請重新選擇圖片。')));
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
              children: <Widget>[
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
          children: <Widget>[
            Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(widget.title),
                leading: TextButton(
                  onPressed: _interactionLocked
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: _interactionLocked ? Colors.white38 : Colors.white,
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
                              _bodyHint,
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
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    icon: const Icon(Icons.zoom_out),
                                    label: const Text('縮小'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _interactionLocked
                                        ? null
                                        : _reset,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('重設'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _interactionLocked
                                        ? null
                                        : () => _zoomBy(1.2),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
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
            if (_preparing) _buildBusyOverlay(message: '正在讀取圖片…'),
            if (_applying) _buildBusyOverlay(message: '正在處理圖片…'),
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
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 48,
          ),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
        final double coverScale = FixedAspectCropMath.coverScale(
          image: _imageSize,
          viewport: viewport,
        );
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
                      maxScale:
                          coverScale * FixedAspectCropMath.maxZoomMultiplier,
                      onInteractionEnd: (_) {
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
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
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
