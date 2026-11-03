import 'environment_end_entry.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/review_model.dart';

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

  TextStyle get body => TextStyle(
    fontSize: HomeReviewSectionSetting.fontSize(setting.textSize).toDouble(),
    color: displayStyle == null
        ? theme.textColor
        : Color(displayStyle!.effectiveBodyColor),
    height: 1.5,
  );
  List<ReviewModel> get items => sortPublicReviews(reviews);
  String get score =>
      items.isEmpty ? '—' : homeReviewAverage(items).toStringAsFixed(1);
  String get summary => items.isEmpty
      ? kHomeReviewEmptyMessage
      : '$score / 5 · ${items.length} 則';
  String text(ReviewModel r) =>
      r.content.trim().isEmpty ? '顧客留下了星級評價' : r.content.trim();

  @override
  Widget build(BuildContext context) {
    if (phase == HomeInfoSectionPhase.hidden) return const SizedBox.shrink();
    if (setting.isMini) return _mini();
    if (phase == HomeInfoSectionPhase.loading) {
      return SizedBox(
        key: const Key('home-review-skeleton'),
        height: 100,
        child: Center(
          child: TextButton(
            onPressed: onOpen,
            child: const Text('評價載入中 · 查看全部評價 ›'),
          ),
        ),
      );
    }
    return Container(
      key: const Key('home-review-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                setting.entryTitle,
                style: body.copyWith(
                  fontSize: homeDisplayFontSize(
                    displayStyle?.titleSize ?? HomeDisplaySizes.medium,
                    fallback: 16,
                  ),
                  color: displayStyle == null
                      ? theme.textColor
                      : Color(displayStyle!.titleColor),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                key: const Key('home-review-see-all'),
                onPressed: onOpen,
                child: const Text('查看全部評價 ›'),
              ),
            ],
          ),
          if (setting.entrySubtitle.isNotEmpty)
            Text(
              setting.entrySubtitle,
              style: body.copyWith(
                fontSize: 12,
                color: theme.secondaryTextColor,
              ),
            ),
          const SizedBox(height: 8),
          if (phase == HomeInfoSectionPhase.unavailable)
            Text('評價暫時無法載入', style: body)
          else if (items.isEmpty)
            Text(
              phase == HomeInfoSectionPhase.empty
                  ? '預覽示意：尚未有公開評價'
                  : kHomeReviewEmptyMessage,
              style: body,
            )
          else ...[
            if (setting.layout != HomeReviewLayouts.featured)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '★ $summary',
                  style: body.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            switch (HomeReviewLayouts.migrate(setting.layout)) {
              HomeReviewLayouts.scoreCompact => _review(
                items.first,
                maxLines: HomeReviewSectionSetting.lines(setting.contentLines),
              ),
              HomeReviewLayouts.featured => _hero(),
              HomeReviewLayouts.scoreOverview => _wall(),
              HomeReviewLayouts.scoreAndLatest => _long(),
              _ => _photos(),
            },
          ],
        ],
      ),
    );
  }

  Widget _mini() => Material(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      key: const Key('home-review-mini'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          phase == HomeInfoSectionPhase.loading
              ? '★ 評價載入中 ›'
              : phase == HomeInfoSectionPhase.unavailable
              ? '★ 查看住宿評價 ›'
              : '★ $summary ›',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ),
    ),
  );

  Widget _stars(int rating) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (int i = 0; i < 5; i++)
        Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 15,
          color: theme.primaryColor,
        ),
    ],
  );
  Widget _meta(ReviewModel r) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (setting.showCustomerName)
        Text(
          r.customerName.trim().isEmpty ? '匿名顧客' : r.customerName,
          style: body.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      if (setting.showDate && r.createdAt != null)
        Text(
          r.createdAt!.toDate().toLocal().toIso8601String().split('T').first,
          style: body.copyWith(fontSize: 11, color: theme.secondaryTextColor),
        ),
    ],
  );
  Widget _review(ReviewModel r, {int? maxLines, bool reply = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stars(r.rating),
      const SizedBox(height: 6),
      _meta(r),
      const SizedBox(height: 6),
      Text(
        text(r),
        maxLines:
            maxLines ?? HomeReviewSectionSetting.lines(setting.contentLines),
        overflow: TextOverflow.ellipsis,
        style: body,
      ),
      if (setting.showReplyBadge && r.hasReply)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: reply
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '店家回覆：\n${r.reply}',
                    maxLines: HomeReviewSectionSetting.lines(
                      setting.contentLines,
                    ),
                    overflow: TextOverflow.ellipsis,
                    style: body.copyWith(fontSize: 12),
                  ),
                )
              : Text(
                  '店家已回覆',
                  style: body.copyWith(fontSize: 11, color: theme.primaryColor),
                ),
        ),
    ],
  );
  Widget _hero() {
    final r = items.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [theme.cardColor, theme.primaryColor.withValues(alpha: .16)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score,
            style: TextStyle(
              fontSize: 56,
              height: 1.1,
              color: theme.primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text('${items.length} 則住宿評價', style: body.copyWith(fontSize: 12)),
          const SizedBox(height: 12),
          _stars(r.rating),
          if (setting.showImages && r.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _image(r.imageUrls.first, 150),
            ),
          const SizedBox(height: 10),
          Text(
            '「${text(r)}」',
            maxLines: HomeReviewSectionSetting.lines(setting.contentLines),
            overflow: TextOverflow.ellipsis,
            style: body.copyWith(
              fontSize:
                  HomeReviewSectionSetting.fontSize(setting.textSize) + 8.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _meta(r),
          if (setting.showReplyBadge && r.hasReply)
            Text(
              '店家已回覆',
              style: body.copyWith(fontSize: 11, color: theme.primaryColor),
            ),
        ],
      ),
    );
  }

  Widget _wall() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 280 ? 1 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final r in items.take(setting.carouselCount))
            SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: _review(r),
              ),
            ),
        ],
      );
    },
  );
  Widget _long() => Column(
    children: [
      for (final r in items.take(setting.carouselCount)) ...[
        _review(r, reply: true),
        Divider(height: 26, color: theme.cardBorderColor),
      ],
    ],
  );
  Widget _image(String url, double height) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stack) => SizedBox(
        height: height,
        child: Center(child: Icon(Icons.pets, color: theme.primaryColor)),
      ),
    ),
  );
  Widget _photos() => LayoutBuilder(
    builder: (context, constraints) {
      final preview = items
          .take(
            HomeReviewSectionSetting.migrateCarouselCount(
              setting.carouselCount,
            ),
          )
          .toList();
      final hasPhoto =
          setting.showImages && preview.any((r) => r.imageUrls.isNotEmpty);
      final lines = HomeReviewSectionSetting.lines(setting.contentLines);
      return SizedBox(
        height:
            (hasPhoto ? 160 : 0) +
            130 +
            lines *
                HomeReviewSectionSetting.fontSize(setting.textSize) *
                1.8 *
                MediaQuery.textScalerOf(context).scale(1),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: preview.length + 1,
          separatorBuilder: (_, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            if (index == preview.length) {
              return Center(
                child: EnvironmentEndEntry(
                  style: setting.endEntryStyle,
                  color: theme.primaryColor,
                  label: '全部評價',
                  semanticLabel: '全部評價',
                  onPressed: onOpen,
                ),
              );
            }
            final r = preview[index];
            return SizedBox(
              width: (constraints.maxWidth * .8).clamp(150.0, 300.0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border.all(color: theme.cardBorderColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (setting.showImages && r.imageUrls.isNotEmpty) ...[
                      _image(r.imageUrls.first, 150),
                      const SizedBox(height: 10),
                    ],
                    _review(r),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
