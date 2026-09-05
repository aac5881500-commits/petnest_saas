// 檔案名稱：lib/features/shop/widgets/store/store_banner_view.dart
// 功能說明：商城海報 renderer：後台 Preview 與前台共用，效果只 overlay、不改原圖。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    this.onTap,
    this.borderRadius = 18,
    this.scope = PetNestBannerScope.store,
    this.sizePresetOverride,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final StoreBannerInteractMode interactMode;
  final String? selectedTextId;
  final ValueChanged<StoreBannerModel>? onChanged;
  final ValueChanged<String?>? onTextSelected;
  final VoidCallback? onTap;
  final double borderRadius;
  final PetNestBannerScope scope;
  final String? sizePresetOverride;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double rawHeight = StoreBannerSizePresets.heightForWidth(
            sizePresetOverride ?? banner.sizePreset,
            width,
            scope: scope,
          );
          final double height;
          if (scope == PetNestBannerScope.home &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight > 0) {
            height = constraints.maxHeight;
          } else if (constraints.maxHeight.isFinite) {
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
                onTap: onTap,
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
    required this.onTap,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final double width;
  final double height;
  final StoreBannerInteractMode interactMode;
  final String? selectedTextId;
  final ValueChanged<StoreBannerModel>? onChanged;
  final ValueChanged<String?>? onTextSelected;
  final VoidCallback? onTap;

  bool get _editing => interactMode != StoreBannerInteractMode.none;

  @override
  Widget build(BuildContext context) {
    final Size bannerSize = Size(width, height);
    final Widget image = _BannerImage(banner: banner, theme: theme);
    final List<StoreBannerTextElement> texts = banner.resolvedTextElements;
    final Widget stack = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (interactMode == StoreBannerInteractMode.image)
          _EagerPanDetector(
            onUpdate: _dragImage,
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
              selected: interactMode == StoreBannerInteractMode.cta,
              onSelect: null,
              onMoved: _commitCta,
              child: _BannerCtaButton(
                banner: banner,
                theme: theme,
                onTap: null,
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

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.banner, required this.theme});

  final StoreBannerModel banner;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    if (!banner.hasImage) {
      return ColoredBox(
        color: theme.cardColor,
        child: Icon(Icons.image_outlined, color: theme.primaryColor),
      );
    }
    return ColoredBox(
      color: theme.cardColor,
      child: ClipRect(
        child: Transform.scale(
          scale: banner.imageScale.clamp(1.0, 2.5),
          alignment: banner.imageAlignment,
          child: Image.network(
            banner.imageUrl,
            fit: BoxFit.cover,
            alignment: banner.imageAlignment,
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

  void _applyDelta(Offset delta) {
    if (_elementSize == Size.zero ||
        widget.bannerSize.width <= 0 ||
        widget.bannerSize.height <= 0) {
      return;
    }
    final Offset current = StoreBannerPlacement.offsetOf(
      positionX: _x,
      positionY: _y,
      bannerSize: widget.bannerSize,
      elementSize: _elementSize,
    );
    final Offset next = StoreBannerPlacement.normalize(
      actual: StoreBannerPlacement.clampActual(
        actual: current + delta,
        bannerSize: widget.bannerSize,
        elementSize: _elementSize,
      ),
      bannerSize: widget.bannerSize,
      elementSize: _elementSize,
    );
    setState(() {
      _x = next.dx;
      _y = next.dy;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (_dragging) {
      content = Opacity(opacity: widget.selected ? 0.95 : 0.92, child: content);
    }
    if (widget.enabled) {
      content = _EagerPanDetector(
        onStart: () {
          _dragging = true;
          widget.onSelect?.call();
        },
        onUpdate: _applyDelta,
        onEnd: () {
          _dragging = false;
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
  final VoidCallback? onStart;
  final ValueChanged<Offset>? onUpdate;
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
                instance.onStart = (_) => onStart?.call();
                instance.onUpdate = (DragUpdateDetails details) {
                  onUpdate?.call(details.delta);
                };
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
    box.layout(
      BoxConstraints(
        maxWidth: (size.width - StoreBannerPlacement.padX * 2).clamp(
          48.0,
          size.width,
        ),
        maxHeight: (size.height - StoreBannerPlacement.padY * 2).clamp(
          24.0,
          size.height,
        ),
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
  });

  final StoreBannerTextElement element;
  final double bannerHeight;
  final double bannerWidth;
  final bool selected;
  final Color brandColor;
  final bool allowTextBackground;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Color(element.textColor);
    final TextAlign align = StoreBannerTextAligns.textAlign(element.textAlign);
    final bool showBackground = allowTextBackground && element.showsBackground;
    final bool lightText = textColor.computeLuminance() > 0.55;
    final Widget label = Text(
      element.hasText ? element.text : '文字',
      maxLines: element.maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        fontSize: element.resolvedFontSize(bannerHeight),
        height: 1.15,
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

    if (selected) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: brandColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(padding: const EdgeInsets.all(3), child: child),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth:
            (bannerWidth *
                    StoreBannerTextWidthPresets.ratio(element.maxWidthPreset))
                .clamp(72.0, bannerWidth - 32),
      ),
      child: child,
    );
  }
}

class _BannerCtaButton extends StatelessWidget {
  const _BannerCtaButton({
    required this.banner,
    required this.theme,
    required this.onTap,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = banner.resolvedCtaBackground(theme);
    final Color foreground = banner.resolvedCtaForeground(theme);
    final double radius = StoreBannerCtaRadii.radius(banner.ctaRadius);
    final EdgeInsets padding = switch (banner.ctaSize) {
      StoreBannerCtaSizes.small => const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      StoreBannerCtaSizes.large => const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 9,
      ),
      _ => const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    };
    final double fontSize = switch (banner.ctaSize) {
      StoreBannerCtaSizes.small => 11,
      StoreBannerCtaSizes.large => 15,
      _ => 13,
    };
    final String label = banner.ctaShowArrow
        ? '${banner.ctaText.trim()} →'
        : banner.ctaText.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
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
