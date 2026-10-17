// 檔案名稱：lib/features/auth/pages/shop_opening_welcome_page.dart
// 功能說明：驗證激活碼後的 PetNest 開店歡迎頁；僅呈現 UI，不建立店家或寫入資料。
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

class ShopOpeningWelcomePage extends StatefulWidget {
  const ShopOpeningWelcomePage({
    super.key,
    required this.activationCode,
    this.heroIllustration,
  });

  final String activationCode;
  final Widget? heroIllustration;

  @override
  State<ShopOpeningWelcomePage> createState() => _ShopOpeningWelcomePageState();
}

class _ShopOpeningWelcomePageState extends State<ShopOpeningWelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final code = widget.activationCode.trim();
    if (code.isEmpty) {
      Navigator.of(context).pop(ShopCreateExit.recheckActivation);
      return;
    }
    final result = await Navigator.of(context).push<ShopCreateExit>(
      MaterialPageRoute<ShopCreateExit>(
        builder: (_) => CreateShopPage(activationCode: code),
      ),
    );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result);
  }

  void _back() => Navigator.of(context).maybePop();

  Widget _reveal(Widget child, double begin) {
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final t = ((_controller.value - begin) / (1 - begin))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final desktop = bounds.maxWidth >= 820;
            if (desktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: _reveal(
                              _DesktopHero(
                                illustration: widget.heroIllustration,
                                onBack: _back,
                              ),
                              0,
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Container(
                              color: Colors.white,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(28, 38, 28, 28),
                                child: _reveal(
                                  _WelcomeContent(
                                    onStart: _start,
                                    onBack: _back,
                                    desktop: true,
                                  ),
                                  .15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _reveal(
                          _MobileHero(
                            illustration: widget.heroIllustration,
                            onBack: _back,
                          ),
                          0,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                          child: _reveal(
                            _WelcomeContent(
                              onStart: _start,
                              onBack: _back,
                              desktop: false,
                            ),
                            .18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomAction(onStart: _start),
              ],
            );
          },
        ),
      ),
    );
  }
}

const _ink = Color(0xFF542E20);
const _muted = Color(0xFF7C6B60);
const _orange = Color(0xFFE57A35);
const _warm = Color(0xFFFFF5EA);

