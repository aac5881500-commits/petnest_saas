// 檔案名稱：lib/features/shop/widgets/about/service_builtin_artwork.dart
// 功能說明：服務項目內建向量插畫；離線可用、不需上傳或額外圖片查詢。
import 'package:flutter/material.dart';

class ServiceBuiltinArtwork extends StatelessWidget {
  const ServiceBuiltinArtwork({
    super.key,
    required this.serviceId,
    required this.variant,
    required this.accent,
    required this.fallbackIcon,
  });
  final String serviceId, variant;
  final Color accent;
  final IconData fallbackIcon;
  @override
  Widget build(BuildContext context) => variant == 'simple'
      ? Center(child: Icon(fallbackIcon, size: 30, color: accent))
      : CustomPaint(
          painter: _ServiceIllustration(serviceId, variant, accent),
          child: const SizedBox.expand(),
        );
}

class _ServiceIllustration extends CustomPainter {
  const _ServiceIllustration(this.id, this.variant, this.accent);
  final String id, variant;
  final Color accent;
  bool get sticker => variant == 'sticker';
  bool get postcard => variant == 'postcard';
  Color get ink => sticker ? const Color(0xFF383452) : const Color(0xFF79594C);
  @override
  void paint(Canvas canvas, Size size) {
    final bg = postcard
        ? const Color(0xFFF7EAD4)
        : sticker
        ? const Color(0xFFE8E8FF)
        : const Color(0xFFFFF2E8);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final scale = size.shortestSide / 100;
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = sticker ? 3.2 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void shape(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, line);
    }

