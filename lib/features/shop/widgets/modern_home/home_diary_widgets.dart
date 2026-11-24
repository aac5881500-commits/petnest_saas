import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/models/home_diary_setting.dart';
import '../../../../core/models/home_theme_model.dart';
import 'home_diary_heading_scope.dart';
import 'home_diary_reference_widgets.dart';
import 'editorial_section_widgets.dart';

class HomeDiaryCover extends StatelessWidget {
  const HomeDiaryCover({
    super.key,
    required this.setting,
    required this.theme,
    required this.imageUrl,
    this.imageProvider,
  });
  final HomeDiarySetting setting;
  final HomeThemeModel theme;
  final String imageUrl;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      setting.coverTitle,
      style: TextStyle(
        fontFamily: setting.fontFamily,
        fontFamilyFallback: const ['NotoSansTC'],
        fontSize: setting.coverTitleSize,
        fontWeight: FontWeight.w800,
        height: 1.45,
        color: theme.textColor,
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setting.coverTag.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              image: setting.showPaper
                  ? DecorationImage(
                      opacity: setting.decorationOpacity,
                      image: const AssetImage(HomeDiarySetting.paperAsset),
                      fit: BoxFit.fill,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                setting.coverTag,
                style: TextStyle(
                  fontFamily: setting.fontFamily,
                  fontFamilyFallback: const ['NotoSansTC'],
                  color: theme.textColor,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        title,
        if (setting.coverSubtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            setting.coverSubtitle,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: setting.refNumber('coverBodySize'),
              height: 1.6,
            ),
          ),
        ],
      ],
    );
    final rawPhoto = ClipRRect(
      borderRadius: BorderRadius.circular(theme.storybook.radius),
      child: AspectRatio(
        aspectRatio: setting.coverLayout == 'banner'
            ? 2
            : setting.coverPhotoAspect,
        child: imageProvider != null
            ? Image(image: imageProvider!, fit: BoxFit.cover)
            : sectionPhoto(imageUrl),
      ),
    );
    final photo =
        setting.refFlag('coverBlend') && setting.coverLayout == 'split'
        ? ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: setting.coverPhotoSide == 'right'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              end: setting.coverPhotoSide == 'right'
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              colors: const [Colors.transparent, Colors.white, Colors.white],
              stops: const [0, .16, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: rawPhoto,
          )
        : rawPhoto;
    return HomeDiaryNote(
      theme: theme,
      flowers: true,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          final stacked =
              setting.coverLayout == 'banner' ||
              box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 23;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                photo,
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: copy,
                ),
              ],
            );
          }
          final photoFlex = (setting.coverPhotoFraction * 100).round();
          final copyWidget = Expanded(
            flex: 100 - photoFlex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: copy,
            ),
          );
          final photoWidget = Expanded(flex: photoFlex, child: photo);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: setting.coverPhotoSide == 'right'
                ? [copyWidget, const SizedBox(width: 10), photoWidget]
                : [photoWidget, const SizedBox(width: 10), copyWidget],
          );
        },
      ),
    );
  }
}

class HomeDiaryChapter extends StatelessWidget {
  const HomeDiaryChapter({
    super.key,
    required this.sectionId,
    required this.setting,
    required this.theme,
    required this.child,
  });
  final String sectionId;
  final HomeDiarySetting setting;
  final HomeThemeModel theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!setting.enabled || !setting.timelineSections.contains(sectionId)) {
      return child;
    }
    final title =
        setting.titles[sectionId] ??
        HomeDiarySetting.sectionLabels[sectionId] ??
        '';
    final surface = setting.surfaces[sectionId] ?? 'plain';
    final color = switch (surface) {
      'blue' => Color(theme.storybook.blueColor),
      'cream' => Color(theme.storybook.paperColor),
      _ => Colors.transparent,
    };
    final decoration = BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(theme.storybook.radius),
      image: surface == 'paper' && setting.showPaper
          ? DecorationImage(
              image: const AssetImage(HomeDiarySetting.paperAsset),
              fit: BoxFit.fill,
              opacity: setting.decorationOpacity,
            )
          : null,
    );
    final headingTape = setting.showTape && setting.refFlag('headingTape');
    final heading = Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: headingTape ? 7 : 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: setting.showPaper
                  ? DecorationImage(
                      image: const AssetImage(HomeDiarySetting.paperAsset),
                      fit: BoxFit.fill,
                      opacity: setting.decorationOpacity,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: setting.headingSize,
                  fontFamily: setting.fontFamily,
                  fontFamilyFallback: const ['NotoSansTC'],
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
            ),
          ),
        ),
        if (headingTape)
          Positioned(
            top: 0,
            left: 2,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: setting.decorationOpacity,
                  child: Image.asset(
                    HomeDiarySetting.tapeAsset,
                    width: 45,
                    height: 17,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return _ChapterLayout(
      setting: setting,
      decoration: decoration,
      inset: surface == 'plain' ? 0 : theme.storybook.padding,
      children: [
        heading,
        HomeDiaryHeadingScope(child: child),
      ],
    );
  }
}

