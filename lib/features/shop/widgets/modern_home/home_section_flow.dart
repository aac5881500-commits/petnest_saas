import 'package:flutter/widgets.dart';
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
      Padding(
        padding: EdgeInsets.only(bottom: gap),
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