    void box(Rect rect, Color color, double radius) {
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rr, Paint()..color = color);
      canvas.drawRRect(rr, line);
    }

    void dot(double x, double y, double r, Color color) =>
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
    void stroke(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), line);
    if (postcard) {
      box(const Rect.fromLTWH(8, 10, 84, 80), const Color(0xFFFFFCF5), 5);
      canvas.drawRect(
        const Rect.fromLTWH(14, 16, 72, 58),
        Paint()..color = const Color(0xFFE2EFDB),
      );
      dot(73, 28, 8, const Color(0xFFF5CB73));
      stroke(24, 82, 57, 82);
      stroke(64, 82, 76, 82);
      canvas.save();
      canvas.translate(7, 4);
      canvas.scale(.85);
    } else if (sticker) {
      final stickerPath = Path()
        ..moveTo(18, 18)
        ..lineTo(70, 10)
        ..quadraticBezierTo(92, 13, 89, 40)
        ..lineTo(94, 73)
        ..quadraticBezierTo(83, 94, 60, 87)
        ..lineTo(27, 93)
        ..quadraticBezierTo(5, 85, 11, 60)
        ..lineTo(7, 37)
        ..quadraticBezierTo(7, 21, 18, 18)
        ..close();
      canvas.drawPath(stickerPath, Paint()..color = const Color(0xFFFFDA79));
      canvas.drawPath(
        stickerPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      dot(80, 20, 4, const Color(0xFFCF9EFA));
      dot(18, 80, 5, const Color(0xFFF89D9C));
    } else {
      dot(51, 50, 37, const Color(0xFFFFE0C3));
      dot(17, 23, 4, const Color(0xFFB9D7C4));
      dot(85, 72, 5, const Color(0xFFE5B5BD));
      stroke(81, 19, 81, 27);
      stroke(77, 23, 85, 23);
    }
    final fur = id == 'dog_hotel'
        ? const Color(0xFFC89B77)
        : const Color(0xFFFFCA79);
    if (id == 'cat_hotel' || id == 'dog_hotel') {
      // 旅店小屋、床墊與動物表情，避免僅以固定圖示換色。
      shape(
        Path()
          ..moveTo(16, 45)
          ..lineTo(50, 16)
          ..lineTo(84, 45)
          ..close(),
        postcard ? const Color(0xFFB8C8B4) : const Color(0xFFD99B88),
      );
      box(const Rect.fromLTWH(24, 43, 52, 39), const Color(0xFFFFFAEF), 5);
      box(const Rect.fromLTWH(23, 73, 54, 11), const Color(0xFFB8D5CF), 5);
      if (id == 'cat_hotel') {
        shape(
          Path()
            ..moveTo(31, 58)
            ..lineTo(31, 39)
            ..lineTo(44, 48)
            ..lineTo(58, 48)
            ..lineTo(70, 39)
            ..lineTo(69, 60)
            ..close(),
          fur,
        );
      } else {
        canvas.drawOval(
          const Rect.fromLTWH(26, 43, 15, 29),
          Paint()..color = const Color(0xFF98715F),
        );
        canvas.drawOval(
          const Rect.fromLTWH(63, 43, 15, 29),
          Paint()..color = const Color(0xFF98715F),
        );
      }
      canvas.drawOval(
        const Rect.fromLTWH(32, 46, 37, 31),
        Paint()..color = fur,
      );
      canvas.drawOval(const Rect.fromLTWH(32, 46, 37, 31), line);
      dot(42, 59, 1.8, ink);
      dot(59, 59, 1.8, ink);
      dot(50, 65, 2.2, ink);
      stroke(50, 66, 47, 69);
      stroke(50, 66, 54, 69);
      dot(37, 65, 2.6, const Color(0xFFF2A398));
      dot(64, 65, 2.6, const Color(0xFFF2A398));
    } else if (id == 'grooming') {
      box(const Rect.fromLTWH(20, 50, 62, 25), const Color(0xFFB8DAD8), 10);
      stroke(30, 76, 27, 83);
      stroke(73, 76, 76, 83);
      for (final point in const [
        Offset(35, 43),
        Offset(48, 38),
        Offset(63, 43),
      ]) {
        dot(point.dx, point.dy, 9, Colors.white);
        canvas.drawCircle(point, 9, line);
      }
      canvas.drawCircle(const Offset(30, 23), 7, line);
      canvas.drawCircle(const Offset(45, 23), 7, line);
      stroke(34, 28, 54, 45);
      stroke(41, 28, 24, 45);
      dot(76, 25, 5, Colors.white);
      dot(85, 39, 3, Colors.white);
    } else if (id == 'hospital') {
      box(const Rect.fromLTWH(19, 36, 64, 44), const Color(0xFFB9DBD3), 9);
      box(const Rect.fromLTWH(37, 24, 27, 13), const Color(0xFFFFFCF6), 4);
      final cross = Path()
        ..moveTo(46, 45)
        ..lineTo(57, 45)
        ..lineTo(57, 54)
        ..lineTo(66, 54)
        ..lineTo(66, 64)
        ..lineTo(57, 64)
        ..lineTo(57, 73)
        ..lineTo(46, 73)
        ..lineTo(46, 64)
        ..lineTo(37, 64)
        ..lineTo(37, 54)
        ..lineTo(46, 54)
        ..close();
      shape(cross, const Color(0xFFFFFAF3));
      shape(
        Path()
          ..moveTo(78, 22)
          ..cubicTo(66, 12, 64, 31, 78, 37)
          ..cubicTo(93, 28, 89, 13, 78, 22)
          ..close(),
        const Color(0xFFF1A2A5),
      );
    } else {
      box(const Rect.fromLTWH(23, 33, 55, 51), const Color(0xFFF5BC88), 5);
      canvas.drawArc(
        const Rect.fromLTWH(37, 16, 26, 33),
        3.14,
        3.14,
        false,
        line,
      );
      dot(50, 63, 9, const Color(0xFFFFF7E9));
      for (final p in const [Offset(39, 48), Offset(49, 43), Offset(60, 48)]) {
        dot(p.dx, p.dy, 4, const Color(0xFFFFF7E9));
      }
      stroke(69, 21, 77, 15);
      stroke(76, 26, 85, 25);
    }
    if (postcard) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ServiceIllustration old) =>
      id != old.id || variant != old.variant || accent != old.accent;
}
