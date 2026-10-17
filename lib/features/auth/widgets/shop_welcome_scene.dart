// 檔案名稱：lib/features/auth/widgets/shop_welcome_scene.dart
// 功能說明：貓咪住宿歡迎頁的庭院場景。只負責繪圖與角色動畫，不建立店家。

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 貓咪住宿開店歡迎的主視覺。
///
/// 之後若要換成狗狗住宿或其他服務，可替換這個元件，不必改歡迎頁的導航。
class ShopWelcomeScene extends StatefulWidget {
  const ShopWelcomeScene({super.key, this.replacement});

  /// 預留給日後的專屬插畫。提供時不再繪製內建貓咪。
  final Widget? replacement;

  @override
  State<ShopWelcomeScene> createState() => _ShopWelcomeSceneState();
}

class _ShopWelcomeSceneState extends State<ShopWelcomeScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _life;
  late final AnimationController _react;
  bool _reduceMotion = false;
  bool _playLife = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _life = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    );
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant ShopWelcomeScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncMotion();
    });
  }

  void _syncMotion() {
    final bool covered = ModalRoute.of(context)?.isCurrent == false;
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    final bool hidden =
        !TickerMode.of(context) ||
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden;
    _playLife =
        widget.replacement == null && !_reduceMotion && !covered && !hidden;
    if (_playLife) {
      if (!_life.isAnimating) _life.repeat();
    } else {
      _life.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _life.dispose();
    _react.dispose();
    super.dispose();
  }

  void _greet() {
    if (!_playLife || _react.isAnimating) return;
    _react.forward(from: 0);
  }

  _WelcomePose _pose() {
    if (widget.replacement != null || _reduceMotion) {
      return const _WelcomePose();
    }
    final double t = _life.value;
    final double breath = math.sin(t * math.pi * 2);
    final double sway = math.sin(t * math.pi * 4 + 0.5);
    final double blink = _blinkWindow(t, 0.74);
    final double react = _react.value;
    final double tilt = math.sin(react * math.pi) * -0.07;
    final double reactBlink = react > 0 && react < 0.34
        ? math.sin((react / 0.34) * math.pi)
        : 0;
    final double wag = react == 0 ? 0 : math.sin(react * math.pi * 3) * 0.85;
    return _WelcomePose(
      breath: breath,
      tail: (sway * 0.55 + wag).clamp(-1.3, 1.3),
      blink: math.max(blink, reactBlink).clamp(0, 1),
      tilt: tilt,
    );
  }

  double _blinkWindow(double t, double center) {
    const double half = 0.032;
    final double distance = (t - center).abs();
    if (distance >= half) return 0;
    return math.cos((distance / half) * math.pi / 2);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '貓咪旅社的溫暖歡迎插畫',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_life, _react]),
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: _InnScenePainter(
                        pose: _pose(),
                        drawCat: widget.replacement == null,
                      ),
                      child: child,
                    );
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              if (widget.replacement != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: widget.replacement,
                  ),
                )
              else
                Align(
                  alignment: const Alignment(0.34, 0.2),
                  child: FractionallySizedBox(
                    widthFactor: 0.46,
                    heightFactor: 0.78,
                    child: Semantics(
                      button: true,
                      label: '摸摸貓咪',
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _greet,
                        child: const SizedBox.expand(),
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

class _WelcomePose {
  const _WelcomePose({
    this.breath = 0,
    this.tail = 0,
    this.blink = 0,
    this.tilt = 0,
  });

  final double breath;
  final double tail;
  final double blink;
  final double tilt;

  @override
  bool operator ==(Object other) {
    return other is _WelcomePose &&
        other.breath == breath &&
        other.tail == tail &&
        other.blink == blink &&
        other.tilt == tilt;
  }

  @override
  int get hashCode => Object.hash(breath, tail, blink, tilt);
}

class _InnScenePainter extends CustomPainter {
  const _InnScenePainter({required this.pose, required this.drawCat});

  final _WelcomePose pose;
  final bool drawCat;

  static const double _designW = 720;
  static const double _designH = 430;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    final double scale = math.min(size.width / _designW, size.height / _designH);
    canvas.save();
    canvas.translate(
      (size.width - _designW * scale) / 2,
      (size.height - _designH * scale) / 2,
    );
    canvas.scale(scale);
    _paintGarden(canvas);
    _paintInn(canvas);
    _paintDetails(canvas);
    if (drawCat) _paintCat(canvas, pose);
    canvas.restore();
  }

  void _paintSky(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFFFFAF5),
            Color(0xFFF7EADC),
            Color(0xFFF1E7D9),
          ],
          stops: <double>[0, 0.62, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.16),
      size.shortestSide * 0.28,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFE3C4).withValues(alpha: 0.95),
            const Color(0xFFFFE3C4).withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.84, size.height * 0.16),
            radius: size.shortestSide * 0.28,
          ),
        ),
    );
  }

  void _paintGarden(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(360, 318), width: 760, height: 150),
      Paint()..color = const Color(0xFFD5E3D2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(250, 292), width: 280, height: 70),
      Paint()..color = const Color(0xFFC9D9C4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(390, 356), width: 520, height: 78),
      Paint()..color = const Color(0xFFF4E4D4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(430, 368), width: 250, height: 28),
      Paint()..color = const Color(0xFFE7D3C0),
    );
    _paintPaw(canvas, const Offset(300, 348), 0.7, -0.4);
    _paintPaw(canvas, const Offset(338, 362), 0.55, -0.2);
    _paintTuft(canvas, const Offset(96, 332));
    _paintTuft(canvas, const Offset(620, 338));
    _paintFlower(canvas, const Offset(250, 338));
  }

  void _paintInn(Canvas canvas) {
    _softShadow(canvas, const Offset(176, 318), 150, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(118, 176, 132, 128),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFD7C3AE),
    );
    final RRect wall = RRect.fromRectAndRadius(
      const Rect.fromLTWH(86, 168, 150, 140),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      wall,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFFCF8), Color(0xFFF3E4D4)],
        ).createShader(wall.outerRect),
    );

    final Path roof = Path()
      ..moveTo(64, 186)
      ..quadraticBezierTo(122, 112, 161, 96)
      ..quadraticBezierTo(206, 112, 262, 186)
      ..lineTo(244, 198)
      ..quadraticBezierTo(198, 136, 161, 122)
      ..quadraticBezierTo(126, 136, 82, 198)
      ..close();
    canvas.drawPath(
      roof,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF9BB392), Color(0xFF6E8B68)],
        ).createShader(const Rect.fromLTWH(64, 90, 200, 110)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(78, 178)
        ..quadraticBezierTo(128, 128, 161, 116)
        ..quadraticBezierTo(198, 130, 246, 178),
      Paint()
        ..color = const Color(0xFFF7F3EA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(196, 108, 22, 36),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFC47A62),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(192, 102, 30, 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFA86450),
    );

    final Offset window = const Offset(132, 228);
    canvas.drawCircle(
      window,
      24,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF1D2),
            const Color(0xFFF0B56A),
          ],
        ).createShader(Rect.fromCircle(center: window, radius: 24)),
    );
    canvas.drawCircle(
      window,
      24,
      Paint()
        ..color = const Color(0xFF8C6A4E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final Paint mullion = Paint()
      ..color = const Color(0xFF8C6A4E)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(window.translate(-14, 0), window.translate(14, 0), mullion);
    canvas.drawLine(window.translate(0, -14), window.translate(0, 14), mullion);

    final RRect door = RRect.fromRectAndRadius(
      const Rect.fromLTWH(176, 220, 42, 88),
      const Radius.circular(18),
    );
    canvas.drawRRect(door, Paint()..color = const Color(0xFF8C5E42));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(182, 232, 30, 28),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFA87558),
    );
    canvas.drawCircle(
      const Offset(208, 268),
      3.2,
      Paint()..color = const Color(0xFFF6E2C4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(168, 304, 58, 8),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFC4A484),
    );
    _paintPot(canvas, const Offset(78, 300));
  }

  // 用柔和的室內生活細節，讓場景更像真正的貓咪旅社，而非孤立圖形。
  void _paintDetails(Canvas canvas) {
    final Paint glow = Paint()..color = const Color(0xFFFFF7E7).withValues(alpha: 0.9);
    for (final Offset p in <Offset>[
      const Offset(292, 146),
      const Offset(624, 165),
      const Offset(314, 266),
    ]) {
      canvas.drawCircle(p, 3.4, glow);
      canvas.drawLine(p.translate(-8, 0), p.translate(8, 0),
          Paint()..color = const Color(0xFFE4BD8D)..strokeWidth = 1.6);
      canvas.drawLine(p.translate(0, -8), p.translate(0, 8),
          Paint()..color = const Color(0xFFE4BD8D)..strokeWidth = 1.6);
    }
    // 門口的小歡迎牌
    final RRect sign = RRect.fromRectAndRadius(
      const Rect.fromLTWH(98, 176, 91, 23), const Radius.circular(11));
    canvas.drawRRect(sign, Paint()..color = const Color(0xFFFFFCF7));
    final TextPainter welcome = TextPainter(
      text: const TextSpan(
        text: 'PETNEST',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
          letterSpacing: 1.1, color: Color(0xFF956D53)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    welcome.paint(canvas, const Offset(112, 181));
    // 暖色系地毯與小玩具，增添生活感。
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(470, 376), width: 256, height: 30),
      Paint()..color = const Color(0xFFF8E9D9).withValues(alpha: 0.78),
    );
    canvas.drawCircle(const Offset(626, 360), 13,
        Paint()..color = const Color(0xFFD7A98C));
    canvas.drawArc(const Rect.fromLTWH(616, 350, 20, 20), -0.7, 2.5, false,
        Paint()..color = const Color(0xFFFFF4E9)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _paintCat(Canvas canvas, _WelcomePose pose) {
    _softShadow(canvas, const Offset(470, 368), 168, 18);
    canvas.save();
    canvas.translate(548, 328);
    canvas.rotate(pose.tail * 0.2);
    canvas.translate(-548, -328);
    _paintTail(canvas);
    canvas.restore();

    canvas.save();
    canvas.translate(468, 362);
    canvas.scale(1 + pose.breath * 0.016, 1 + pose.breath * 0.03);
    canvas.translate(-468, -362);
    _paintBody(canvas);
    canvas.restore();

    canvas.save();
    canvas.translate(462, 248);
    canvas.rotate(pose.tilt);
    canvas.translate(0, pose.breath * -1.6);
    canvas.translate(-462, -248);
    _paintHead(canvas, pose.blink);
    canvas.restore();
  }

  void _paintTail(Canvas canvas) {
    final Path tail = Path()
      ..moveTo(548, 328)
      ..cubicTo(610, 336, 648, 286, 612, 246);
    canvas.drawPath(
      tail,
      Paint()
        ..color = const Color(0xFFC99572)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      tail,
      Paint()
        ..color = const Color(0xFFE7CDB4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBody(Canvas canvas) {
    final Path body = Path()
      ..moveTo(392, 338)
      ..cubicTo(368, 292, 392, 252, 452, 246)
      ..cubicTo(520, 238, 572, 268, 576, 318)
      ..cubicTo(580, 356, 536, 378, 474, 376)
      ..cubicTo(418, 374, 396, 358, 392, 338)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFEBCFB6), Color(0xFFC99572), Color(0xFFB88868)],
          stops: <double>[0, 0.55, 1],
        ).createShader(const Rect.fromLTWH(360, 230, 230, 160)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(528, 322), width: 78, height: 86),
      Paint()..color = const Color(0xFFC49270),
    );
    final Path belly = Path()
      ..moveTo(430, 278)
      ..cubicTo(404, 304, 412, 348, 456, 360)
      ..cubicTo(508, 372, 538, 340, 522, 300)
      ..cubicTo(508, 270, 462, 262, 430, 278)
      ..close();
    canvas.drawPath(belly, Paint()..color = const Color(0xFFFFF6EE));
    _paintPawShape(canvas, const Offset(424, 358));
    _paintPawShape(canvas, const Offset(492, 362));
  }

  void _paintPawShape(Canvas canvas, Offset center) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 36, height: 22),
      Paint()..color = const Color(0xFFD7B08E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 2),
        width: 22,
        height: 12,
      ),
      Paint()..color = const Color(0xFFF3D2C0),
    );
  }

  void _paintHead(Canvas canvas, double blink) {
    final Paint ear = Paint()..color = const Color(0xFFC49270);
    final Paint innerEar = Paint()..color = const Color(0xFFF2C3B6);
    canvas.drawPath(
      Path()
        ..moveTo(384, 168)
        ..quadraticBezierTo(372, 92, 432, 78)
        ..quadraticBezierTo(454, 118, 442, 176)
        ..close(),
      ear,
    );
    canvas.drawPath(
      Path()
        ..moveTo(486, 170)
        ..quadraticBezierTo(512, 96, 566, 118)
        ..quadraticBezierTo(548, 156, 524, 184)
        ..close(),
      ear,
    );
    canvas.drawPath(
      Path()
        ..moveTo(398, 160)
        ..quadraticBezierTo(394, 118, 430, 104)
        ..quadraticBezierTo(444, 132, 434, 166)
        ..close(),
      innerEar,
    );
    canvas.drawPath(
      Path()
        ..moveTo(496, 166)
        ..quadraticBezierTo(516, 122, 548, 132)
        ..quadraticBezierTo(532, 156, 514, 176)
        ..close(),
      innerEar,
    );

    final Rect head = Rect.fromCenter(
      center: const Offset(462, 196),
      width: 178,
      height: 156,
    );
    canvas.drawOval(
      head,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.28, -0.4),
          radius: 0.95,
          colors: <Color>[
            Color(0xFFF4E0CE),
            Color(0xFFDDB892),
            Color(0xFFC49270),
          ],
          stops: <double>[0.12, 0.58, 1],
        ).createShader(head),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(462, 222), width: 92, height: 62),
      Paint()..color = const Color(0xFFFFF6EE),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(396, 214), width: 34, height: 20),
      Paint()..color = const Color(0xFFE7A898).withValues(alpha: 0.4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(528, 212), width: 34, height: 20),
      Paint()..color = const Color(0xFFE7A898).withValues(alpha: 0.4),
    );

    _paintEye(canvas, const Offset(422, 190), blink, -1);
    _paintEye(canvas, const Offset(504, 188), blink, 1);

    final Path nose = Path()
      ..moveTo(462, 214)
      ..lineTo(453, 226)
      ..quadraticBezierTo(462, 233, 471, 226)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFD98986));
    canvas.drawCircle(
      const Offset(458, 222),
      1.8,
      Paint()..color = const Color(0xFFFFF6EE).withValues(alpha: 0.85),
    );
    final Paint mouth = Paint()
      ..color = const Color(0xFF8C5E55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(462, 232)
        ..quadraticBezierTo(450, 244, 436, 236),
      mouth,
    );
    canvas.drawPath(
      Path()
        ..moveTo(462, 232)
        ..quadraticBezierTo(474, 244, 488, 236),
      mouth,
    );
    _paintWhiskers(canvas);

    canvas.drawArc(
      Rect.fromCenter(center: const Offset(462, 258), width: 86, height: 30),
      0.2,
      2.75,
      false,
      Paint()
        ..color = const Color(0xFF6E8B68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(462, 274),
      8,
      Paint()..color = const Color(0xFFE2B15A),
    );
    canvas.drawCircle(
      const Offset(462, 274),
      8,
      Paint()
        ..color = const Color(0xFF8C6A3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  void _paintEye(Canvas canvas, Offset center, double blink, double side) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final double open = (1 - blink).clamp(0.08, 1);
    canvas.scale(1, open);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 28, height: 32),
      Paint()..color = const Color(0xFFFFFBF6),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: 18, height: 22),
      Paint()..color = const Color(0xFF3E4F3C),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 3), width: 8, height: 16),
      Paint()..color = const Color(0xFF1C1916),
    );
    canvas.drawCircle(
      const Offset(-4, -6),
      3.1,
      Paint()..color = const Color(0xFFFFFBF6),
    );
    canvas.drawCircle(
      Offset(3.5 * side, 2),
      1.5,
      Paint()..color = const Color(0xFFFFFBF6).withValues(alpha: 0.85),
    );
    canvas.restore();
    if (blink > 0.45) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 26, height: 14),
        0.1,
        2.9,
        false,
        Paint()
          ..color = const Color(0xFF8C6A55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintWhiskers(Canvas canvas) {
    final Paint whisker = Paint()
      ..color = const Color(0xFF6A5344).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    const Offset left = Offset(430, 228);
    const Offset right = Offset(494, 228);
    canvas.drawLine(left, left.translate(-48, -10), whisker);
    canvas.drawLine(left, left.translate(-52, 2), whisker);
    canvas.drawLine(left, left.translate(-46, 14), whisker);
    canvas.drawLine(right, right.translate(48, -10), whisker);
    canvas.drawLine(right, right.translate(52, 2), whisker);
    canvas.drawLine(right, right.translate(46, 14), whisker);
  }

  void _paintPot(Canvas canvas, Offset base) {
    final Path pot = Path()
      ..moveTo(base.dx - 16, base.dy - 8)
      ..lineTo(base.dx - 12, base.dy + 16)
      ..quadraticBezierTo(base.dx, base.dy + 22, base.dx + 12, base.dy + 16)
      ..lineTo(base.dx + 16, base.dy - 8)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFFC47A62));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: base.translate(0, -10),
          width: 36,
          height: 8,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFA86450),
    );
    final Paint leaf = Paint()..color = const Color(0xFF6E8B68);
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(-8, -28),
        width: 16,
        height: 28,
      ),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(8, -32),
        width: 16,
        height: 30,
      ),
      Paint()..color = const Color(0xFF8EAE86),
    );
  }

  void _paintFlower(Canvas canvas, Offset center) {
    final Paint petal = Paint()..color = const Color(0xFFF2B7AE);
    for (int i = 0; i < 5; i++) {
      final double angle = i * math.pi * 2 / 5;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(math.cos(angle) * 6, math.sin(angle) * 6),
          width: 8,
          height: 8,
        ),
        petal,
      );
    }
    canvas.drawCircle(center, 3.2, Paint()..color = const Color(0xFFE2B15A));
  }

  void _paintTuft(Canvas canvas, Offset base) {
    final Paint blade = Paint()
      ..color = const Color(0xFF7E9A78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, base.translate(-4, -16), blade);
    canvas.drawLine(base, base.translate(2, -18), blade);
    canvas.drawLine(base, base.translate(8, -14), blade);
  }

  void _paintPaw(Canvas canvas, Offset center, double scale, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    final Paint ink = Paint()..color = const Color(0xFFC4A484).withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 4), width: 14, height: 12),
      ink,
    );
    canvas.drawCircle(const Offset(-6, -6), 3.1, ink);
    canvas.drawCircle(const Offset(0, -8), 3.2, ink);
    canvas.drawCircle(const Offset(6, -6), 3.1, ink);
    canvas.restore();
  }

  void _softShadow(Canvas canvas, Offset center, double width, double height) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: width + 28,
        height: height + 10,
      ),
      Paint()..color = const Color(0xFF8C6A4E).withValues(alpha: 0.08),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      Paint()..color = const Color(0xFF8C6A4E).withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _InnScenePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.drawCat != drawCat;
  }
}
