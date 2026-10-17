// 檔案名稱：lib/features/auth/pages/shop_opening_welcome_page.dart
// 功能說明：激活碼驗證成功後的歡迎畫面。不建立店家，也不寫入 Firestore。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/widgets/shop_welcome_scene.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

/// 激活碼驗證成功後的歡迎畫面。不建立店家，也不寫入 Firestore。
///
/// [heroIllustration] 預留給日後的專屬插畫。未提供時使用貓咪住宿庭院。
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
  late final AnimationController _enter;
  late final CurvedAnimation _hero;
  late final CurvedAnimation _copy;
  late final CurvedAnimation _bubble;
  late final CurvedAnimation _tips;
  bool _motionReady = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _hero = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.48, curve: Curves.easeOutCubic),
    );
    _copy = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.18, 0.66, curve: Curves.easeOutCubic),
    );
    _bubble = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.34, 0.78, curve: Curves.easeOutCubic),
    );
    _tips = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.46, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionReady) return;
    _motionReady = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _hero.dispose();
    _copy.dispose();
    _bubble.dispose();
    _tips.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final String code = widget.activationCode.trim();
    if (code.isEmpty) {
      Navigator.of(context).pop(ShopCreateExit.recheckActivation);
      return;
    }
    final ShopCreateExit? result = await Navigator.of(context)
        .push<ShopCreateExit>(
          MaterialPageRoute<ShopCreateExit>(
            builder: (_) => CreateShopPage(activationCode: code),
          ),
        );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result);
  }

  void _leave() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 720;
    final bool roomy = width >= 980;
    final double pad = width < 360 ? 12 : (wide ? 32 : 18);

    return Scaffold(
      backgroundColor: _WelcomePalette.cream,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WelcomeBackdropPainter()),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _WelcomeHeader(onBack: _leave),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(pad, 4, pad, 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, constraints.maxHeight - 12),
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 880),
                              child: Column(
                                children: <Widget>[
                                  if (roomy)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                          flex: 6,
                                          child: _rise(
                                            animation: _hero,
                                            child: _SceneFrame(
                                              height: 300,
                                              child: ShopWelcomeScene(
                                                replacement: widget.heroIllustration,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 28),
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            children: <Widget>[
                                              _rise(
                                                animation: _copy,
                                                child: const _WelcomeCopy(),
                                              ),
                                              const SizedBox(height: 16),
                                              _rise(
                                                animation: _bubble,
                                                child: const _HelperBubble(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...<Widget>[
                                    _rise(
                                      animation: _hero,
                                      child: _SceneFrame(
                                        height: width < 360
                                            ? 188
                                            : (wide ? 260 : 214),
                                        child: ShopWelcomeScene(
                                          replacement: widget.heroIllustration,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: wide ? 20 : 16),
                                    _rise(
                                      animation: _copy,
                                      child: const _WelcomeCopy(),
                                    ),
                                    SizedBox(height: wide ? 14 : 12),
                                    _rise(
                                      animation: _bubble,
                                      child: const _HelperBubble(),
                                    ),
                                  ],
                                  SizedBox(height: wide ? 18 : 14),
                                  _TipSection(animation: _tips, wide: wide),
                                  if (wide) ...<Widget>[
                                    const SizedBox(height: 8),
                                    _WelcomeActions(
                                      wide: wide,
                                      docked: false,
                                      onStart: _start,
                                      onBack: _leave,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!wide)
                  _WelcomeActions(
                    wide: wide,
                    onStart: _start,
                    onBack: _leave,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rise({required Animation<double> animation, required Widget child}) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value.clamp(0, 1).toDouble();
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SceneFrame extends StatelessWidget {
  const _SceneFrame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: double.infinity, child: child);
  }
}

class _WelcomePalette {
  static const Color cream = Color(0xFFFFF6EE);
  static const Color ink = Color(0xFF172238);
  static const Color blueGray = Color(0xFF5C6B7A);
  static const Color sageDeep = Color(0xFF3E5C45);
  static const Color sageSoft = Color(0xFFE7F0E4);
  static const Color line = Color(0xFFE8DDD2);
  static const Color paper = Color(0xFFFFFCF8);
}

class _WelcomeBackdropPainter extends CustomPainter {
  const _WelcomeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _WelcomePalette.cream,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.08),
      size.shortestSide * 0.42,
      Paint()..color = const Color(0xFFF6DCCB).withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(size.width * -0.04, size.height * 0.72),
      size.shortestSide * 0.38,
      Paint()..color = const Color(0xFFDCE8D8).withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.96),
      size.shortestSide * 0.22,
      Paint()..color = const Color(0xFFE4EEF4).withValues(alpha: 0.8),
    );
    _paw(canvas, Offset(size.width * 0.12, size.height * 0.22), 0.9);
    _paw(canvas, Offset(size.width * 0.86, size.height * 0.58), 0.7);
  }

  void _paw(Canvas canvas, Offset center, double scale) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final Paint ink = Paint()
      ..color = const Color(0xFFD7B89A).withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 18, height: 14),
      ink,
    );
    canvas.drawCircle(const Offset(-8, -6), 4, ink);
    canvas.drawCircle(const Offset(0, -9), 4.2, ink);
    canvas.drawCircle(const Offset(8, -6), 4, ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackdropPainter oldDelegate) => false;
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 720;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 16 : 0, 2, wide ? 24 : 10, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: '返回',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  'PetNest 開店小幫手',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _WelcomePalette.ink,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const _ReadyBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyBadge extends StatelessWidget {
  const _ReadyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _WelcomePalette.sageSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '準備開始',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _WelcomePalette.sageDeep,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy();

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final TextTheme text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        children: <Widget>[
          Text(
            '歡迎加入 PetNest！',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontSize: wide ? 34 : 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: _WelcomePalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '一起打造貓咪們的第二個家 🐾',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: _WelcomePalette.sageDeep,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '從今天開始，讓我們陪你一步步建立專屬旅社。\n不用一次做完，小幫手會帶著你，其餘設定之後也能慢慢補上。',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              height: 1.55,
              color: _WelcomePalette.blueGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelperBubble extends StatelessWidget {
  const _HelperBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: <Widget>[
            CustomPaint(
              size: const Size(18, 10),
              painter: _BubbleTailPainter(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _WelcomePalette.paper,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _WelcomePalette.line),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x148C6A4E),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '「喵～準備好打造我們的新家了嗎？」',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: _WelcomePalette.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path tail = Path()
      ..moveTo(size.width * 0.28, size.height)
      ..lineTo(size.width * 0.62, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(tail, Paint()..color = _WelcomePalette.paper);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) => false;
}

class _TipSection extends StatelessWidget {
  const _TipSection({required this.animation, required this.wide});

  final Animation<double> animation;
  final bool wide;

  static const List<_TipData> _tips = <_TipData>[
    _TipData(
      step: '1',
      title: '一步一步帶你完成',
      body: '每次只做一小步，不會一次把所有事情交給你。',
    ),
    _TipData(
      step: '2',
      title: '不用擔心做錯',
      body: '需要填的地方會先提醒，重要內容也可以再確認。',
    ),
    _TipData(
      step: '3',
      title: '其他設定之後再完成',
      body: '先把旅社建立起來，其餘功能進後台再慢慢完成。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      for (int i = 0; i < _tips.length; i++)
        _TipReveal(
          animation: animation,
          index: i,
          child: _TipCard(tip: _tips[i], compact: !wide),
        ),
    ];
    if (!wide) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _WelcomePalette.paper.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _WelcomePalette.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < cards.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(height: 1, color: _WelcomePalette.line),
                cards[i],
              ],
            ],
          ),
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _TipReveal extends StatelessWidget {
  const _TipReveal({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double start = index * 0.16;
        final double t = ((animation.value - start) / (1 - start))
            .clamp(0, 1)
            .toDouble();
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _TipData {
  const _TipData({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, required this.compact});

  final _TipData tip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Widget mark = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _WelcomePalette.sageSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        tip.step,
        style: text.labelLarge?.copyWith(
          color: _WelcomePalette.sageDeep,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tip.title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: _WelcomePalette.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          tip.body,
          style: text.bodySmall?.copyWith(
            height: 1.4,
            color: _WelcomePalette.blueGray,
          ),
        ),
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            mark,
            const SizedBox(width: 10),
            Expanded(child: copy),
          ],
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _WelcomePalette.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _WelcomePalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            mark,
            const SizedBox(height: 10),
            copy,
          ],
        ),
      ),
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({
    required this.wide,
    required this.onStart,
    required this.onBack,
    this.docked = true,
  });

  final bool wide;
  final bool docked;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: docked ? const Color(0xF7FFF6EE) : const Color(0x00FFF6EE),
        border: docked
            ? const Border(top: BorderSide(color: _WelcomePalette.line))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 32 : 16, docked ? 12 : 4, wide ? 32 : 16, 6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StartButton(onPressed: onStart),
                TextButton(
                  onPressed: onBack,
                  child: Text(
                    '先返回',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _WelcomePalette.blueGray,
                      fontWeight: FontWeight.w700,
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
}

class _StartButton extends StatefulWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _WelcomePalette.ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x33172238),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const SizedBox(
            height: 52,
            child: Center(
              child: Text(
                '開始打造我的旅社 →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFF6EE),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
