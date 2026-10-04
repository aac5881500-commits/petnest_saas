// 檔案名稱：lib/features/shop/widgets/platform_media_asset_picker.dart
// 功能說明：店主從平台圖庫選取已啟用素材；小圖示用 contain＋棋盤格，不提供上傳。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/platform_media_asset.dart';
import '../../../core/services/platform_media_library_service.dart';

class PlatformMediaAssetPickerLabels {
  PlatformMediaAssetPickerLabels._();

  static const String emptyIcon = '平台尚未提供每日照護小圖示';
  static const String emptyGeneral = '目前沒有可選用的圖庫圖片';
  static const String loadError = '圖庫讀取失敗';
  static const String retry = '重新讀取';
}

class PlatformMediaPick {
  const PlatformMediaPick.asset(this.asset) : usePlatformDefault = false;

  const PlatformMediaPick.platformDefault()
    : asset = null,
      usePlatformDefault = true;

  final PlatformMediaAsset? asset;
  final bool usePlatformDefault;
}

Future<PlatformMediaAsset?> showPlatformMediaAssetPicker({
  required BuildContext context,
  required String category,
  String? selectedId,
  @visibleForTesting List<PlatformMediaAsset>? assetsOverride,
  @visibleForTesting Object? errorOverride,
  @visibleForTesting ImageProvider Function(String url)? imageProviderBuilder,
}) {
  return showModalBottomSheet<PlatformMediaAsset>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return PlatformMediaAssetPickerSheet(
        category: category,
        selectedId: selectedId ?? '',
        assetsOverride: assetsOverride,
        errorOverride: errorOverride,
        imageProviderBuilder: imageProviderBuilder,
      );
    },
  );
}

Future<PlatformMediaPick?> showShopHouseAssetPicker({
  required BuildContext context,
  required String placement,
  required String title,
  String selectedId = '',
  @visibleForTesting List<PlatformMediaAsset>? assetsOverride,
  @visibleForTesting Object? errorOverride,
  @visibleForTesting ImageProvider Function(String url)? imageProviderBuilder,
}) {
  final PlatformMediaAssetPickerSheet sheet = PlatformMediaAssetPickerSheet(
    category: PlatformMediaCategories.shopHouse,
    placement: placement,
    title: title,
    selectedId: selectedId,
    confirmSelection: true,
    includePlatformDefault: true,
    assetsOverride: assetsOverride,
    errorOverride: errorOverride,
    imageProviderBuilder: imageProviderBuilder,
  );
  final Size size = MediaQuery.sizeOf(context);
  if (size.width >= 700) {
    return showDialog<PlatformMediaPick>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(width: 760, height: size.height * 0.8, child: sheet),
        );
      },
    );
  }
  return showModalBottomSheet<PlatformMediaPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => sheet,
  );
}

class PlatformMediaAssetPickerSheet extends StatefulWidget {
  const PlatformMediaAssetPickerSheet({
    super.key,
    required this.category,
    this.selectedId = '',
    this.placement = '',
    this.title = '',
    this.confirmSelection = false,
    this.includePlatformDefault = false,
    this.assetsOverride,
    this.errorOverride,
    this.imageProviderBuilder,
  });

  final String category;
  final String selectedId;
  final String placement;
  final String title;
  final bool confirmSelection;
  final bool includePlatformDefault;
  final List<PlatformMediaAsset>? assetsOverride;
  final Object? errorOverride;
  final ImageProvider Function(String url)? imageProviderBuilder;

  @override
  State<PlatformMediaAssetPickerSheet> createState() =>
      _PlatformMediaAssetPickerSheetState();
}