class _ChapterLayout extends MultiChildRenderObjectWidget {
  const _ChapterLayout({
    required this.setting,
    required this.decoration,
    required this.inset,
    required super.children,
  });
  final HomeDiarySetting setting;
  final BoxDecoration decoration;
  final double inset;
  @override
  RenderObject createRenderObject(BuildContext context) => _ChapterRender(
    setting,
    decoration,
    inset,
    createLocalImageConfiguration(context),
  );
  @override
  void updateRenderObject(BuildContext context, _ChapterRender renderObject) =>
      renderObject.update(
        setting,
        decoration,
        inset,
        createLocalImageConfiguration(context),
      );
}

class _ChapterData extends ContainerBoxParentData<RenderBox> {}

class _ChapterRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChapterData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChapterData> {
  _ChapterRender(this.setting, this.decoration, this.inset, this.configuration);
  HomeDiarySetting setting;
  BoxDecoration decoration;
  double inset;
  ImageConfiguration configuration;
  BoxPainter? _painter;
  double get gutter => setting.showTimeline ? setting.gutter : 0;
  void update(
    HomeDiarySetting next,
    BoxDecoration surface,
    double padding,
    ImageConfiguration imageConfiguration,
  ) {
    setting = next;
    decoration = surface;
    inset = padding;
    configuration = imageConfiguration;
    _painter?.dispose();
    _painter = null;
    markNeedsLayout();
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ChapterData) child.parentData = _ChapterData();
  }

  @override
  void performLayout() {
    final body = lastChild!;
    body.layout(
      constraints.deflate(EdgeInsets.only(left: gutter + inset, right: inset)),
      parentUsesSize: true,
    );
    if (body.size.height == 0) {
      firstChild!.layout(
        const BoxConstraints.tightFor(width: 0, height: 0),
        parentUsesSize: true,
      );
      size = constraints.constrain(Size(body.size.width + gutter, 0));
      return;
    }
    final heading = firstChild!;
    heading.layout(
      constraints.deflate(EdgeInsets.only(left: gutter)),
      parentUsesSize: true,
    );
    (heading.parentData! as _ChapterData).offset = Offset(gutter, 0);
    (body.parentData! as _ChapterData).offset = Offset(
      gutter + inset,
      heading.size.height + 6 + inset,
    );
    size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : body.size.width + gutter + inset * 2,
        heading.size.height + 6 + body.size.height + inset * 2 + 8,
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final body = lastChild!.getDryLayout(
      constraints.deflate(EdgeInsets.only(left: gutter + inset, right: inset)),
    );
    if (body.height == 0) {
      return constraints.constrain(Size(body.width + gutter, 0));
    }
    final heading = firstChild!.getDryLayout(
      constraints.deflate(EdgeInsets.only(left: gutter)),
    );
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : body.width + gutter + inset * 2,
        heading.height + 6 + body.height + inset * 2 + 8,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.height == 0 || lastChild!.size.height == 0) return;
    final bodyData = lastChild!.parentData! as _ChapterData;
    final origin = offset + Offset(gutter, firstChild!.size.height + 6);
    final surfaceSize = Size(
      size.width - gutter,
      lastChild!.size.height + inset * 2,
    );
    _painter ??= decoration.createBoxPainter(markNeedsPaint);
    _painter!.paint(
      context.canvas,
      origin,
      configuration.copyWith(size: surfaceSize),
    );
    if (setting.showTimeline) {
      final x = offset.dx + gutter / 2;
      final paint = Paint()
        ..color = Color(setting.lineColor)
        ..strokeWidth = setting.lineWidth;
      context.canvas.drawLine(
        Offset(x, offset.dy),
        Offset(x, offset.dy + size.height),
        paint,
      );
      final center = Offset(x, offset.dy + firstChild!.size.height / 2);
      context.canvas.drawCircle(
        center,
        11,
        Paint()..color = const Color(0xFFFFF6D8),
      );
      if (setting.marker == 'dot') {
        context.canvas.drawCircle(
          center,
          4,
          Paint()..color = Color(setting.lineColor),
        );
      } else {
        final painter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(Icons.pets_rounded.codePoint),
            style: TextStyle(
              fontFamily: Icons.pets_rounded.fontFamily,
              fontSize: 16,
              color: Color(setting.markerColor),
            ),
          ),
        );
        painter.layout();
        painter.paint(
          context.canvas,
          center - Offset(painter.width / 2, painter.height / 2),
        );
        painter.dispose();
      }
    }
    context.paintChild(
      firstChild!,
      offset + (firstChild!.parentData! as _ChapterData).offset,
    );
    // Render objects use parent-data offsets for both painting and hit testing.
    context.paintChild(lastChild!, offset + bodyData.offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }
}

