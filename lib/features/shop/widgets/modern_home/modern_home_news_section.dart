import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁最新消息。正式前台與外觀預覽共用。
class ModernHomeNewsSection extends StatelessWidget {
  const ModernHomeNewsSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.items,
    required this.phase,
    required this.preview,
    required this.onOpen,
  });

  final HomeThemeModel theme;
  final HomeNewsSectionSetting setting;
  final List<HomeNewsItem> items;
  final HomeNewsSectionPhase phase;
  final bool preview;
  final ValueChanged<ShopAnnouncementSection> onOpen;

  @override
  Widget build(BuildContext context) {
    if (phase == HomeNewsSectionPhase.hidden) {
      return const SizedBox.shrink();
    }
    if (phase == HomeNewsSectionPhase.loading) {
      return _skeleton();
    }
    if (phase == HomeNewsSectionPhase.unavailable) {
      return _messageCard(kHomeNewsErrorMessage);
    }
    if (phase == HomeNewsSectionPhase.empty || items.isEmpty) {
      return _messageCard(kHomeNewsEmptyMessage);
    }
    return switch (HomeNewsLayouts.migrate(setting.layout)) {
      HomeNewsLayouts.compactCard => _compact(items.first),
      HomeNewsLayouts.multiLine => _multi(),
      _ => _single(items.first),
    };
  }

  void _open(ShopAnnouncementSection section) {
    if (preview) {
      return;
    }
    onOpen(section);
  }

  ShopAnnouncementSection _sectionFor(HomeNewsItem item) {
    return item.isCampaign
        ? ShopAnnouncementSection.campaigns
        : ShopAnnouncementSection.notices;
  }

  ShopAnnouncementSection get _seeAllSection {
    return HomeNewsSources.migrate(setting.source) == HomeNewsSources.campaigns
        ? ShopAnnouncementSection.campaigns
        : ShopAnnouncementSection.notices;
  }

  Widget _compact(HomeNewsItem item) {
    return ModernHomeEntryCard(
      cardKey: const Key('home-news-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: item.title,
      showSubtitle: true,
      cardSize: 'small',
      surface: HomeNewsSurfaces.entrySurface(setting.surfaceStyle),
      icon: homeNewsIcon(item.iconType),
      showArrow: false,
      textAlign: _textAlign,
      onTap: () => _open(_sectionFor(item)),
    );
  }

  Widget _single(HomeNewsItem item) {
    return ModernHomeEntryCard(
      cardKey: const Key('home-news-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: item.title,
      showSubtitle: true,
      cardSize: 'wide',
      surface: HomeNewsSurfaces.entrySurface(setting.surfaceStyle),
      icon: homeNewsIcon(item.iconType),
      showArrow: setting.showArrow,
      textAlign: _textAlign,
      onTap: () => _open(_sectionFor(item)),
    );
  }

  Widget _multi() {
    final int count = HomeNewsSectionSetting.migrateCount(
      setting.multiLineCount,
    );
    final List<HomeNewsItem> visible = items.take(count).toList();
    final double rowHeight = _rowHeight;
    return _shell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: _crossAlign,
          children: <Widget>[
            Text(
              setting.entryTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            for (final HomeNewsItem item in visible)
              SizedBox(
                height: rowHeight,
                width: double.infinity,
                child: InkWell(
                  key: Key('home-news-item-${item.id}'),
                  onTap: () => _open(_sectionFor(item)),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        homeNewsIcon(item.iconType),
                        size: 20,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _rowCopy(item)),
                    ],
                  ),
                ),
              ),
            if (setting.showArrow)
              Align(
                alignment: _textAlign == TextAlign.center
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: TextButton(
                  key: const Key('home-news-see-all'),
                  onPressed: () => _open(_seeAllSection),
                  child: const Text('查看全部'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rowCopy(HomeNewsItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: _crossAlign,
      children: <Widget>[
        if (setting.showTypeBadge)
          Text(
            homeNewsBadge(item.iconType),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: _textAlign,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: theme.primaryColor,
            ),
          ),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: _textAlign,
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        if (setting.showSummary && item.summary.isNotEmpty)
          Text(
            item.summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: _textAlign,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: theme.secondaryTextColor,
            ),
          ),
        if (setting.showDate)
          Text(
            _date(item.publishedAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: _textAlign,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: theme.secondaryTextColor,
            ),
          ),
      ],
    );
  }

  double get _rowHeight {
    double height = 28;
    if (setting.showTypeBadge) {
      height += 14;
    }
    if (setting.showSummary) {
      height += 16;
    }
    if (setting.showDate) {
      height += 14;
    }
    return height;
  }

  Widget _messageCard(String message) {
    final String layout = HomeNewsLayouts.migrate(setting.layout);
    if (layout == HomeNewsLayouts.multiLine) {
      return _shell(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            message,
            key: const Key('home-news-card'),
            textAlign: _textAlign,
            style: TextStyle(color: theme.secondaryTextColor, height: 1.35),
          ),
        ),
      );
    }
    return ModernHomeEntryCard(
      cardKey: const Key('home-news-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: message,
      showSubtitle: true,
      cardSize: layout == HomeNewsLayouts.compactCard ? 'small' : 'wide',
      surface: HomeNewsSurfaces.entrySurface(setting.surfaceStyle),
      icon: Icons.campaign_outlined,
      showArrow: false,
      textAlign: _textAlign,
      onTap: () {},
    );
  }

  Widget _skeleton() {
    final double height = switch (HomeNewsLayouts.migrate(setting.layout)) {
      HomeNewsLayouts.compactCard => kModernHomeSmallCardHeight,
      HomeNewsLayouts.multiLine => 148,
      _ => kModernHomeWideCardHeight,
    };
    return SizedBox(
      key: const Key('home-news-skeleton'),
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
    final String surface = HomeNewsSurfaces.migrate(setting.surfaceStyle);
    final Color fill = switch (surface) {
      HomeNewsSurfaces.transparent => Colors.transparent,
      HomeNewsSurfaces.translucent => theme.cardColor.withValues(alpha: 0.55),
      _ => theme.cardColor,
    };
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: surface == HomeNewsSurfaces.transparent
              ? null
              : Border.all(color: theme.cardBorderColor),
        ),
        child: child,
      ),
    );
  }

  TextAlign get _textAlign {
    return setting.textAlign == HomeNewsTextAligns.center
        ? TextAlign.center
        : TextAlign.start;
  }

  CrossAxisAlignment get _crossAlign {
    return _textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
  }

  String _date(DateTime time) {
    final DateTime local = time.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day';
  }
}

IconData homeNewsIcon(String iconType) {
  switch (iconType) {
    case 'important':
      return Icons.priority_high_rounded;
    case 'business_hours':
      return Icons.schedule_rounded;
    case 'promotion':
      return Icons.card_giftcard_outlined;
    case 'checkin_notice':
      return Icons.pets_outlined;
    case HomeNewsIconTypes.campaign:
      return Icons.local_offer_outlined;
    default:
      return Icons.campaign_outlined;
  }
}

String homeNewsBadge(String iconType) {
  switch (iconType) {
    case 'important':
      return '重要';
    case 'business_hours':
      return '營業';
    case 'promotion':
      return '店內公告';
    case 'checkin_notice':
      return '入住';
    case HomeNewsIconTypes.campaign:
      return '優惠';
    default:
      return '公告';
  }
}
