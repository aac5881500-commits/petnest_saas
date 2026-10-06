// 檔案名稱：lib/features/shop/widgets/modern_home/modern_home_store_card.dart
// 功能說明：新版首頁「寵物賣場入口卡片」共用 renderer（Preview 與真正首頁同一套）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';

class ModernHomeStoreCard extends StatelessWidget {
  const ModernHomeStoreCard({
    super.key,
    required this.theme,
    required this.setting,
    this.fallbackImageUrl = '',
    this.onTap,
    this.height = 156,
    this.showcaseImageUrls = const <String>[],
    this.previewChrome = false,
  });

  final HomeThemeModel theme;
  final ModernStoreHomeSetting setting;
  final String fallbackImageUrl;
  final VoidCallback? onTap;
  final double height;
  final List<String> showcaseImageUrls;
  final bool previewChrome;

  String get _imageUrl {
    if (setting.storeBannerImageUrl.trim().isNotEmpty) {
      return setting.storeBannerImageUrl.trim();
    }
    return fallbackImageUrl.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (setting.storeEntryLayout == ModernStoreEntryLayouts.brand) {
      return _frame(_brandBody(), key: const Key('store-entry-brand'));
    }
    if (setting.storeEntryLayout == ModernStoreEntryLayouts.showcase) {
      return _frame(_showcaseBody(), key: const Key('store-entry-showcase'));
    }
    return _frame(_bannerBody(), key: const Key('store-entry-banner'));
  }

  Widget _frame(Widget child, {required Key key}) {
    return Material(
      key: key,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _bannerBody() {
    final Color titleColor = ModernStoreCardTextColors.colorOf(
      setting.storeBannerTitleColorPreset,
      theme,
    );
    final Color subtitleColor = ModernStoreCardTextColors.colorOf(
      setting.storeBannerSubtitleColorPreset,
      theme,
    ).withValues(alpha: 0.86);
    final Color buttonBg = ModernStoreCardButtonColors.backgroundOf(
      setting.storeBannerButtonColorPreset,
      theme,
    );
    final Color buttonFg = ModernStoreCardButtonColors.foregroundOf(buttonBg);
    final String imageUrl = _imageUrl;
    final double overlayOpacity = ModernStoreCardOverlays.opacity(
      setting.storeBannerOverlayPreset,
    );
    final Alignment contentAlign = ModernStoreCardPositions.alignment(
      setting.storeBannerContentPosition,
    );
    final TextAlign textAlign = ModernStoreCardPositions.textAlign(
      setting.storeBannerContentPosition,
    );

    final Widget card = SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: theme.cardColor),
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: setting.backgroundBoxFit,
                  alignment: setting.backgroundAlignment,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) {
                    return ColoredBox(
                      color: theme.primaryColor.withValues(alpha: 0.12),
                    );
                  },
                ),
              )
            else
              ColoredBox(color: theme.primaryColor.withValues(alpha: 0.10)),
            if (overlayOpacity > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: ModernStoreCardOverlayTones.colorOf(
                    setting.storeBannerOverlayTone,
                  ).withValues(alpha: overlayOpacity),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Align(
                alignment: contentAlign,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: ModernStoreCardPositions.cross(
                      setting.storeBannerContentPosition,
                    ),
                    children: <Widget>[
                      Text(
                        setting.resolvedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        setting.resolvedSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: buttonBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            setting.resolvedButtonText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: buttonFg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return card;
  }

  Widget _brandBody() {
    final Color titleColor = ModernStoreCardTextColors.colorOf(
      setting.storeBannerTitleColorPreset,
      theme,
    );
    final Color subtitleColor = ModernStoreCardTextColors.colorOf(
      setting.storeBannerSubtitleColorPreset,
      theme,
    ).withValues(alpha: 0.86);
    final double overlayOpacity = ModernStoreCardOverlays.opacity(
      setting.storeBannerOverlayPreset,
    );
    return SizedBox(
      height: height < 180 ? 210 : height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _background(),
            if (overlayOpacity > 0) _overlay(overlayOpacity),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Align(
                alignment: ModernStoreCardPositions.alignment(
                  setting.storeBannerContentPosition,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: ModernStoreCardPositions.cross(
                    setting.storeBannerContentPosition,
                  ),
                  children: <Widget>[
                    Text(
                      setting.resolvedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: ModernStoreCardPositions.textAlign(
                        setting.storeBannerContentPosition,
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      setting.resolvedSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: ModernStoreCardPositions.textAlign(
                        setting.storeBannerContentPosition,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${setting.resolvedButtonText} >',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _showcaseBody() {
    final Color titleColor = ModernStoreCardTextColors.colorOf(
      setting.storeBannerTitleColorPreset,
      theme,
    );
    final Color subtitleColor = ModernStoreCardTextColors.colorOf(
      setting.storeBannerSubtitleColorPreset,
      theme,
    ).withValues(alpha: 0.86);
    final List<String> urls = showcaseImageUrls
        .map((String url) => url.trim())
        .where((String url) => url.isNotEmpty)
        .take(3)
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            setting.resolvedTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            setting.resolvedSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
          ),
          if (urls.isNotEmpty || previewChrome) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: Row(
                children: <Widget>[
                  for (
                    int index = 0;
                    index < (urls.isEmpty ? 3 : urls.length);
                    index++
                  ) ...<Widget>[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: _thumb(urls.isEmpty ? '' : urls[index])),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${setting.resolvedButtonText} >',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: theme.primaryColor.withValues(alpha: 0.08),
        child: url.isEmpty
            ? Icon(
                Icons.shopping_bag_outlined,
                color: theme.primaryColor.withValues(alpha: 0.7),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) {
                  return Icon(
                    Icons.shopping_bag_outlined,
                    color: theme.primaryColor,
                  );
                },
              ),
      ),
    );
  }

  Widget _background() {
    final String imageUrl = _imageUrl;
    if (imageUrl.isEmpty) {
      return ColoredBox(color: theme.primaryColor.withValues(alpha: 0.10));
    }
    return Image.network(
      imageUrl,
      fit: setting.backgroundBoxFit,
      alignment: setting.backgroundAlignment,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) {
        return ColoredBox(color: theme.primaryColor.withValues(alpha: 0.12));
      },
    );
  }

  Widget _overlay(double overlayOpacity) {
    return ColoredBox(
      color: ModernStoreCardOverlayTones.colorOf(
        setting.storeBannerOverlayTone,
      ).withValues(alpha: overlayOpacity),
    );
  }
}