class _PlatformMediaAssetPickerSheetState
    extends State<PlatformMediaAssetPickerSheet> {
  int _retry = 0;
  late String _pendingId;
  List<PlatformMediaAsset> _visible = const <PlatformMediaAsset>[];
  Object? _loggedError;

  bool get _isIcon =>
      widget.placement.isEmpty &&
      widget.category == PlatformMediaCategories.dailyCareIcon;

  @override
  void initState() {
    super.initState();
    _pendingId = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    final double factor = widget.confirmSelection ? 0.8 : 0.72;
    final double preferred = MediaQuery.sizeOf(context).height * factor;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double height =
              constraints.maxHeight.isFinite &&
                  constraints.maxHeight < preferred
              ? constraints.maxHeight
              : preferred;
          return SizedBox(
            height: height,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.title.trim().isEmpty
                              ? PlatformMediaCategories.label(widget.category)
                              : widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '關閉',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
                if (widget.confirmSelection) _confirmBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _confirmBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _apply, child: const Text('套用')),
          ),
        ],
      ),
    );
  }

  void _apply() {
    if (_pendingId.isEmpty) {
      Navigator.pop(context, const PlatformMediaPick.platformDefault());
      return;
    }
    for (final PlatformMediaAsset asset in _visible) {
      if (asset.id == _pendingId) {
        Navigator.pop(context, PlatformMediaPick.asset(asset));
        return;
      }
    }
    Navigator.pop(context, const PlatformMediaPick.platformDefault());
  }

  Widget _buildBody() {
    if (widget.errorOverride != null) {
      return _ErrorPane(onRetry: _retryLoad);
    }
    if (widget.assetsOverride != null) {
      return _buildGrid(_filterPlacement(widget.assetsOverride!));
    }
    final Stream<List<PlatformMediaAsset>> stream = widget.placement.isEmpty
        ? PlatformMediaLibraryService.instance.streamEnabledAssets(
            widget.category,
          )
        : PlatformMediaLibraryService.instance.streamEnabledForPlacement(
            widget.placement,
          );
    return StreamBuilder<List<PlatformMediaAsset>>(
      key: ValueKey<int>(_retry),
      stream: stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<PlatformMediaAsset>> snapshot,
          ) {
            if (snapshot.hasError) {
              _logLoadError(snapshot.error);
              return _ErrorPane(onRetry: _retryLoad);
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildGrid(snapshot.data ?? const <PlatformMediaAsset>[]);
          },
    );
  }

  List<PlatformMediaAsset> _filterPlacement(List<PlatformMediaAsset> assets) {
    if (widget.placement.isEmpty) {
      return assets;
    }
    return assets
        .where(
          (PlatformMediaAsset asset) => asset.allowsPlacement(widget.placement),
        )
        .toList();
  }

  Widget _buildGrid(List<PlatformMediaAsset> assets) {
    _visible = assets;
    if (assets.isEmpty && !widget.includePlatformDefault) {
      return Center(
        child: Text(
          _isIcon
              ? PlatformMediaAssetPickerLabels.emptyIcon
              : PlatformMediaAssetPickerLabels.emptyGeneral,
          textAlign: TextAlign.center,
        ),
      );
    }
    final int extra = widget.includePlatformDefault ? 1 : 0;
    final bool narrow = MediaQuery.sizeOf(context).width < 700;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: widget.confirmSelection
          ? SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: narrow ? 2 : 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            )
          : SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _isIcon ? 120 : 180,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: _isIcon ? 0.78 : 0.82,
            ),
      itemCount: assets.length + extra,
      itemBuilder: (BuildContext context, int index) {
        if (widget.includePlatformDefault && index == 0) {
          return _defaultTile();
        }
        final PlatformMediaAsset asset = assets[index - extra];
        final bool selected = widget.confirmSelection
            ? asset.id == _pendingId
            : asset.id == widget.selectedId;
        return InkWell(
          onTap: () {
            if (!widget.confirmSelection) {
              Navigator.pop(context, asset);
              return;
            }
            setState(() {
              _pendingId = asset.id;
            });
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black12,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (_isIcon) const PlatformMediaTransparencyBoard(),
                        Padding(
                          padding: EdgeInsets.all(_isIcon ? 8 : 0),
                          child: _assetImage(asset),
                        ),
                        if (selected)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.check_circle,
                                color: Color(0xFF1565C0),
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    asset.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _defaultTile() {
    final bool selected = _pendingId.isEmpty;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        setState(() {
          _pendingId = '';
        });
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.cottage_outlined, color: colors.primary),
            const SizedBox(height: 8),
            const Text(
              'PetNest 預設',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xFF1565C0),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _assetImage(PlatformMediaAsset asset) {
    final String url = asset.thumbnailUrl.isEmpty
        ? asset.imageUrl
        : asset.thumbnailUrl;
    final BoxFit fit = _isIcon ? BoxFit.contain : BoxFit.cover;
    final ImageProvider? override = widget.imageProviderBuilder?.call(url);
    if (override != null) {
      return Image(image: override, fit: fit);
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) {
        return const ColoredBox(
          color: Color(0xFFF3F4F6),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
      },
    );
  }

  void _logLoadError(Object? error) {
    if (!kDebugMode || identical(_loggedError, error)) {
      return;
    }
    _loggedError = error;
    debugPrint('PlatformMediaAssetPicker load error:\n$error');
  }

  void _retryLoad() {
    _loggedError = null;
    setState(() {
      _retry += 1;
    });
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(PlatformMediaAssetPickerLabels.loadError),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onRetry,
            child: const Text(PlatformMediaAssetPickerLabels.retry),
          ),
        ],
      ),
    );
  }
}

class PlatformMediaTransparencyBoard extends StatelessWidget {
  const PlatformMediaTransparencyBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _CheckerPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 8;
    final Paint light = Paint()..color = const Color(0xFFF4F5F7);
    final Paint dark = Paint()..color = const Color(0xFFE4E7EC);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final int ix = (x / cell).floor();
        final int iy = (y / cell).floor();
        if ((ix + iy).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
