// 檔案名稱：lib/features/auth/pages/shop_opening_welcome_page.dart
// 功能說明：驗證激活碼後的開店歡迎頁，使用本機寫實照片與桌機／手機響應式卡片。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

const _ink = Color(0xFF74250F);
const _muted = Color(0xFF796A5D);
const _orange = Color(0xFFF45B14);
const _cream = Color(0xFFFFFAF2);
// 明確指定變動字體的 wght 軸，確保各 Flutter 渲染環境的字重一致。
const _regularAxes = [ui.FontVariation('wght', 400)];
const _mediumAxes = [ui.FontVariation('wght', 600)];
const _labelAxes = [ui.FontVariation('wght', 700)];
const _boldAxes = [ui.FontVariation('wght', 800)];
const _desktopPhoto = 'assets/images/shop_onboarding/welcome_desktop.webp';
const _mobilePhoto = 'assets/images/shop_onboarding/welcome_mobile.webp';

class ShopOpeningWelcomePage extends StatefulWidget {
  const ShopOpeningWelcomePage({
    super.key,
    required this.activationCode,
    this.heroIllustration,
  });

  final String activationCode;

  // 保留既有注入主視覺的介面；正式流程預設載入本機照片。
  final Widget? heroIllustration;

  @override
  State<ShopOpeningWelcomePage> createState() => _ShopOpeningWelcomePageState();
}

