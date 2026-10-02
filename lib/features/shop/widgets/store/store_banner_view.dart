// 檔案名稱：lib/features/shop/widgets/store/store_banner_view.dart
// 功能說明：商城海報 renderer：後台 Preview 與前台共用，效果只 overlay、不改原圖。

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';

enum StoreBannerInteractMode { none, image, text, cta }

class StoreBannerView extends StatelessWidget {
  const StoreBannerView({
    super.key,
    required this.banner,
    required this.theme,
    this.interactMode = StoreBannerInteractMode.none,
    this.selectedTextId,
    this.onChanged,
    this.onTextSelected,
    this.onCtaSelected,
    this.onTap,
    this.previewImageBytes,
    this.ctaSelected = false,
    this.borderRadius = 18,
    this.scope = PetNestBannerScope.store,
    this.sizePresetOverride,
    this.composeLive,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final StoreBannerInteractMode interactMode;
  final String? selectedTextId;
  final ValueChanged<StoreBannerModel>? onChanged;
  final ValueChanged<String?>? onTextSelected;
  final VoidCallback? onCtaSelected;
  final VoidCallback? onTap;
  final Uint8List? previewImageBytes;
  final bool ctaSelected;
  final double borderRadius;
  final PetNestBannerScope scope;
  final String? sizePresetOverride;
  final bool? composeLive;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool live =
              composeLive ??
              (interactMode != StoreBannerInteractMode.none ||
                  !banner.hasRenderedImage);
          final bool publishedHome =
              scope == PetNestBannerScope.home &&
              banner.hasPublishedPoster &&
              !live;
          final double rawHeight = scope == PetNestBannerScope.home
              ? (width <= 0 ? 0 : width / HomeBannerDisplay.aspectRatio)
              : StoreBannerSizePresets.heightForWidth(
                  sizePresetOverride ?? banner.sizePreset,
                  width,
                  scope: scope,
                );
          final double height;
          if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
            height = rawHeight.clamp(0.0, constraints.maxHeight);
          } else {
            height = rawHeight;
          }
          return SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: _BannerStage(
                banner: banner,
                theme: theme,
                width: width,
                height: height,
                interactMode: interactMode,
                selectedTextId: selectedTextId,
                onChanged: onChanged,
                onTextSelected: onTextSelected,
                onCtaSelected: onCtaSelected,
                onTap: onTap,
                previewImageBytes: previewImageBytes,
                ctaSelected: ctaSelected,
                homeFreeCompose:
                    live && scope == PetNestBannerScope.home && !publishedHome,
                completePoster: publishedHome,
                composeLive: live,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerStage extends StatelessWidget {
  const _BannerStage({
    required this.banner,
    required this.theme,
    required this.width,
    required this.height,
    required this.interactMode,
    required this.selectedTextId,
    required this.onChanged,
    required this.onTextSelected,
    required this.onCtaSelected,
    required this.onTap,
    required this.previewImageBytes,
    required this.ctaSelected,
    required this.homeFreeCompose,
    required this.composeLive,
    required this.completePoster,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final double width;
  final double height;
  final StoreBannerInteractMode interactMode;
  final String? selectedTextId;
  final ValueChanged<StoreBannerModel>? onChanged;
  final ValueChanged<String?>? onTextSelected;
  final VoidCallback? onCtaSelected;
  final VoidCallback? onTap;
  final Uint8List? previewImageBytes;
  final bool ctaSelected;
  final bool homeFreeCompose;
  final bool composeLive;
  final bool completePoster;

  bool get _editing => interactMode != StoreBannerInteractMode.none;

  @override
  Widget build(BuildContext context) {
    final Size bannerSize = Size(width, height);
    final Widget image = _BannerImage(
      banner: banner,
      theme: theme,
      useRendered: completePoster || (!composeLive && banner.hasRenderedImage),
      contain: completePoster,
      composeSource: composeLive && !completePoster,
      previewBytes: previewImageBytes,
    );
    if (completePoster) {
      return _wrapFrontTap(image);
    }
    if (!composeLive && banner.hasRenderedImage) {
      return _wrapFrontTap(image);
    }
    if (banner.isImageOnly) {
      return _wrapFrontTap(image);
    }
    if (banner.usesSafeTemplateOverlay && !homeFreeCompose) {
      return _wrapFrontTap(
        _SafeTemplateOverlay(
          banner: banner,
          theme: theme,
          width: width,
          height: height,
          image: image,
        ),
      );
    }
    final List<StoreBannerTextElement> texts = banner.resolvedTextElements;
    final Widget stack = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (interactMode == StoreBannerInteractMode.image)
          _EagerPanDetector(
            onUpdate: (DragUpdateDetails details) {
              _dragImage(details.delta);
            },
            onTap: () => onTextSelected?.call(null),
            child: image,
          )
        else
          image,
        if (banner.overlayMode != StoreBannerOverlayModes.none)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: StoreBannerGradientSpec.gradient(
                  mode: banner.overlayMode,
                  extent: banner.overlayExtent,
                  strength: banner.overlayStrength,
                  color: banner.overlayColor(theme),
                ),
              ),
            ),
          ),
        if (_editing && interactMode != StoreBannerInteractMode.image)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => onTextSelected?.call(null),
          ),
        ...texts.map((StoreBannerTextElement item) {
          Widget textItem = _BannerDraggableItem(
            key: ValueKey<String>('text_${item.id}'),
            bannerSize: bannerSize,
            positionX: item.positionX,
            positionY: item.positionY,
            enabled: _editing,
            selected: selectedTextId == item.id,
            onSelect: _editing ? () => onTextSelected?.call(item.id) : null,
            onMoved: (Offset next) {
              _commitText(item.id, next);
            },
            child: _BannerTextChip(
              element: item,
              bannerHeight: height,
              bannerWidth: width,
              selected: selectedTextId == item.id,
              brandColor: theme.primaryColor,
              allowTextBackground: !banner.showsCta,
              designScale: homeFreeCompose,
            ),
          );
          if (!_editing) {
            textItem = IgnorePointer(child: textItem);
          }
          return textItem;
        }),
        if (banner.showsCta)
          _wrapFrontPointer(
            child: _BannerDraggableItem(
              key: const ValueKey<String>('cta'),
              bannerSize: bannerSize,
              positionX: banner.ctaPositionX,
              positionY: banner.ctaPositionY,
              enabled: _editing,
              selected: ctaSelected,
              onSelect: _editing ? onCtaSelected : null,
              onMoved: _commitCta,
              child: _BannerCtaButton(
                banner: banner,
                theme: theme,
                selected: ctaSelected,
                onTap: null,
                bannerWidth: width,
                bannerHeight: height,
                designScale: homeFreeCompose,
              ),
            ),
          ),
      ],
    );

