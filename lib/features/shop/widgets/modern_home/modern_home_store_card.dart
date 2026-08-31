// lib/features/shop/widgets/modern_home/modern_home_store_card.dart
// 🛒 新版首頁「寵物賣場入口卡片」共用 renderer（Preview 與真正首頁同一套）

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
    this.height = 132,
  });

  final HomeThemeModel theme;
  final ModernStoreHomeSetting setting;
  final String fallbackImageUrl;
  final VoidCallback? onTap;
  final double height;

  String get _imageUrl {
    if (setting.storeBannerImageUrl.trim().isNotEmpty) {
      return setting.storeBannerImageUrl.trim();
    }
    return fallbackImageUrl.trim();
  }

  @override
  Widget build(BuildContext context) {
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

    return Material(
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
          child: card,
        ),
      ),
    );
  }
}
