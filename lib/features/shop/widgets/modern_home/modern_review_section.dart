import 'home_card_image.dart';
import 'environment_end_entry.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁顧客評價。正式前台與外觀預覽共用，不再自行查詢 reviews。
class ModernReviewSection extends StatelessWidget {
  const ModernReviewSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.reviews,
    required this.phase,
    required this.onOpen,
    this.displayStyle,
  });

  final HomeThemeModel theme;
  final HomeReviewSectionSetting setting;
  final List<ReviewModel> reviews;
  final HomeInfoSectionPhase phase;
  final VoidCallback onOpen;
  final HomeDisplayStyle? displayStyle;

  TextStyle _look(TextStyle original) {
    final style = displayStyle;
    if (style == null || original.color == theme.primaryColor) return original;
    final title =
        (original.fontSize ?? 14) >= 14 &&
        (original.fontWeight?.value ?? 400) >= 600;
    return original.copyWith(
      fontSize: (original.fontSize ?? 0) >= 24
          ? original.fontSize
          : homeDisplayFontSize(
              title ? style.titleSize : style.bodySize,
              fallback: original.fontSize ?? 13,
            ),
      fontWeight: homeDisplayFontWeight(
        title ? style.titleWeight : style.bodyWeight,
      ),
      color: Color(title ? style.titleColor : style.effectiveBodyColor),
    );
  }

  @override
  Widget build(BuildContext context) => HomeCardImage(
    setting: setting.cardImage,
    enabled: setting.layout == HomeReviewLayouts.scoreCompact,
    builder: (context, image) => DefaultTextStyle.merge(
      textAlign: displayStyle == null
          ? TextAlign.start
          : homeDisplayTextAlign(displayStyle!.bodyAlign),
      child: _content(context, image.url),
    ),
  );

  Widget _content(BuildContext context, String imageUrl) {
    if (phase == HomeInfoSectionPhase.hidden) {
      return const SizedBox.shrink();
    }
    if (phase == HomeInfoSectionPhase.loading) {
      return _skeleton();
    }
    if (phase == HomeInfoSectionPhase.unavailable) return _message('評價暫時無法載入');
    if (phase == HomeInfoSectionPhase.empty) {
      return _message('預覽示意：尚未有公開評價', imageUrl: imageUrl);
    }
    final bool empty = reviews.isEmpty;
    return switch (HomeReviewLayouts.migrate(setting.layout)) {
      HomeReviewLayouts.scoreCompact => _score(empty, imageUrl),
      HomeReviewLayouts.featured => _featured(empty),
      HomeReviewLayouts.scoreOverview => _overview(empty),
      HomeReviewLayouts.scoreAndLatest => _scoreAndLatest(empty),
      _ => _carousel(empty),
    };
  }

  Widget _score(bool empty, String imageUrl) {
    final String score = empty
        ? '—'
        : homeReviewAverage(reviews).toStringAsFixed(1);
    final String subtitle = empty
        ? kHomeReviewEmptyMessage
        : '$score 分　${reviews.length} 則評價';
    return ModernHomeEntryCard(
      displayStyle: displayStyle,
      backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      cardKey: const Key('home-review-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: subtitle,
      showSubtitle: true,
      cardSize: 'small',
      surface: displayStyle?.cardBackground ?? 'filled',
      icon: Icons.star_rounded,
      onTap: onOpen,
    );
  }

  Widget _featured(bool empty) {
    if (empty) {
      return _message(kHomeReviewEmptyMessage);
    }
    final ReviewModel review = reviews.first;
    return _shell(
      child: InkWell(
        key: const Key('home-review-card'),
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                setting.entryTitle,
                textAlign: displayStyle == null
                    ? TextAlign.start
                    : homeDisplayTextAlign(displayStyle!.titleAlign),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _look(
                  TextStyle(
                    fontSize: homeDisplayFontSize(
                      displayStyle?.titleSize ?? HomeDisplaySizes.medium,
                      fallback: 15,
                    ),
                    height: 1.2,
                    fontWeight: homeDisplayFontWeight(
                      displayStyle?.titleWeight ?? HomeDisplayWeights.bold,
                    ),
                    color: displayStyle == null
                        ? theme.textColor
                        : Color(displayStyle!.titleColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _stars(review.rating.clamp(1, 5)),
              const SizedBox(height: 6),
              Text(
                review.content.trim().isEmpty
                    ? '顧客留下了星級評價'
                    : review.content.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _look(
                  TextStyle(
                    fontSize: homeDisplayFontSize(
                      displayStyle?.bodySize ?? HomeDisplaySizes.small,
                      fallback: 13,
                    ),
                    height: 1.35,
                    fontWeight: homeDisplayFontWeight(
                      displayStyle?.bodyWeight ?? HomeDisplayWeights.medium,
                    ),
                    color: displayStyle == null
                        ? theme.textColor
                        : Color(displayStyle!.effectiveBodyColor),
                  ),
                ),
              ),
              if (setting.showImages && review.imageUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _thumb(review.imageUrls.first),
                ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(child: _meta(review)),
                  if (setting.showReplyBadge && review.hasReply)
                    Text(
                      '店家已回覆',
                      style: _look(
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              if (setting.showViewAll)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('home-review-see-all'),
                    onPressed: onOpen,
                    child: const Text('全部評價'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview(bool empty) {
    final double average = empty ? 0 : homeReviewAverage(reviews);
    return _shell(
      child: InkWell(
        key: const Key('home-review-card'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget score = _scoreBlock(
                average,
                empty ? 0 : reviews.length,
              );
              final Widget bars = empty
                  ? Text(
                      kHomeReviewEmptyMessage,
                      style: _look(TextStyle(color: theme.secondaryTextColor)),
                    )
                  : _bars();
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[score, const SizedBox(height: 10), bars],
                );
              }
              return Row(
                children: <Widget>[
                  score,
                  const SizedBox(width: 16),
                  Expanded(child: bars),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _scoreAndLatest(bool empty) {
    return _shell(
      child: InkWell(
        key: const Key('home-review-card'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget score = _scoreBlock(
                empty ? 0 : homeReviewAverage(reviews),
                empty ? 0 : reviews.length,
              );
              final Widget latest = empty
                  ? Text(
                      kHomeReviewEmptyMessage,
                      style: _look(TextStyle(color: theme.secondaryTextColor)),
                    )
                  : _latestCopy(reviews.first);
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[score, const SizedBox(height: 10), latest],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  score,
                  const SizedBox(width: 12),
                  Expanded(child: latest),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _scoreBlock(double average, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          count == 0 ? '—' : average.toStringAsFixed(1),
          style: _look(
            TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w900,
              color: theme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _stars(count == 0 ? 0 : average.round().clamp(0, 5)),
        const SizedBox(height: 4),
        Text(
          '$count 則評價',
          style: _look(
            TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
        ),
      ],
    );
  }

  Widget _bars() {
    return Column(
      children: <Widget>[
        for (int star = 5; star >= 1; star--)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 16,
                  child: Text(
                    '$star',
                    style: _look(
                      TextStyle(fontSize: 11, color: theme.secondaryTextColor),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: reviews.isEmpty
                          ? 0
                          : reviews
                                    .where(
                                      (ReviewModel item) => item.rating == star,
                                    )
                                    .length /
                                reviews.length,
                      backgroundColor: theme.cardBorderColor,
                      color: const Color(0xFFFFB300),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _latestCopy(ReviewModel review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          review.content.trim().isEmpty ? '顧客留下了星級評價' : review.content.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _look(
            TextStyle(fontSize: 13, height: 1.35, color: theme.textColor),
          ),
        ),
        const SizedBox(height: 6),
        _meta(review),
        if (setting.showImages && review.imageUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _thumb(review.imageUrls.first),
          ),
      ],
    );
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 44,
          height: 44,
          color: theme.cardBorderColor,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: theme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _carousel(bool empty) {
    if (empty) {
      return _message(kHomeReviewEmptyMessage);
    }
    final int count = HomeReviewSectionSetting.migrateCarouselCount(
      setting.carouselCount,
    );
    final List<ReviewModel> preview = reviews.take(count).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          setting.entryTitle,
          textAlign: displayStyle == null
              ? TextAlign.start
              : homeDisplayTextAlign(displayStyle!.titleAlign),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _look(
            TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 8;
            final double available = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 320;
            final double room = (available * .7).clamp(120.0, 280.0);
            final double cardWidth = preview.length == 1
                ? room
                : (205.0 > room ? room : 205.0);
            return SizedBox(
              key: const Key('home-review-card'),
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: preview.length + (setting.showViewAll ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (BuildContext context, int index) {
                  if (index == preview.length) {
                    return Center(
                      widthFactor: 1,
                      child: EnvironmentEndEntry(
                        key: const Key('home-review-see-all'),
                        style: setting.endEntryStyle,
                        color: theme.primaryColor,
                        label: '全部評價',
                        semanticLabel: '全部評價',
                        onPressed: onOpen,
                      ),
                    );
                  }
                  return _reviewCard(preview[index], width: cardWidth);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _reviewCard(ReviewModel review, {required double width}) {
    final String name = review.customerName.trim().isEmpty
        ? '匿名顧客'
        : review.customerName.trim();
    final String content = review.content.trim().isEmpty
        ? '顧客留下了星級評價'
        : review.content.trim();
    return SizedBox(
      width: width,
      child: _shell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _stars(review.rating.clamp(1, 5), compact: true),
              const SizedBox(height: 4),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _look(
                  TextStyle(fontSize: 12, height: 1.25, color: theme.textColor),
                ),
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _look(
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(ReviewModel review) {
    final String name = !setting.showCustomerName
        ? ''
        : review.customerName.trim().isEmpty
        ? '匿名顧客'
        : review.customerName.trim();
    final String date = setting.showDate
        ? _date(review.createdAt?.toDate())
        : '';
    final String text = <String>[
      name,
      date,
    ].where((String item) => item.isNotEmpty).join('　');
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _look(TextStyle(fontSize: 12, color: theme.secondaryTextColor)),
    );
  }

  Widget _stars(int rating, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < 5; index++)
          Icon(
            index < rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: compact ? 13 : 16,
            color: const Color(0xFFFFB300),
          ),
      ],
    );
  }

  Widget _message(String message, {String imageUrl = ''}) {
    final bool wide =
        HomeReviewLayouts.migrate(setting.layout) !=
        HomeReviewLayouts.scoreCompact;
    if (!wide && setting.layout == HomeReviewLayouts.scoreCompact) {
      return _score(true, imageUrl);
    }
    return _shell(
      child: SizedBox(
        key: const Key('home-review-card'),
        height:
            HomeReviewLayouts.migrate(setting.layout) ==
                HomeReviewLayouts.carousel
            ? 112
            : null,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                setting.entryTitle,
                textAlign: displayStyle == null
                    ? TextAlign.start
                    : homeDisplayTextAlign(displayStyle!.titleAlign),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _look(
                  TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: _look(
                  TextStyle(color: theme.secondaryTextColor, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeleton() {
    final double height = switch (HomeReviewLayouts.migrate(setting.layout)) {
      HomeReviewLayouts.scoreCompact => kModernHomeSmallCardHeight,
      HomeReviewLayouts.featured => 148,
      _ => 132,
    };
    return SizedBox(
      key: const Key('home-review-skeleton'),
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Material(
      color: displayStyle?.cardBackground == HomeDisplayBackgrounds.transparent
          ? Colors.transparent
          : displayStyle?.cardBackground == HomeDisplayBackgrounds.outlined
          ? Colors.transparent
          : theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: child,
      ),
    );
  }

  String _date(DateTime? time) {
    if (time == null) {
      return '';
    }
    final DateTime local = time.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day';
  }
}
