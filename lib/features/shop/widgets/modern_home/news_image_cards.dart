import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'editorial_section_widgets.dart';

/// Actual announcement data with editable display photos; dots represent real pages.
class NewsImageCards extends StatefulWidget {
  const NewsImageCards({
    super.key,
    required this.items,
    required this.setting,
    required this.theme,
    required this.onOpen,
    this.storeAside,
  });
  final List<HomeNewsItem> items;
  final HomeNewsSectionSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeNewsItem> onOpen;
  final Widget? storeAside;
  @override
  State<NewsImageCards> createState() => _NewsImageCardsState();
}

class _NewsImageCardsState extends State<NewsImageCards> {
  final controller = PageController();
  int page = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String photo(int i) => widget.items[i].imageUrl.isNotEmpty
      ? widget.items[i].imageUrl
      : i.isOdd
      ? widget.setting.secondPhotoUrl
      : widget.setting.photoUrl;
  String date(HomeNewsItem item) =>
      '${item.publishedAt.year}.${item.publishedAt.month.toString().padLeft(2, '0')}.${item.publishedAt.day.toString().padLeft(2, '0')}';
  Widget badge(HomeNewsItem item) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: widget.theme.primaryColor,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      item.isCampaign ? '優惠活動' : '最新公告',
      style: const TextStyle(color: Colors.white, fontSize: 10),
    ),
  );
  Widget card(int i, {bool feature = false}) {
    final item = widget.items[i];
    return InkWell(
      key: ValueKey('news-image-${item.id}'),
      onTap: () => widget.onOpen(item),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: feature
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: .72,
                      heightFactor: 1,
                      child: sectionPhoto(photo(i)),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.theme.backgroundColor,
                          widget.theme.backgroundColor.withValues(alpha: .92),
                          widget.theme.backgroundColor.withValues(alpha: .05),
                        ],
                        stops: const [0, .38, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (widget.setting.showTypeBadge) badge(item),
                            if (widget.setting.showDate)
                              Text(
                                date(item),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: widget.theme.textColor,
                          ),
                        ),
                        if (widget.setting.showSummary) ...[
                          const SizedBox(height: 5),
                          Text(
                            item.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.theme.textColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '閱讀消息 ›',
                          style: TextStyle(
                            color: widget.theme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.theme.cardColor,
                  border: Border.all(color: widget.theme.cardBorderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: sectionPhoto(photo(i))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
                      child: Row(
                        children: [
                          if (widget.setting.showTypeBadge) badge(item),
                          if (widget.setting.showDate) ...[
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                date(item),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: widget.theme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.storeAside ?? const SizedBox.shrink();
    }
    if (widget.setting.layout == HomeNewsLayouts.feature ||
        widget.storeAside != null) {
      return Container(
        height: 204 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2.2),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.theme.primaryColor.withValues(alpha: .3),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              flex: widget.storeAside == null ? 1 : 2,
              child: card(0, feature: true),
            ),
            if (widget.storeAside != null) ...[
              Container(
                width: 1,
                height: 170,
                color: widget.theme.primaryColor.withValues(alpha: .18),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: widget.storeAside!,
                ),
              ),
            ],
          ],
        ),
      );
    }
    final count = (widget.items.length / 2).ceil();
    return Column(
      children: [
        SizedBox(
          height: 190 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
          child: PageView.builder(
            controller: controller,
            itemCount: count,
            onPageChanged: (value) => setState(() => page = value),
            itemBuilder: (_, p) => Row(
              children: [
                for (var n = 0; n < 2; n++) ...[
                  if (n > 0) const SizedBox(width: 10),
                  Expanded(
                    child: p * 2 + n < widget.items.length
                        ? card(p * 2 + n)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (count > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                IconButton(
                  tooltip: '第${i + 1}頁消息',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  icon: Icon(
                    Icons.circle,
                    size: 8,
                    color: widget.theme.primaryColor.withValues(
                      alpha: i == page ? 1 : .25,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
