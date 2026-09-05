// 檔案名稱：lib/features/shop/widgets/store/store_banner_carousel.dart
// 功能說明：商城活動海報輪播（店家 Banner，不是旅館首頁 Banner）

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class StoreBannerCarousel extends StatefulWidget {
  const StoreBannerCarousel({
    super.key,
    required this.banners,
    required this.theme,
    required this.onTap,
    this.autoPlay = true,
    this.autoPlaySeconds = 5,
  });

  final List<StoreBannerModel> banners;
  final HomeThemeModel theme;
  final void Function(StoreBannerModel banner) onTap;
  final bool autoPlay;
  final int autoPlaySeconds;

  @override
  State<StoreBannerCarousel> createState() => _StoreBannerCarouselState();
}

class _StoreBannerCarouselState extends State<StoreBannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant StoreBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.autoPlaySeconds != widget.autoPlaySeconds ||
        oldWidget.banners.length != widget.banners.length) {
      _restartTimer();
    }
    if (_index >= widget.banners.length && widget.banners.isNotEmpty) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!widget.autoPlay || widget.banners.length <= 1) {
      return;
    }
    final int seconds =
        widget.autoPlaySeconds == 3 || widget.autoPlaySeconds == 8
        ? widget.autoPlaySeconds
        : 5;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted ||
          !_pageController.hasClients ||
          widget.banners.length <= 1) {
        return;
      }
      final int next = (_index + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
      );
    });
  }

  void _go(int delta) {
    if (widget.banners.length <= 1 || !_pageController.hasClients) {
      return;
    }
    final int next = (_index + delta).clamp(0, widget.banners.length - 1);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<StoreBannerModel> banners = widget.banners;
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }
    final int safeIndex = _index.clamp(0, banners.length - 1);
    final bool showPager = banners.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double height = StoreBannerSizePresets.heightForWidth(
                banners[safeIndex].sizePreset,
                constraints.maxWidth,
              );
              return SizedBox(
                height: height,
                child: Stack(
                  children: <Widget>[
                    PageView.builder(
                      controller: _pageController,
                      itemCount: banners.length,
                      onPageChanged: (int value) {
                        setState(() => _index = value);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final StoreBannerModel banner = banners[index];
                        return StoreBannerView(
                          banner: banner,
                          theme: widget.theme,
                          borderRadius: 18,
                          onTap: banner.hasNavigableAction
                              ? () => widget.onTap(banner)
                              : null,
                        );
                      },
                    ),
                    if (showPager && kIsWeb) ...<Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _ArrowButton(
                          icon: Icons.chevron_left,
                          onTap: () => _go(-1),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _ArrowButton(
                          icon: Icons.chevron_right,
                          onTap: () => _go(1),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (showPager)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(banners.length, (int i) {
                  final bool active = i == safeIndex;
                  return Container(
                    width: active ? 14 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? widget.theme.primaryColor
                          : widget.theme.textColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class StoreFallbackBanner extends StatelessWidget {
  const StoreFallbackBanner({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
  });

  final HomeThemeModel theme;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: <Color>[
              theme.primaryColor.withValues(alpha: 0.16),
              theme.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: theme.textColor.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.pets_outlined, size: 32, color: theme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