class _MobileHero extends StatelessWidget {
  const _MobileHero({required this.illustration, required this.onBack});
  final Widget? illustration;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: width < 360 ? 325 : 370,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroArt(illustration: illustration),
          Positioned(
            left: 12,
            top: 8,
            child: Material(
              color: Colors.white.withValues(alpha: .85),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back, color: _ink),
                onPressed: onBack,
              ),
            ),
          ),
          const Positioned(
            left: 64,
            top: 16,
            child: _Brand(),
          ),
          const Positioned(
            left: 22,
            right: 22,
            top: 82,
            child: _HeroHeadline(mobile: true),
          ),
          const Positioned(
            right: 16,
            bottom: 14,
            child: _HeroNote(),
          ),
        ],
      ),
    );
  }
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero({required this.illustration, required this.onBack});
  final Widget? illustration;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _HeroArt(illustration: illustration),
        const Positioned(left: 28, top: 26, child: _Brand()),
        Positioned(
          right: 20,
          top: 18,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('返回'),
            style: TextButton.styleFrom(
              foregroundColor: _ink,
              backgroundColor: Colors.white.withValues(alpha: .86),
            ),
          ),
        ),
        const Positioned(
          left: 34,
          right: 26,
          top: 128,
          child: _HeroHeadline(mobile: false),
        ),
        const Positioned(right: 24, bottom: 26, child: _HeroNote()),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.illustration});
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SvgPicture.asset(
          'assets/images/shop_welcome_hero.svg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholderBuilder: (_) =>
              const ColoredBox(color: Color(0xFFF8E5D0)),
        ),
        if (illustration != null)
          Positioned.fill(child: illustration!),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFF8EF).withValues(alpha: .82),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: const [0, .34, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pets_rounded, color: _ink, size: 27),
        SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PetNest', style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900, color: _ink,
              height: 1.1,
            )),
            Text('寵物旅宿 SaaS', style: TextStyle(
              fontSize: 10, color: _muted, height: 1.3,
            )),
          ],
        ),
      ],
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline({required this.mobile});
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '一起開啟\n你的貓咪旅社',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            height: 1.16,
            fontSize: mobile ? 29 : 43,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '簡單設定・溫暖開店・專屬你的品牌',
          style: TextStyle(
            color: _ink,
            fontSize: mobile ? 12 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeroNote extends StatelessWidget {
  const _HeroNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x16935A36), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: const Text(
        '讓更多毛孩，擁有安心又溫暖的旅宿體驗 ♡',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _ink,
          height: 1.5,
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.onStart,
    required this.onBack,
    required this.desktop,
  });
  final VoidCallback onStart;
  final VoidCallback onBack;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (desktop) ...[
          const Text('開店小幫手', style: TextStyle(
            color: _orange, fontSize: 14, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 10),
          const Text('準備好打造你的旅社了嗎？', style: TextStyle(
            color: _ink, fontSize: 27, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 10),
          const Text(
            '激活碼已完成驗證，接下來只要設定基本資料，\n就能開始打造你的專屬旅社。',
            style: TextStyle(color: _muted, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 26),
        ] else ...[
          const Center(
            child: Text('接下來，三個步驟就能開始', style: TextStyle(
              color: _ink, fontSize: 19, fontWeight: FontWeight.w900,
            )),
          ),
          const SizedBox(height: 15),
        ],
        const _StepCard(
          number: '01',
          icon: Icons.verified_user_outlined,
          title: '激活碼驗證完成',
          description: '你的開店資格已確認，可以放心繼續。',
          completed: true,
        ),
        const SizedBox(height: 10),
        const _StepCard(
          number: '02',
          icon: Icons.tune_rounded,
          title: '完善店家資料',
          description: '設定店名、地區，建立旅社基本資訊。',
        ),
        const SizedBox(height: 10),
        const _StepCard(
          number: '03',
          icon: Icons.storefront_rounded,
          title: '開始經營旅社',
          description: '房型、預約和服務都可以之後慢慢設定。',
        ),
        if (desktop) ...[
          const SizedBox(height: 30),
          _PrimaryButton(onPressed: onStart),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onBack,
            child: const Text('先返回', style: TextStyle(color: _muted)),
          ),
          const SizedBox(height: 18),
          const _Assurance(),
        ] else ...[
          const SizedBox(height: 18),
          const _Assurance(),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    this.completed = false,
  });
  final String number;
  final IconData icon;
  final String title;
  final String description;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1E4D7)),
        boxShadow: const [
          BoxShadow(color: Color(0x0B946B4C), blurRadius: 18, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              color: _warm,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _orange, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: _ink, fontWeight: FontWeight.w800, fontSize: 15,
                )),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(
                  color: _muted, height: 1.4, fontSize: 12,
                )),
              ],
            ),
          ),
          if (completed)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF7F9C75), size: 20)
          else
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDA897)),
        ],
      ),
    );
  }
}

class _Assurance extends StatelessWidget {
  const _Assurance();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite_rounded, size: 14, color: _orange),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            '不用一次做完，後續設定都能慢慢補齊',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 13),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAF5),
        border: Border(top: BorderSide(color: Color(0xFFF1E4D7))),
      ),
      child: _PrimaryButton(onPressed: onStart),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF8C42), Color(0xFFD46B2F)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x32CC733A), blurRadius: 16, offset: Offset(0, 7)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: const SizedBox(
            height: 55,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_rounded, color: Colors.white, size: 21),
                SizedBox(width: 9),
                Text('開始建立我的旅社', style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                )),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
