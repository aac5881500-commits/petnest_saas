// lib/features/shop/widgets/modern_home/modern_home_banner_carousel.dart
// 新版 Beta 首頁活動海報輪播。
// 自己管理 PageController / 目前頁碼，切換時不重建整頁。

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_text_style_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';

class ModernHomeBannerCarousel extends StatefulWidget {
  const ModernHomeBannerCarousel({
    super.key,
    required this.banners,
    required this.theme,
    required this.frameSetting,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.bannerTitleStyle,
    required this.bannerSubtitleStyle,
    required this.bannerButtonText,
    required this.bannerButtonColor,
    required this.bannerButtonTextColor,
    required this.onBookingPressed,
    required this.reviewBadge,
  });

  final List<Map<String, dynamic>> banners;
  final HomeThemeModel theme;
  final ModernBannerFrameSetting frameSetting;
  final String bannerTitle;
  final String bannerSubtitle;
  final HomeTextStyleModel bannerTitleStyle;
  final HomeTextStyleModel bannerSubtitleStyle;
  final String bannerButtonText;
  final Color bannerButtonColor;
  final Color bannerButtonTextColor;
  final VoidCallback onBookingPressed;
  final Widget reviewBadge;

  @override
  State<ModernHomeBannerCarousel> createState() =>
      _ModernHomeBannerCarouselState();
}

