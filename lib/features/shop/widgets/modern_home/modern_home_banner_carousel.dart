// 檔案名稱：lib/features/shop/widgets/modern_home/modern_home_banner_carousel.dart
// 功能說明：新版 Beta 首頁活動海報輪播。
// 外框寬度與高度由前台外觀分開決定，內容由每張 Banner 自己 render。

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shared_entry_section.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class ModernHomeBannerCarousel extends StatefulWidget {
  const ModernHomeBannerCarousel({
    super.key,
    required this.banners,
    required this.theme,
    required this.frameSetting,
    this.onBannerTap,
    this.liveComposeBannerId,
    this.initialBannerId,
    this.onComposeChanged,
    this.onComposeTextSelected,
    this.onComposeCtaSelected,
    this.composeImageBytes,
    this.composeSelectedTextId,
    this.composeCtaSelected = false,
    this.scrollStorageKey = 'modern-home-banner-pageview',
  });

  final List<StoreBannerModel> banners;
  final HomeThemeModel theme;
  final ModernBannerFrameSetting frameSetting;
  final ValueChanged<StoreBannerModel>? onBannerTap;

  /// 後台預覽：這張用草稿即時合成，顧客前台不傳。
  final String? liveComposeBannerId;
  final String? initialBannerId;
  final ValueChanged<StoreBannerModel>? onComposeChanged;
  final ValueChanged<String?>? onComposeTextSelected;
  final VoidCallback? onComposeCtaSelected;
  final Uint8List? composeImageBytes;
  final String? composeSelectedTextId;
  final bool composeCtaSelected;

  /// 同一店家若同時有顧客首頁與編排畫布，滾動儲存鍵必須分開。
  final String scrollStorageKey;

  @override
  State<ModernHomeBannerCarousel> createState() =>
      _ModernHomeBannerCarouselState();
}

class _ModernHomeBannerCarouselState extends State<ModernHomeBannerCarousel> {
  late final PageController _pageController;
  late PageController _activityPage;
  int _currentIndex = 0;

  List<StoreBannerModel> get _banners => widget.banners;