class _ShopOpeningWelcomePageState extends State<ShopOpeningWelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (!_entrance.isAnimating && _entrance.value == 0) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_opening) return;
    final code = widget.activationCode.trim();
    if (code.isEmpty) {
      Navigator.of(context).pop(ShopCreateExit.recheckActivation);
      return;
    }
    setState(() => _opening = true);
    try {
      final result = await Navigator.of(context).push<ShopCreateExit>(
        MaterialPageRoute<ShopCreateExit>(
          builder: (_) => CreateShopPage(activationCode: code),
        ),
      );
      if (!mounted || result == null) return;
      Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final desktop = viewport.maxWidth >= 900;
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final extraHeight = (textScale - 1).clamp(0.0, 3.0) * 180;
            return SingleChildScrollView(
              key: const ValueKey('welcome-scroll'),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: EdgeInsets.all(desktop ? 24 : 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(desktop ? 26 : 0),
                        boxShadow: desktop
                            ? const [
                                BoxShadow(
                                  color: Color(0x12774A25),
                                  blurRadius: 28,
                                  offset: Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(desktop ? 26 : 0),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontFamily: 'NotoSansTC',
                            fontVariations: _regularAxes,
                          ),
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              final photoHeight = desktop
                                  ? (bounds.maxWidth * .41).clamp(440.0, 520.0)
                                  : (bounds.maxWidth * 1.16).clamp(
                                      380.0,
                                      540.0,
                                    );
                              final heroHeight = photoHeight + extraHeight;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    height: heroHeight,
                                    child: FadeTransition(
                                      opacity: _entrance,
                                      child: _Hero(
                                        desktop: desktop,
                                        textScale: textScale,
                                        imageTop: extraHeight,
                                        illustration: widget.heroIllustration,
                                        onBack: () =>
                                            Navigator.of(context).maybePop(),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height:
                                            heroHeight - (desktop ? 40 : 28),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: desktop ? 56 : 16,
                                        ),
                                        child: _OnboardingPanel(
                                          horizontal:
                                              desktop && textScale <= 1.4,
                                          desktop: desktop,
                                          onStart: _opening ? null : _start,
                                        ),
                                      ),
                                      if (desktop) ...[
                                        const SizedBox(height: 24),
                                        const _ProductFeatures(),
                                      ] else
                                        const SizedBox(height: 20),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.desktop,
    required this.textScale,
    required this.imageTop,
    required this.illustration,
    required this.onBack,
  });
  final bool desktop;
  final double textScale;
  final double imageTop;
  final Widget? illustration;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final width = bounds.maxWidth;
        final inset = desktop ? 64.0 : 20.0;
        return ColoredBox(
          color: _cream,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: imageTop,
                left: 0,
                right: 0,
                bottom: 0,
                child:
                    illustration ??
                    Image.asset(
                      desktop ? _desktopPhoto : _mobilePhoto,
                      key: const ValueKey('welcome-photo'),
                      fit: BoxFit.cover,
                      alignment: desktop
                          ? Alignment.centerRight
                          : Alignment.center,
                      semanticLabel: '暖陽照入木質貓咪旅社，長毛虎斑貓躺在柔軟地毯上',
                    ),
              ),
              Positioned(
                top: desktop ? 124 : 96,
                left: inset,
                width: desktop && textScale <= 1.4
                    ? width * .61
                    : width - inset * 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '一起開啟\n你的寵物旅宿事業',
                      key: const ValueKey('welcome-headline'),
                      style: TextStyle(
                        color: _ink,
                        fontSize: desktop
                            ? (width * .044).clamp(38.0, 58.0)
                            : (width * .078).clamp(25.0, 35.0),
                        fontWeight: FontWeight.w800,
                        fontVariations: _boldAxes,
                        height: 1.24,
                        letterSpacing: desktop ? .5 : -.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '簡單設定・快速開店・專屬你的品牌',
                      style: TextStyle(
                        color: _ink,
                        fontSize: desktop ? 20 : 13,
                        fontWeight: FontWeight.w600,
                        fontVariations: _mediumAxes,
                        height: 1.6,
                      ),
                    ),
                    if (desktop && textScale <= 1.4) ...[
                      const SizedBox(height: 26),
                      const Text(
                        '讓更多毛孩，\n擁有安心又溫暖的旅宿體驗 ♡',
                        style: TextStyle(
                          fontFamily: 'KleeOne',
                          fontWeight: FontWeight.w600,
                          fontVariations: [],
                          color: _ink,
                          fontSize: 19,
                          height: 1.65,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: desktop ? 28 : 18,
                left: inset,
                right: desktop ? 28 : 12,
                child: Row(
                  children: [
                    const Expanded(child: _Brand()),
                    TextButton.icon(
                      key: const ValueKey('welcome-back'),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      label: Text(
                        width < 360 || textScale > 1.3 ? '返回' : '返回上一頁',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _ink,
                        backgroundColor: const Color(0xF5FFFCF5),
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const StadiumBorder(
                          side: BorderSide(color: Color(0xFFF0DDC3)),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansTC',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontVariations: _labelAxes,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PetNest 寵物旅宿 SaaS',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: 36, color: Color(0xFFB23A0B)),
            SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PetNest',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 25,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    fontVariations: _boldAxes,
                    letterSpacing: -.5,
                  ),
                ),
                Text(
                  '寵物旅宿 SaaS',
                  style: TextStyle(color: _ink, fontSize: 10, height: 1.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _steps = [
  (Icons.storefront_rounded, '1. 激活碼驗證完成', '開店資格已確認\n接下來建立你的專屬旅宿'),
  (Icons.settings_rounded, '2. 完善店家資料', '設定基本資訊、房型、服務\n打造屬於你的風格'),
  (Icons.bar_chart_rounded, '3. 開始營運', '上架預約、管理訂單\n提供專業的寵物旅宿服務'),
];

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  color: const Color(0xFFFFFDF9),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFFF3E7D8)),
  boxShadow: const [
    BoxShadow(color: Color(0x0E784A22), blurRadius: 24, offset: Offset(0, 6)),
  ],
);

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    required this.horizontal,
    required this.desktop,
    required this.onStart,
  });
  final bool horizontal;
  final bool desktop;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: desktop
          ? const EdgeInsets.fromLTRB(28, 24, 28, 20)
          : EdgeInsets.zero,
      decoration: desktop ? _cardDecoration(24) : null,
      child: Column(
        children: [
          if (horizontal)
            Row(
              key: const ValueKey('horizontal-steps'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 52, 10, 0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: _muted,
                      ),
                    ),
                  Expanded(child: _StepCard(index: i, horizontal: true)),
                ],
              ],
            )
          else
            Column(
              key: const ValueKey('vertical-steps'),
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _StepCard(index: i, horizontal: false),
                ],
              ],
            ),
          SizedBox(height: desktop ? 22 : 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _PrimaryButton(onPressed: onStart),
          ),
          const SizedBox(height: 10),
          const Text(
            '激活碼已驗證，接下來設定你的店家資料',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.horizontal});
  final int index;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final step = _steps[index];
    final symbol = Container(
      width: horizontal ? 64 : 46,
      height: horizontal ? 64 : 46,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0D5),
        shape: BoxShape.circle,
      ),
      child: Icon(step.$1, size: horizontal ? 32 : 26, color: _orange),
    );
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          step.$2,
          textAlign: horizontal ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: const Color(0xFF30261E),
            fontSize: horizontal ? 18 : 14,
            fontWeight: FontWeight.w800,
            fontVariations: _boldAxes,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          step.$3,
          textAlign: horizontal ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: _muted,
            fontSize: horizontal ? 13 : 12,
            height: 1.6,
          ),
        ),
      ],
    );
    if (horizontal) {
      return Column(children: [symbol, const SizedBox(height: 12), copy]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: _cardDecoration(18),
      child: Row(
        children: [
          symbol,
          const SizedBox(width: 12),
          Expanded(child: copy),
          const SizedBox(width: 4),
          Icon(
            index == 0
                ? Icons.check_circle_rounded
                : Icons.chevron_right_rounded,
            color: index == 0 ? const Color(0xFF7C9865) : _muted,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF751F), Color(0xFFF04F0C)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26E96920),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        key: const ValueKey('welcome-start'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: const StadiumBorder(),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, size: 22),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                '開始建立我的旅宿',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSansTC',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontVariations: _labelAxes,
                ),
              ),
            ),
            SizedBox(width: 9),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProductFeatures extends StatelessWidget {
  const _ProductFeatures();
  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.pets_rounded, '專為寵物旅宿設計', '住宿・安親・會員・金流\n一次整合'),
      (Icons.lock_rounded, '安全穩定的平台', 'Firebase 技術\n守護你的營運資料'),
      (Icons.favorite_rounded, '節省營運時間', '訂單・房務・照護回報\n輕鬆管理'),
      (Icons.groups_rounded, '陪伴你的成長', '持續優化產品\n專注每一天的照護'),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF0E3D0))),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final columns = largeText ? 2 : 4;
          return Wrap(
            runSpacing: 24,
            children: [
              for (final feature in features)
                SizedBox(
                  width: bounds.maxWidth / columns,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(feature.$1, size: 27, color: _ink),
                        const SizedBox(height: 9),
                        Text(
                          feature.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF392B21),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontVariations: _boldAxes,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          feature.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
