import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/models/home_storybook_setting.dart';
import '../../../../core/models/home_theme_model.dart';

/// Decorates existing modules and collapses fully when a module has no content.
class HomeStorybookSurface extends StatelessWidget {
  const HomeStorybookSurface({
    super.key,
    required this.setting,
    required this.sectionId,
    required this.child,
  });
  final HomeStorybookSetting setting;
  final String sectionId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!setting.enabled || !setting.decorateSections.contains(sectionId)) {
      return child;
    }
    final blue = setting.blueSections.contains(sectionId);
    return _NonEmptyStorybookSurface(
      padding: EdgeInsets.all(setting.padding),
      decoration: BoxDecoration(
        color: Color(blue ? setting.blueColor : setting.paperColor),
        borderRadius: BorderRadius.circular(setting.radius),
        border: Border.all(color: Color(setting.borderColor)),
        image: setting.decoration == 'flowers'
            ? DecorationImage(
                image: const AssetImage(HomeStorybookSetting.trimAsset),
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
                opacity: setting.decorationOpacity,
              )
            : null,
      ),
      child: child,
    );
  }
}

class _NonEmptyStorybookSurface extends SingleChildRenderObjectWidget {
  const _NonEmptyStorybookSurface({
    required this.padding,
    required this.decoration,
    required super.child,
  });
  final EdgeInsets padding;
  final BoxDecoration decoration;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStorybookSurface(
        padding,
        decoration,
        createLocalImageConfiguration(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStorybookSurface renderObject,
  ) {
    renderObject.update(
      padding,
      decoration,
      createLocalImageConfiguration(context),
    );
  }
}

class _RenderStorybookSurface extends RenderShiftedBox {
  _RenderStorybookSurface(this._padding, this._decoration, this._configuration)
    : super(null);
  EdgeInsets _padding;
  BoxDecoration _decoration;
  ImageConfiguration _configuration;
  BoxPainter? _painter;

  void update(
    EdgeInsets padding,
    BoxDecoration decoration,
    ImageConfiguration configuration,
  ) {
    _padding = padding;
    _decoration = decoration;
    _configuration = configuration;
    _painter?.dispose();
    _painter = null;
    markNeedsLayout();
    markNeedsPaint();
  }

  @override
  void performLayout() {
    child!.layout(constraints.deflate(_padding), parentUsesSize: true);
    size = constraints.constrain(
      Size(
        child!.size.width + _padding.horizontal,
        child!.size.height == 0 ? 0 : child!.size.height + _padding.vertical,
      ),
    );
    (child!.parentData! as BoxParentData).offset = _padding.topLeft;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final content = child!.getDryLayout(constraints.deflate(_padding));
    return constraints.constrain(
      Size(
        content.width + _padding.horizontal,
        content.height == 0 ? 0 : content.height + _padding.vertical,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.height == 0) return;
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    _painter!.paint(
      context.canvas,
      offset,
      _configuration.copyWith(size: size),
    );
    super.paint(context, offset);
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }
}

class HomeStorybookHero extends StatelessWidget {
  const HomeStorybookHero({
    super.key,
    required this.setting,
    required this.theme,
    this.onBook,
  });
  final HomeStorybookSetting setting;
  final HomeThemeModel theme;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final centered = setting.heroAlign == 'center';
    return ClipRRect(
      borderRadius: BorderRadius.circular(setting.radius),
      child: ColoredBox(
        color: Color(setting.paperColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (setting.heroImage == 'cottage')
              AspectRatio(
                aspectRatio: setting.heroAspect,
                child: Image.asset(
                  HomeStorybookSetting.heroAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            Padding(
              padding: EdgeInsets.all(setting.padding + 4),
              child: Column(
                crossAxisAlignment: centered
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    setting.heroTitle,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: setting.titleSize,
                      color: theme.textColor,
                      fontWeight: FontWeight.w800,
                      fontFamily: setting.fontFamily,
                      height: 1.3,
                    ),
                  ),
                  if (setting.heroSubtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      setting.heroSubtitle,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (setting.heroButton.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.buttonBackgroundColor,
                        foregroundColor: theme.buttonForegroundColor,
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onBook,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: Text(setting.heroButton),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeStorybookShortcuts extends StatelessWidget {
  const HomeStorybookShortcuts({
    super.key,
    required this.setting,
    required this.theme,
    required this.items,
    required this.onOpen,
  });
  final HomeStorybookSetting setting;
  final HomeThemeModel theme;
  final List<({String id, String label, IconData icon})> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(14) > 22
          ? 2
          : 4;
      final width = (box.maxWidth - 8 * (columns - 1)) / columns;
      return Padding(
        padding: EdgeInsets.only(top: setting.gap),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, item) in items.indexed)
              SizedBox(
                width: width,
                child: Material(
                  color: Color(
                    index.isEven ? setting.paperColor : setting.blueColor,
                  ),
                  borderRadius: BorderRadius.circular(setting.radius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(setting.radius),
                    onTap: () => onOpen(item.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: Column(
                        children: [
                          Icon(item.icon, color: theme.primaryColor, size: 30),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