    if (_editing || onTap == null) {
      return stack;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: stack),
    );
  }

  Widget _wrapFrontTap(Widget child) {
    if (_editing || onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }

  Widget _wrapFrontPointer({required Widget child}) {
    if (_editing) {
      return child;
    }
    return IgnorePointer(child: child);
  }

  void _dragImage(Offset delta) {
    if (onChanged == null || width <= 0 || height <= 0) {
      return;
    }
    onChanged!(
      banner.copyWith(
        imageAlignmentX: (banner.imageAlignmentX - delta.dx / width).clamp(
          0.0,
          1.0,
        ),
        imageAlignmentY: (banner.imageAlignmentY - delta.dy / height).clamp(
          0.0,
          1.0,
        ),
      ),
    );
  }

  void _commitText(String id, Offset next) {
    if (onChanged == null) {
      return;
    }
    final List<StoreBannerTextElement> items = banner.resolvedTextElements.map((
      StoreBannerTextElement current,
    ) {
      if (current.id != id) {
        return current;
      }
      return current.copyWith(positionX: next.dx, positionY: next.dy);
    }).toList();
    onChanged!(banner.copyWith(textElements: items));
  }

  void _commitCta(Offset next) {
    if (onChanged == null) {
      return;
    }
    onChanged!(banner.copyWith(ctaPositionX: next.dx, ctaPositionY: next.dy));
  }
}

