import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';

/// 預覽與正式前台共用的區塊間距。落在 8～12px。
const double kHomeSectionGap = 10;

/// 把排好的列畫成上下排列；相鄰 half 左右並排，單獨 half 維持半寬。
List<Widget> buildHomeSectionRows({
  required List<String> sectionIds,
  required HomeSectionSpan Function(String sectionId) spanOf,
  required Widget Function(String sectionId) itemBuilder,
  double gap = kHomeSectionGap,
}) {
  return <Widget>[
    for (final HomeSectionRow row in packHomeSections(sectionIds, spanOf))
      _NonEmptySectionGap(
        gap: gap,
        child: row.span == HomeSectionSpan.full
            ? Row(
                children: <Widget>[
                  Expanded(child: itemBuilder(row.sectionIds.single)),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < row.sectionIds.length;
                    index++
                  ) ...<Widget>[
                    if (index > 0) SizedBox(width: gap),
                    Expanded(child: itemBuilder(row.sectionIds[index])),
                  ],
                  if (!row.isPair) ...<Widget>[
                    SizedBox(width: gap),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
      ),
  ];
}

// Async sections without content should collapse their spacing as well.
class _NonEmptySectionGap extends SingleChildRenderObjectWidget {
  const _NonEmptySectionGap({required this.gap, required super.child});
  final double gap;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSectionGap(gap);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSectionGap renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class _RenderSectionGap extends RenderProxyBox {
  _RenderSectionGap(this._gap);
  double _gap;
  set gap(double value) {
    if (_gap != value) {
      _gap = value;
      markNeedsLayout();
    }
  }

  Size _withGap(Size value, BoxConstraints constraints) =>
      constraints.constrain(
        Size(value.width, value.height == 0 ? 0 : value.height + _gap),
      );
  @override
  void performLayout() {
    super.performLayout();
    size = _withGap(size, constraints);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _withGap(super.computeDryLayout(constraints), constraints);
}