class _ModernHomeBannerCarouselState extends State<ModernHomeBannerCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  List<Map<String, dynamic>> get _banners => widget.banners;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheNearbyBanners();
    });
  }

  @override
  void didUpdateWidget(ModernHomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_banners.isEmpty) {
      if (_currentIndex != 0) {
        _currentIndex = 0;
      }
      return;
    }
    if (_currentIndex >= _banners.length) {
      _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
    _precacheNearbyBanners();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(Map<String, dynamic> banner) {
    final String cropped = (banner['croppedImageUrl'] ?? '').toString().trim();
    if (cropped.isNotEmpty) {
      return cropped;
    }
    return (banner['imageUrl'] ?? '').toString().trim();
  }

  String _slideKey(Map<String, dynamic> banner, int index) {
    final String path = (banner['imageStoragePath'] ?? '').toString().trim();
    final String croppedPath =
        (banner['croppedImageStoragePath'] ?? '').toString().trim();
    return 'modern-banner-$index-$path-$croppedPath-${_resolveImageUrl(banner)}';
  }

  void _precacheNearbyBanners() {
    if (!mounted || _banners.isEmpty) {
      return;
    }

    final int count = _banners.length;
    final Set<int> indices = <int>{_currentIndex.clamp(0, count - 1)};
    if (count > 1) {
      indices.add((_currentIndex + 1) % count);
      indices.add((_currentIndex - 1 + count) % count);
    }

    for (final int index in indices) {
      final String url = _resolveImageUrl(_banners[index]);
      if (url.isEmpty) {
        continue;
      }
      precacheImage(NetworkImage(url), context);
    }
  }

  void _goToPage(int nextIndex) {
    final int count = _banners.length;
    if (count <= 1) {
      return;
    }

    final int index = (nextIndex + count) % count;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _bannerShell({required Widget child}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = widget.frameSetting.heightForWidth(
          constraints.maxWidth,
        );
        return SizedBox(
          width: double.infinity,
          height: height,
          child: child,
        );
      },
    );
  }

  Widget _bannerSlideImage({
    required Map<String, dynamic> banner,
    required int index,
  }) {
    final String imageUrl = _resolveImageUrl(banner);
    return KeyedSubtree(
      key: ValueKey<String>(_slideKey(banner, index)),
      child: SizedBox.expand(
        child: Image.network(
          imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: widget.frameSetting.boxFit,
          alignment: widget.frameSetting.alignment,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          webHtmlElementStrategy: WebHtmlElementStrategy.never,
          loadingBuilder:
              (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
            return Container(
              color: widget.theme.cardColor,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                size: 34,
                color: widget.theme.primaryColor,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _navArrow({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> banners = _banners;
    final HomeThemeModel theme = widget.theme;
    final ModernBannerFrameSetting frameSetting = widget.frameSetting;

    if (banners.isEmpty) {
      return _bannerShell(
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 31, color: theme.primaryColor),
                const SizedBox(height: 7),
                Text(
                  '尚未設定店家封面',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isUltra = frameSetting.isUltraCompact;
    final bool isCompact = frameSetting.isCompact;
    final bool tightLayout = isUltra || isCompact;
    final double titleTop = isUltra ? 22 : (isCompact ? 26 : 38);
    final double titleGap = isUltra ? 2 : (isCompact ? 4 : 10);
    final double sidePad = tightLayout ? 8 : 13;
    final double ctaHeight = isUltra ? 22 : 28;
    final double ctaBottom = isUltra ? 4 : 8;
    final double badgeTop = isUltra ? 4 : 8;
    final double titleMaxSize = isUltra ? 15 : 18;
    final double subtitleMaxSize = isUltra ? 10 : 12;
    final HomeTextStyleModel titleStyle = widget.bannerTitleStyle.copyWith(
      fontSize: tightLayout && widget.bannerTitleStyle.fontSize > titleMaxSize
          ? titleMaxSize
          : widget.bannerTitleStyle.fontSize,
    );
    final HomeTextStyleModel subtitleStyle = widget.bannerSubtitleStyle.copyWith(
      fontSize:
          tightLayout && widget.bannerSubtitleStyle.fontSize > subtitleMaxSize
          ? subtitleMaxSize
          : widget.bannerSubtitleStyle.fontSize,
    );
    final bool showPager = banners.length > 1;
    final bool showNavArrows =
        showPager &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final int safeIndex = _currentIndex.clamp(0, banners.length - 1);

    return Column(
      children: [
        _bannerShell(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (kIsWeb)
                        _bannerSlideImage(
                          banner: banners[safeIndex],
                          index: safeIndex,
                        ),
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: const <PointerDeviceKind>{
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: PageView.builder(
                          key: const PageStorageKey<String>(
                            'modern-home-banner-pageview',
                          ),
                          controller: _pageController,
                          itemCount: banners.length,
                          physics: showPager
                              ? const PageScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          onPageChanged: (int index) {
                            setState(() {
                              _currentIndex = index;
                            });
                            _precacheNearbyBanners();
                          },
                          itemBuilder: (BuildContext context, int index) {
                            if (kIsWeb) {
                              return const SizedBox.expand();
                            }
                            return _bannerSlideImage(
                              banner: banners[index],
                              index: index,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      stops: [0.2, 0.65, 1],
                      colors: [
                        Colors.transparent,
                        Color(0x55000000),
                        Color(0xD9000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: sidePad,
                  top: badgeTop,
                  child: widget.reviewBadge,
                ),
                Positioned(
                  left: sidePad,
                  right: isUltra ? 40 : 85,
                  top: titleTop,
                  bottom: ctaHeight + ctaBottom + 2,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.bannerTitle.isNotEmpty)
                          Text(
                            widget.bannerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: titleStyle.textAlign,
                            style: titleStyle.toTextStyle(defaultHeight: 1.1),
                          ),
                        if (widget.bannerTitle.isNotEmpty &&
                            widget.bannerSubtitle.isNotEmpty)
                          SizedBox(height: titleGap),
                        if (widget.bannerSubtitle.isNotEmpty)
                          Text(
                            widget.bannerSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: subtitleStyle.textAlign,
                            style: subtitleStyle.toTextStyle(defaultHeight: 1.1),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: sidePad,
                  bottom: ctaBottom,
                  child: SizedBox(
                    height: ctaHeight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.bannerButtonColor,
                        foregroundColor: widget.bannerButtonTextColor,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltra ? 8 : 10,
                        ),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isUltra ? 10 : 12,
                          ),
                        ),
                      ),
                      onPressed: widget.onBookingPressed,
                      icon: Icon(
                        Icons.pets_rounded,
                        size: isUltra ? 10 : 12,
                      ),
                      label: Text(
                        widget.bannerButtonText.isEmpty
                            ? '立即預約住宿'
                            : widget.bannerButtonText,
                        style: TextStyle(
                          color: widget.bannerButtonTextColor,
                          fontSize: isUltra ? 8.5 : 9.5,
                          height: 1,
                          letterSpacing: 0.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showNavArrows) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _navArrow(
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => _goToPage(safeIndex - 1),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _navArrow(
                        icon: Icons.chevron_right_rounded,
                        onPressed: () => _goToPage(safeIndex + 1),
                      ),
                    ),
                  ),
                ],
                if (showPager)
                  Positioned(
                    right: isUltra ? 8 : 10,
                    bottom: isUltra ? 4 : 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isUltra ? 6 : 7,
                        vertical: isUltra ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${safeIndex + 1}/${banners.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isUltra ? 8 : 9,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showPager) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(banners.length, (int index) {
                final bool selected = index == safeIndex;
                return GestureDetector(
                  onTap: () => _goToPage(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: selected ? 14 : 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.primaryColor
                          : theme.cardBorderColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}