class _SafeTemplateOverlay extends StatelessWidget {
  const _SafeTemplateOverlay({
    required this.banner,
    required this.theme,
    required this.width,
    required this.height,
    required this.image,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final double width;
  final double height;
  final Widget image;

  String get _title {
    if (banner.title.trim().isNotEmpty) {
      return banner.title.trim();
    }
    for (final StoreBannerTextElement item in banner.resolvedTextElements) {
      if (item.hasText) {
        return item.text.trim();
      }
    }
    return '';
  }

  String get _subtitle {
    if (banner.subtitle.trim().isNotEmpty) {
      return banner.subtitle.trim();
    }
    final List<StoreBannerTextElement> items = banner.resolvedTextElements
        .where((StoreBannerTextElement item) => item.hasText)
        .toList();
    if (items.length >= 2) {
      return items[1].text.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String alignX = banner.resolvedTextAlignH;
    final String alignY = banner.resolvedTextAlignV;
    final String scale = banner.resolvedFontScale;
    final String overlayMode =
        banner.overlayMode == StoreBannerOverlayModes.none
        ? StoreBannerAlignX.overlayModeFor(alignX)
        : banner.overlayMode;
    final CrossAxisAlignment cross = switch (alignX) {
      StoreBannerAlignX.center => CrossAxisAlignment.center,
      StoreBannerAlignX.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final MainAxisAlignment main = switch (alignY) {
      StoreBannerAlignY.center => MainAxisAlignment.center,
      StoreBannerAlignY.bottom => MainAxisAlignment.end,
      _ => MainAxisAlignment.start,
    };
    final TextAlign textAlign = switch (alignX) {
      StoreBannerAlignX.center => TextAlign.center,
      StoreBannerAlignX.right => TextAlign.right,
      _ => TextAlign.left,
    };
    final Color textColor = banner.copyColor(theme);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        image,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: StoreBannerGradientSpec.gradient(
                mode: overlayMode,
                extent: banner.overlayExtent,
                strength: banner.overlayStrength,
                color: banner.overlayColor(theme),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * StoreBannerSafeLayout.insetX,
            vertical: height * StoreBannerSafeLayout.insetY,
          ),
          child: Column(
            mainAxisAlignment: main,
            crossAxisAlignment: cross,
            children: <Widget>[
              if (_title.isNotEmpty)
                Text(
                  _title,
                  maxLines: StoreBannerSafeLayout.titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: textAlign,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    fontSize:
                        height * StoreBannerSafeLayout.titleHeightRatio(scale),
                    shadows: const <Shadow>[
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              if (_subtitle.isNotEmpty) ...<Widget>[
                SizedBox(height: height * 0.02),
                Text(
                  _subtitle,
                  maxLines: StoreBannerSafeLayout.subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: textAlign,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    fontSize:
                        height *
                        StoreBannerSafeLayout.subtitleHeightRatio(scale),
                    shadows: const <Shadow>[
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
              if (banner.showsCta) ...<Widget>[
                SizedBox(height: height * 0.03),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width * 0.62),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(height * 0.08),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.04,
                        vertical: height * 0.018,
                      ),
                      child: Text(
                        banner.ctaText.trim(),
                        maxLines: StoreBannerSafeLayout.ctaMaxLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize:
                              height *
                              StoreBannerSafeLayout.ctaHeightRatio(scale),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({
    required this.banner,
    required this.theme,
    this.useRendered = false,
    this.contain = false,
    this.composeSource = false,
    this.previewBytes,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final bool useRendered;
  final bool contain;
  final bool composeSource;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final bool fullFrame = contain || (composeSource && banner.isImageOnly);
    final Uint8List? bytes = composeSource ? previewBytes : null;
    if ((bytes == null || bytes.isEmpty) && !banner.hasImage) {
      return ColoredBox(
        color: theme.cardColor,
        child: Icon(Icons.image_outlined, color: theme.primaryColor),
      );
    }
    if (bytes != null && bytes.isNotEmpty) {
      return ColoredBox(
        color: theme.cardColor,
        child: ClipRect(
          child: Transform.scale(
            scale: fullFrame ? 1 : banner.imageScale.clamp(1.0, 2.5),
            alignment: fullFrame ? Alignment.center : banner.imageAlignment,
            child: Image.memory(
              bytes,
              fit: fullFrame ? BoxFit.contain : BoxFit.cover,
              alignment: fullFrame ? Alignment.center : banner.imageAlignment,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            ),
          ),
        ),
      );
    }
    final String url = useRendered
        ? banner.renderedImageUrl
        : (composeSource ? banner.imageUrl.trim() : banner.frontImageUrl);
    return ColoredBox(
      color: theme.cardColor,
      child: ClipRect(
        child: Transform.scale(
          scale: useRendered || fullFrame
              ? 1
              : banner.imageScale.clamp(1.0, 2.5),
          alignment: useRendered || fullFrame
              ? Alignment.center
              : banner.imageAlignment,
          child: Image.network(
            url,
            fit: fullFrame ? BoxFit.contain : BoxFit.cover,
            alignment: fullFrame ? Alignment.center : banner.imageAlignment,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            loadingBuilder:
                (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) {
                    return child;
                  }
                  return ColoredBox(
                    color: theme.cardColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor,
                      ),
                    ),
                  );
                },
            errorBuilder: (_, _, _) {
              return ColoredBox(
                color: theme.cardColor,
                child: Icon(Icons.image_outlined, color: theme.primaryColor),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BannerDraggableItem extends StatefulWidget {
  const _BannerDraggableItem({
    super.key,
    required this.bannerSize,
    required this.positionX,
    required this.positionY,
    required this.enabled,
    required this.selected,
    required this.child,
    required this.onMoved,
    this.onSelect,
  });

  final Size bannerSize;
  final double positionX;
  final double positionY;
  final bool enabled;
  final bool selected;
  final Widget child;
  final ValueChanged<Offset> onMoved;
  final VoidCallback? onSelect;

  @override
  State<_BannerDraggableItem> createState() => _BannerDraggableItemState();
}

class _BannerDraggableItemState extends State<_BannerDraggableItem> {
  late double _x = widget.positionX;
  late double _y = widget.positionY;
  bool _dragging = false;
  Size _elementSize = Size.zero;
  Offset? _grabOffset;

  @override
  void didUpdateWidget(covariant _BannerDraggableItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging &&
        (oldWidget.positionX != widget.positionX ||
            oldWidget.positionY != widget.positionY)) {
      _x = widget.positionX;
      _y = widget.positionY;
    }
  }

  _RenderBannerPlaced? _canvasBox() {
    RenderObject? node = context.findRenderObject();
    while (node != null) {
      if (node is _RenderBannerPlaced) {
        return node;
      }
      node = node.parent;
    }
    return null;
  }

  void _rememberGrab(Offset globalPosition) {
    final _RenderBannerPlaced? canvas = _canvasBox();
    final RenderBox? element = canvas?.child;
    if (canvas == null ||
        element == null ||
        !element.hasSize ||
        !canvas.hasSize) {
      _grabOffset = null;
      return;
    }
    final Offset finger = canvas.globalToLocal(globalPosition);
    final Offset topLeft = canvas.globalToLocal(
      element.localToGlobal(Offset.zero),
    );
    _grabOffset = finger - topLeft;
    _elementSize = element.size;
  }

  void _moveToFinger(Offset globalPosition) {
    final _RenderBannerPlaced? canvas = _canvasBox();
    final Offset? grab = _grabOffset;
    if (canvas == null || grab == null || !canvas.hasSize) {
      return;
    }
    final Size canvasSize = canvas.size;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      return;
    }
    final Offset finger = canvas.globalToLocal(globalPosition);
    final Offset normalized = StoreBannerPlacement.normalize(
      actual: finger - grab,
      bannerSize: canvasSize,
      elementSize: _elementSize,
    );
    if (normalized.dx == _x && normalized.dy == _y) {
      return;
    }
    setState(() {
      _x = normalized.dx;
      _y = normalized.dy;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget.enabled) {
      content = _EagerPanDetector(
        onStart: (DragStartDetails details) {
          _dragging = true;
          _rememberGrab(details.globalPosition);
          widget.onSelect?.call();
        },
        onUpdate: (DragUpdateDetails details) {
          _moveToFinger(details.globalPosition);
        },
        onEnd: () {
          _dragging = false;
          _grabOffset = null;
          widget.onMoved(Offset(_x, _y));
        },
        onTap: widget.onSelect,
        child: content,
      );
    } else if (widget.onSelect != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: content,
      );
    }
    return _BannerPlaced(
      positionX: _x,
      positionY: _y,
      onChildSize: (Size size) {
        if (_elementSize != size) {
          _elementSize = size;
        }
      },
      child: content,
    );
  }
}

class _EagerPanDetector extends StatelessWidget {
  const _EagerPanDetector({
    required this.child,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onTap,
  });

  final Widget child;
  final ValueChanged<DragStartDetails>? onStart;
  final ValueChanged<DragUpdateDetails>? onUpdate;
  final VoidCallback? onEnd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory<GestureRecognizer>>{
        _EagerPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
              _EagerPanGestureRecognizer.new,
              (_EagerPanGestureRecognizer instance) {
                instance.onStart = onStart;
                instance.onUpdate = onUpdate;
                instance.onEnd = (_) => onEnd?.call();
                instance.onCancel = onEnd;
              },
            ),
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (TapGestureRecognizer instance) {
                instance.onTap = onTap;
              },
            ),
      },
      child: child,
    );
  }
}

class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _BannerPlaced extends SingleChildRenderObjectWidget {
  const _BannerPlaced({
    required this.positionX,
    required this.positionY,
    required this.onChildSize,
    required super.child,
  });

  final double positionX;
  final double positionY;
  final ValueChanged<Size> onChildSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBannerPlaced(
      positionX: positionX,
      positionY: positionY,
      onChildSize: onChildSize,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderBannerPlaced renderObject,
  ) {
    renderObject
      ..positionX = positionX
      ..positionY = positionY
      ..onChildSize = onChildSize;
  }
}

class _RenderBannerPlaced extends RenderShiftedBox {
  _RenderBannerPlaced({
    required double positionX,
    required double positionY,
    required this.onChildSize,
  }) : _positionX = positionX,
       _positionY = positionY,
       super(null);

  double _positionX;
  double _positionY;
  ValueChanged<Size> onChildSize;

  set positionX(double value) {
    if (_positionX == value) {
      return;
    }
    _positionX = value;
    markNeedsLayout();
  }

  set positionY(double value) {
    if (_positionY == value) {
      return;
    }
    _positionY = value;
    markNeedsLayout();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final RenderBox? box = child;
    if (box == null) {
      return;
    }
    final double safeX = size.width * StoreBannerPlacement.safeFraction;
    final double safeY = size.height * StoreBannerPlacement.safeFraction;
    box.layout(
      BoxConstraints(
        maxWidth: (size.width - safeX * 2).clamp(48.0, size.width),
        maxHeight: (size.height - safeY * 2).clamp(24.0, size.height),
      ),
      parentUsesSize: true,
    );
    onChildSize(box.size);
    final Offset offset = StoreBannerPlacement.offsetOf(
      positionX: _positionX,
      positionY: _positionY,
      bannerSize: size,
      elementSize: box.size,
    );
    final BoxParentData parentData = box.parentData! as BoxParentData;
    parentData.offset = offset;
  }
}

class _BannerTextChip extends StatelessWidget {
  const _BannerTextChip({
    required this.element,
    required this.bannerHeight,
    required this.bannerWidth,
    required this.selected,
    required this.brandColor,
    this.allowTextBackground = true,
    this.designScale = false,
  });

  final StoreBannerTextElement element;
  final double bannerHeight;
  final double bannerWidth;
  final bool selected;
  final Color brandColor;
  final bool allowTextBackground;
  final bool designScale;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Color(element.textColor);
    final TextAlign align = StoreBannerTextAligns.textAlign(element.textAlign);
    final bool showBackground = allowTextBackground && element.showsBackground;
    final bool lightText = textColor.computeLuminance() > 0.55;
    final bool titleLike =
        element.fontSizePreset == StoreBannerFontSizes.title ||
        element.fontSizePreset == StoreBannerFontSizes.display ||
        element.fontSizePreset == StoreBannerFontSizes.subhead;
    final double fontSize = element.previewFontSize(bannerHeight);
    final Widget label = Text(
      element.hasText ? element.text : '文字',
      maxLines: designScale ? 2 : element.maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize,
        height: designScale ? (titleLike ? 1.15 : 1.3) : 1.15,
        fontWeight: StoreBannerFontWeights.weight(element.fontWeightPreset),
        color: element.hasText ? textColor : textColor.withValues(alpha: 0.45),
        shadows: showBackground
            ? null
            : <Shadow>[
                Shadow(
                  color: lightText
                      ? const Color(0xCC000000)
                      : const Color(0x99FFFFFF),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
    );

    Widget child = label;
    if (showBackground) {
      final Color background = Color(element.backgroundColor).withValues(
        alpha: StoreBannerBgOpacities.opacity(element.backgroundOpacityPreset),
      );
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(
            StoreBannerTextBgStyles.radius(element.backgroundStyle),
          ),
        ),
        child: Padding(
          padding: StoreBannerTextPaddings.insets(element.paddingPreset),
          child: label,
        ),
      );
    }

    final double maxWidth =
        (bannerWidth *
                StoreBannerTextWidthPresets.ratio(element.maxWidthPreset))
            .clamp(
              48.0,
              bannerWidth * (1 - StoreBannerPlacement.safeFraction * 2),
            );
    final bool stretch = align == TextAlign.center;
    Widget body = child;
    if (selected) {
      body = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          child,
          Positioned(
            left: -2,
            top: -2,
            right: -2,
            bottom: -2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: brandColor, width: 1.2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -12,
            child: IgnorePointer(
              child: Text(
                '拖曳',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.1,
                  color: brandColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (stretch) {
      return SizedBox(width: maxWidth, child: body);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: body,
    );
  }
}

class _BannerCtaButton extends StatelessWidget {
  const _BannerCtaButton({
    required this.banner,
    required this.theme,
    required this.onTap,
    this.selected = false,
    this.bannerWidth = 360,
    this.bannerHeight = 203,
    this.designScale = false,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final VoidCallback? onTap;
  final bool selected;
  final double bannerWidth;
  final double bannerHeight;
  final bool designScale;

  @override
  Widget build(BuildContext context) {
    final Color background = banner.resolvedCtaBackground(theme);
    final Color foreground = banner.resolvedCtaForeground(theme);
    final double radius = designScale
        ? StoreBannerFontSizes.scaleDesign(
            StoreBannerCtaRadii.radius(
              banner.ctaRadius,
            ).clamp(8, 28).toDouble(),
            bannerHeight,
          )
        : StoreBannerCtaRadii.radius(banner.ctaRadius);
    final StoreBannerCtaBox posterBox = StoreBannerCtaSizes.box(
      banner.ctaSize,
      scale: banner.ctaScale,
    );
    final double fontSize = designScale
        ? StoreBannerFontSizes.scaleDesign(posterBox.fontPx, bannerHeight)
        : switch (banner.ctaSize) {
            StoreBannerCtaSizes.small => 11,
            StoreBannerCtaSizes.large => 15,
            StoreBannerCtaSizes.extraLarge => 15,
            _ => 13,
          };
    final EdgeInsets padding = designScale
        ? EdgeInsets.symmetric(
            horizontal: StoreBannerFontSizes.scaleDesign(
              posterBox.paddingH,
              bannerHeight,
            ),
            vertical: StoreBannerFontSizes.scaleDesign(
              posterBox.paddingV,
              bannerHeight,
            ),
          )
        : switch (banner.ctaSize) {
            StoreBannerCtaSizes.small => const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 8,
            ),
            StoreBannerCtaSizes.large || StoreBannerCtaSizes.extraLarge =>
              const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            _ => const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          };
    final double minHeight = designScale
        ? StoreBannerFontSizes.scaleDesign(posterBox.minHeight, bannerHeight)
        : 0;
    final double safeWidth =
        bannerWidth * (1 - StoreBannerPlacement.safeFraction * 2);
    final double posterMaxWidth = bannerWidth * 0.70;
    final double maxWidth = designScale
        ? (posterMaxWidth < safeWidth ? posterMaxWidth : safeWidth)
        : 220;
    final String label = banner.ctaShowArrow
        ? '${banner.ctaText.trim()} →'
        : banner.ctaText.trim();
    final Widget caption = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        height: designScale ? 1 : null,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    );
    Widget button = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, minHeight: minHeight),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: designScale
                ? Align(
                    alignment: Alignment.center,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: caption,
                  )
                : caption,
          ),
        ),
      ),
    );
    if (!selected) {
      return button;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        Positioned(
          left: -2,
          top: -2,
          right: -2,
          bottom: -2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.primaryColor, width: 1.2),
                borderRadius: BorderRadius.circular(radius + 3),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -12,
          child: IgnorePointer(
            child: Text(
              '拖曳',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                color: theme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StoreBannerViewCta {
  static Color onColor(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xFF2A221C)
        : const Color(0xFFFFFFFF);
  }
}
