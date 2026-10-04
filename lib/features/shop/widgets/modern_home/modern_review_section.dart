import 'package:flutter/material.dart';
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
  });

  final HomeThemeModel theme;
  final HomeReviewSectionSetting setting;
  final List<ReviewModel> reviews;
  final HomeInfoSectionPhase phase;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (phase == HomeInfoSectionPhase.hidden) {
      return const SizedBox.shrink();
    }
    if (phase == HomeInfoSectionPhase.loading) {
      return _skeleton();
    }
    if (phase == HomeInfoSectionPhase.unavailable ||
        phase == HomeInfoSectionPhase.empty) {
      return ModernReviewSection(
        theme: theme,
        setting: setting,
        reviews: const <ReviewModel>[
          ReviewModel(
            reviewId: 'sample-1',
            shopId: '',
            bookingId: '',
            userId: '',
            customerName: '示意顧客',
            petNames: <String>[],
            roomTypeName: '',
            startDate: null,
            endDate: null,
            nights: 1,
            rating: 5,
            environmentRating: 5,
            serviceRating: 5,
            priceRating: 5,
            content: '示意評價：環境乾淨，照顧很細心。',
            imageUrls: <String>[],
            reply: '謝謝您的回饋',
            replyAt: null,
            replyBy: '',
            status: 'visible',
            createdAt: null,
            updatedAt: null,
          ),
          ReviewModel(
            reviewId: 'sample-2',
            shopId: '',
            bookingId: '',
            userId: '',
            customerName: '示意顧客',
            petNames: <String>[],
            roomTypeName: '',
            startDate: null,
            endDate: null,
            nights: 2,
            rating: 4,
            environmentRating: 4,
            serviceRating: 4,
            priceRating: 4,
            content: '示意評價：接送時間很準。',
            imageUrls: <String>[],
            reply: '',
            replyAt: null,
            replyBy: '',
            status: 'visible',
            createdAt: null,
            updatedAt: null,
          ),
        ],
        phase: HomeInfoSectionPhase.ready,
        onOpen: onOpen,
      );
    }
    final bool empty = reviews.isEmpty;
    return switch (HomeReviewLayouts.migrate(setting.layout)) {
      HomeReviewLayouts.scoreCompact => _score(empty),
      HomeReviewLayouts.featured => _featured(empty),
      HomeReviewLayouts.scoreOverview => _overview(empty),
      HomeReviewLayouts.scoreAndLatest => _scoreAndLatest(empty),
      _ => _carousel(empty),
    };
  }

  Widget _score(bool empty) {
    final String score = empty
        ? '—'
        : homeReviewAverage(reviews).toStringAsFixed(1);
    final String subtitle = empty
        ? kHomeReviewEmptyMessage
        : '$score 分　${reviews.length} 則評價';
    return ModernHomeEntryCard(
      cardKey: const Key('home-review-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: subtitle,
      showSubtitle: true,
      cardSize: 'small',
      surface: 'filled',
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
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
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: theme.textColor,
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
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
                      style: TextStyle(color: theme.secondaryTextColor),
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
                      style: TextStyle(color: theme.secondaryTextColor),
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
          style: TextStyle(
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 4),
        _stars(count == 0 ? 0 : average.round().clamp(0, 5)),
        const SizedBox(height: 4),
        Text(
          '$count 則評價',
          style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.secondaryTextColor,
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
          style: TextStyle(fontSize: 13, height: 1.35, color: theme.textColor),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double allWidth = 78;
            const double gap = 8;
            final double available = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 320;
            final double room = (available - allWidth - gap).clamp(
              120.0,
              280.0,
            );
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
                    return _allCard();
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
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: theme.textColor,
                ),
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allCard() {
    return SizedBox(
      width: 78,
      child: _shell(
        child: InkWell(
          key: const Key('home-review-see-all'),
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.chevron_right_rounded, color: theme.primaryColor),
              const SizedBox(height: 4),
              Text(
                '全部評價',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
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
      style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
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

  Widget _message(String message) {
    final bool wide =
        HomeReviewLayouts.migrate(setting.layout) !=
        HomeReviewLayouts.scoreCompact;
    if (!wide && setting.layout == HomeReviewLayouts.scoreCompact) {
      return _score(true);
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(color: theme.secondaryTextColor, height: 1.35),
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
      color: theme.cardColor,
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