  int _indexOf(String? bannerId) {
    if (bannerId == null || bannerId.isEmpty) {
      return 0;
    }
    final int index = widget.banners.indexWhere(
      (StoreBannerModel banner) => banner.id == bannerId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    final int initial = _indexOf(widget.initialBannerId);
    _currentIndex = initial;
    _pageController = PageController(initialPage: initial);
    _activityPage = _newActivityPage(initial);
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
      _syncActivityPage();
      return;
    }
    if (widget.initialBannerId != oldWidget.initialBannerId) {
      final int index = _indexOf(widget.initialBannerId);
      _currentIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
      });
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
    _syncActivityPage();
  }

  double _activityFraction() {
    if (widget.banners.length < 2 || !widget.frameSetting.isActivity) {
      return 1;
    }
    return widget.frameSetting.activityCardFraction;
  }

  PageController _newActivityPage(int page) {
    final int count = widget.banners.length;
    final int safe = count <= 0 ? 0 : page.clamp(0, count - 1);
    return PageController(
      initialPage: safe,
      viewportFraction: _activityFraction(),
    )..addListener(_onActivityPage);
  }

  void _syncActivityPage() {
    final double fraction = _activityFraction();
    if ((_activityPage.viewportFraction - fraction).abs() <= 0.001) {
      return;
    }
    final int page = _activityPage.hasClients
        ? (_activityPage.page ?? _currentIndex).round()
        : _currentIndex;
    final PageController previous = _activityPage;
    previous.removeListener(_onActivityPage);
    _activityPage = _newActivityPage(page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.dispose();
    });
  }

  void _onActivityPage() {
    if (!_activityPage.hasClients || widget.banners.length < 2) {
      return;
    }
    final int next = (_activityPage.page ?? 0).round().clamp(
      0,
      widget.banners.length - 1,
    );
    if (next != _currentIndex && mounted) {
      setState(() => _currentIndex = next);
    }
  }

  void _goActivity(int index) {
    final int count = widget.banners.length;
    if (count == 0 || !_activityPage.hasClients) {
      return;
    }
    final int safe = index.clamp(0, count - 1);
    _activityPage.animateToPage(
      safe,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _activityPage.removeListener(_onActivityPage);
    _activityPage.dispose();
    _pageController.dispose();
    super.dispose();
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
      final String url = _banners[index].frontImageUrl;
      if (url.isEmpty) {
        continue;
      }
      precacheImage(NetworkImage(url), context).catchError((
        Object e,
        StackTrace st,
      ) {
        print('[ModernHomeBanner] precache FAILED url=$url');
        ChatErrorProbe.dump('ModernHomeBanner precache', e, st);
      });
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

  Widget _bannerCanvas({required Widget child}) {
    return Padding(
      padding: HomeBannerDisplay.outerPadding(widget.frameSetting.widthPreset),
      child: AspectRatio(
        aspectRatio: widget.frameSetting.frameAspectRatio,
        child: child,
      ),
    );
  }

  Widget _bannerSlide({
    required StoreBannerModel banner,
    required int index,
    double borderRadius = 0,
    double? aspectRatio,
    BoxFit? fit,
  }) {
    return KeyedSubtree(
      key: ValueKey<String>(
        'modern-banner-$index-${banner.id}-${banner.imageStoragePath}-${banner.imageUrl}',
      ),
      child: StoreBannerView(
        banner: banner,
        theme: widget.theme,
        scope: PetNestBannerScope.home,
        borderRadius: borderRadius,
        homeFrameAspectRatio:
            aspectRatio ?? widget.frameSetting.frameAspectRatio,
        completePosterFit: fit ?? widget.frameSetting.completePosterFit,
        composeLive: widget.liveComposeBannerId == banner.id ? true : null,
        interactMode:
            widget.liveComposeBannerId == banner.id &&
                widget.onComposeChanged != null
            ? StoreBannerInteractMode.text
            : StoreBannerInteractMode.none,
        previewImageBytes: widget.liveComposeBannerId == banner.id
            ? widget.composeImageBytes
            : null,
        selectedTextId: widget.liveComposeBannerId == banner.id
            ? widget.composeSelectedTextId
            : null,
        ctaSelected:
            widget.liveComposeBannerId == banner.id &&
            widget.composeCtaSelected,
        onChanged: widget.liveComposeBannerId == banner.id
            ? widget.onComposeChanged
            : null,
        onTextSelected: widget.liveComposeBannerId == banner.id
            ? widget.onComposeTextSelected
            : null,
        onCtaSelected: widget.liveComposeBannerId == banner.id
            ? widget.onComposeCtaSelected
            : null,
        onTap: widget.onBannerTap == null || !banner.hasNavigableAction
            ? null
            : () => widget.onBannerTap!(banner),
      ),
    );
  }

  Widget _navArrow({required IconData icon, required VoidCallback onPressed}) {
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
    final List<StoreBannerModel> banners = _banners;
    final HomeThemeModel theme = widget.theme;
    final bool compact =
        widget.frameSetting.widthPreset == HomeBannerWidthPreset.narrow;
    final bool showPager = banners.length > 1;
    final bool showNavArrows =
        showPager &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final int safeIndex = banners.isEmpty
        ? 0
        : _currentIndex.clamp(0, banners.length - 1);

    if (banners.isEmpty) {
      return _withSectionTitle(
        _bannerCanvas(
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
                  Icon(
                    Icons.image_outlined,
                    size: 31,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '尚未設定活動海報',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textColor.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (widget.frameSetting.isActivity) {
      return _withSectionTitle(_activityCarousel(banners, theme, safeIndex));
    }

    return _withSectionTitle(
      Column(
        children: [
          _bannerCanvas(
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
                            key: PageStorageKey<String>(
                              widget.scrollStorageKey,
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
                              return _bannerSlide(
                                banner: banners[index],
                                index: index,
                              );
                            },
                          ),
                        ),
                      ],
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
                      right: compact ? 8 : 10,
                      bottom: compact ? 4 : 10,
                      child: IgnorePointer(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : 7,
                            vertical: compact ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${safeIndex + 1}/${banners.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 8 : 9,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }

  Widget _withSectionTitle(Widget child) {
    final ModernBannerFrameSetting frame = widget.frameSetting;
    final String title = frame.sectionTitle.trim();
    if (!frame.showSectionTitle || title.isEmpty) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeEntryFontScope(
          fontFamily: frame.appliedSectionFont,
          child: Padding(
            padding: EdgeInsets.only(bottom: frame.sectionTitleGapPx),
            child: Text(
              title,
              key: const Key('home-banner-section-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: switch (frame.sectionTitleAlign) {
                ModernBannerFrameSetting.alignCenter => TextAlign.center,
                ModernBannerFrameSetting.alignEnd => TextAlign.end,
                _ => TextAlign.start,
              },
              style: TextStyle(
                color:
                    frame.sectionTitleColorMode ==
                        ModernBannerFrameSetting.colorCustom
                    ? Color(frame.sectionTitleColor)
                    : widget.theme.textColor,
                fontSize: frame.sectionTitleFontSize,
                fontWeight: frame.sectionTitleFontWeight,
                height: 1.2,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _activityCarousel(
    List<StoreBannerModel> banners,
    HomeThemeModel theme,
    int safeIndex,
  ) {
    final ModernBannerFrameSetting frame = widget.frameSetting;
    final bool peek = banners.length > 1;
    final double gap = peek ? frame.activityGapPx : 0;
    final double fraction = peek ? frame.activityCardFraction : 1;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewport = constraints.maxWidth.isFinite
            ? math.max(1, constraints.maxWidth)
            : 360;
        final double inner = math.max(1, viewport - frame.activityInsetPx * 2);
        final double cardWidth = math.max(1, inner * fraction - gap);
        final double height = (cardWidth * frame.activityHeightRatio).clamp(
          96,
          460,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: frame.activityInsetPx),
              child: SizedBox(
                height: height,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const <PointerDeviceKind>{
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: PageView.builder(
                    key: const Key('activity-banner-scroll'),
                    controller: _activityPage,
                    padEnds: false,
                    clipBehavior: Clip.hardEdge,
                    physics: const PageScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    itemCount: banners.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == banners.length - 1 ? 0 : gap,
                        ),
                        child: SizedBox(
                          key: Key('activity-banner-$index'),
                          width: cardWidth,
                          height: height,
                          child: _bannerSlide(
                            banner: banners[index],
                            index: index,
                            borderRadius: frame.activityRadiusPx,
                            aspectRatio: cardWidth / height,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (frame.showDots && banners.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int index = 0; index < banners.length; index++)
                      GestureDetector(
                        key: Key('activity-banner-dot-$index'),
                        onTap: () => _goActivity(index),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == safeIndex ? 14 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          decoration: BoxDecoration(
                            color: index == safeIndex
                                ? (frame.dotColorMode ==
                                          ModernBannerFrameSetting.colorCustom
                                      ? Color(frame.dotColor)
                                      : theme.primaryColor)
                                : theme.cardBorderColor.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