class HomeDiaryEnvironmentRows extends StatelessWidget {
  const HomeDiaryEnvironmentRows({
    super.key,
    required this.items,
    required this.theme,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> items;
  final HomeThemeModel theme;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final setting = theme.storybook.diary;
    return Column(
      children: [
        for (final (index, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: setting.referenceCards
                  ? Colors.transparent
                  : Color(
                      index.isEven
                          ? theme.storybook.paperColor
                          : theme.storybook.blueColor,
                    ),
              borderRadius: BorderRadius.circular(theme.storybook.radius),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(theme.storybook.radius),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final photoImage = ClipRRect(
                      borderRadius: BorderRadius.circular(
                        theme.storybook.radius,
                      ),
                      child: SizedBox(
                        height: setting.environmentPhotoHeight,
                        width: double.infinity,
                        child: sectionPhoto(
                          (item['imageUrl'] ?? '').toString(),
                        ),
                      ),
                    );
                    final photo = Stack(
                      clipBehavior: Clip.none,
                      children: [
                        photoImage,
                        if (setting.showTape && setting.refFlag('photoTape'))
                          Positioned(
                            top: -5,
                            left: index.isEven ? 4 : null,
                            right: index.isEven ? null : 4,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: index.isEven ? -.23 : .23,
                                child: Image.asset(
                                  HomeDiarySetting.tapeAsset,
                                  width: 49,
                                  height: 18,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                    final text = Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['title'] ?? '').toString(),
                            style: TextStyle(
                              fontFamily: setting.fontFamily,
                              fontFamilyFallback: const ['NotoSansTC'],
                              fontWeight: FontWeight.w800,
                              fontSize: setting.refNumber(
                                'environmentTitleSize',
                              ),
                              color: theme.textColor,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (item['description'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: setting.refNumber(
                                'environmentBodySize',
                              ),
                              height: 1.5,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    );
                    if (box.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(14) > 23) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [photo, text],
                      );
                    }
                    final fraction = (setting.environmentPhotoFraction * 100)
                        .round();
                    final photoPart = Expanded(flex: fraction, child: photo);
                    final textPart = Expanded(
                      flex: 100 - fraction,
                      child: text,
                    );
                    return HomeDiaryNote(
                      theme: theme,
                      flowers: true,
                      padding: EdgeInsets.zero,
                      child: Row(
                        children: setting.alternatePhotos && index.isOdd
                            ? [textPart, photoPart]
                            : [photoPart, textPart],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HomeDiaryPreparation extends StatelessWidget {
  const HomeDiaryPreparation({
    super.key,
    required this.policy,
    required this.faq,
  });
  final Widget policy, faq;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(14) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [policy, const SizedBox(height: 8), faq],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: policy),
          const SizedBox(width: 8),
          Expanded(child: faq),
        ],
      );
    },
  );
}

class HomeDiaryCareRibbon extends StatelessWidget {
  const HomeDiaryCareRibbon({
    super.key,
    this.petPhotoUrl = '',
    required this.petNames,
    required this.progressText,
    required this.theme,
    required this.onOpen,
    required this.count,
    required this.completed,
    required this.ready,
  });
  final String petNames, progressText, petPhotoUrl;
  final HomeThemeModel theme;
  final VoidCallback onOpen;
  final int count;
  final Set<int> completed;
  final bool ready;

  @override
  Widget build(BuildContext context) => HomeDiaryNote(
    theme: theme,
    blue: true,
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(theme.storybook.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: LayoutBuilder(
            builder: (context, c) {
              final s = theme.storybook.diary;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.refFlag('careInline'))
                    Wrap(
                      spacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          petNames,
                          style: TextStyle(
                            fontFamily: s.fontFamily,
                            fontFamilyFallback: const ['NotoSansTC'],
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.textColor,
                          ),
                        ),
                        Text(
                          '｜$progressText',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Text(
                      petNames,
                      style: TextStyle(
                        fontFamily: s.fontFamily,
                        fontFamilyFallback: const ['NotoSansTC'],
                        fontSize: 14,
                        color: theme.textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progressText,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                  ],
                  if (ready)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: s.refFlag('careContinuous')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                value: count == 0
                                    ? 0
                                    : completed.length / count,
                                color: theme.primaryColor,
                                backgroundColor: theme.primaryColor.withValues(
                                  alpha: .15,
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                for (int i = 0; i < count; i++)
                                  Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: const EdgeInsets.only(right: 3),
                                      decoration: BoxDecoration(
                                        color: completed.contains(i)
                                            ? theme.primaryColor
                                            : theme.primaryColor.withValues(
                                                alpha: .15,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                ],
              );
              return Row(
                children: [
                  if (s.refFlag('careAvatar') && c.maxWidth > 250) ...[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: petPhotoUrl.isNotEmpty
                            ? sectionPhoto(petPhotoUrl)
                            : Icon(Icons.pets, color: theme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: copy),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: theme.primaryColor,
                    size: 18,
                    semanticLabel: '查看回報',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
