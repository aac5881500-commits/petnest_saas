// 檔案名稱：lib/features/shop/widgets/modern_home/modern_home_banner_carousel.dart
// 功能說明：新版 Beta 首頁活動海報輪播。
// 外框尺寸由前台外觀的 homeBannerDisplaySize 統一決定，內容由每張 Banner 自己 render。

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class ModernHomeBannerCarousel extends StatefulWidget {
  const ModernHomeBannerCarousel({
    super.key,
    required this.banners,
    required this.theme,
    required this.frameSetting,
    required this.reviewBadge,
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
  final Widget reviewBadge;
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
  }

  @override
  void dispose() {
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
      padding: HomeBannerDisplay.outerPadding(widget.frameSetting.displaySize),
      child: AspectRatio(
        aspectRatio: HomeBannerDisplay.aspectRatio,
        child: child,
      ),
    );
  }

  Widget _bannerSlide({required StoreBannerModel banner, required int index}) {
    return KeyedSubtree(
      key: ValueKey<String>(
        'modern-banner-$index-${banner.id}-${banner.imageStoragePath}-${banner.imageUrl}',
      ),
      child: StoreBannerView(
        banner: banner,
        theme: widget.theme,
        scope: PetNestBannerScope.home,
        borderRadius: 0,
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
        widget.frameSetting.displaySize == HomeBannerDisplaySize.small;
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
      return _bannerCanvas(
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

    return Column(
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
                          key: PageStorageKey<String>(widget.scrollStorageKey),
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
                Positioned(
                  left: compact ? 8 : 13,
                  top: compact ? 4 : 8,
                  child: IgnorePointer(child: widget.reviewBadge),
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
    );
  }
}
