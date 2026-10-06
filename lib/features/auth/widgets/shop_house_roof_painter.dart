// 檔案名稱：lib/features/auth/widgets/shop_house_roof_painter.dart
// 功能說明：暖木小屋的程式碼屋頂。左右各一塊屋頂面，加上屋簷厚度、底面、椽木與小吊燈。

import 'package:flutter/material.dart';

const Color _roofLight = Color(0xFFE5C18F);
const Color _roofWarm = Color(0xFFD9AD73);
const Color _roofDeep = Color(0xFFC9965A);
const Color _roofCoffee = Color(0xFF8C6844);
const Color _soffit = Color(0xFFF6E8D4);

Color _tone(Color color, bool dark) {
  if (!dark) {
    return color;
  }
  return Color.alphaBlend(
    color.withValues(alpha: 0.62),
    const Color(0xFF3A3128),
  );
}

/// 依小屋寬度縮放線條。屋頂槽高度仍由外殼決定，這裡不把房子撐高。
double warmWoodScale(double width) {
  if (width <= 0) {
    return 1;
  }
  return (width / 900).clamp(0.58, 1.28).toDouble();
}

void paintWarmWoodHouseRoof(
  Canvas canvas,
  Size size, {
  required double wallLeft,
  required double wallRight,
  required double wallTop,
  required double slotBottom,
  required bool dark,
}) {
  final double width = size.width;
  final double wallWidth = wallRight - wallLeft;
  if (width < 8 || wallWidth < 8 || wallTop < 24) {
    return;
  }
  final double scale = warmWoodScale(width);
  final double overhang = wallWidth * 0.025;
  final double roofLeft = (wallLeft - overhang).clamp(0.0, wallLeft);
  final double roofRight = (wallRight + overhang).clamp(wallRight, width);
  final double available = wallTop - 2;
  final double rise = (width * 0.12).clamp(84.0, 126.0).toDouble();
  final double roofRise = rise > available ? available : rise;
  final double ridgeY = wallTop - roofRise;
  final double eaveY = wallTop + 1;
  final double frontRoom = (slotBottom - 2 - eaveY).clamp(6.0, 12.0).toDouble();
  final double front = (10 * scale).clamp(6.0, frontRoom).toDouble();
  final double mid = width / 2;

  Path face(bool left, double from, double to) {
    final double tip = left ? roofLeft : roofRight;
    return Path()
      ..moveTo(mid, ridgeY + from * 0.4)
      ..lineTo(tip, eaveY + from)
      ..lineTo(tip, eaveY + to)
      ..lineTo(mid, ridgeY + to * 0.4)
      ..close();
  }

  Paint woodPaint(Color color) => Paint()..color = _tone(color, dark);

  final Path shadow = Path()
    ..moveTo(mid, ridgeY)
    ..lineTo(roofLeft, eaveY)
    ..lineTo(roofLeft, eaveY + front)
    ..lineTo(mid, ridgeY + front * 0.4)
    ..lineTo(roofRight, eaveY + front)
    ..lineTo(roofRight, eaveY)
    ..close();

  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.drawPath(
    shadow.shift(Offset(0, 3 * scale)),
    Paint()
      ..color = _tone(_roofCoffee, dark).withValues(alpha: dark ? 0.1 : 0.13)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        (7 * scale).clamp(4, 9).toDouble(),
      ),
  );

  final Rect shadeBounds = Rect.fromLTWH(0, ridgeY, width, eaveY + front);
  canvas.drawPath(face(true, front * 0.9, front), woodPaint(_soffit));
  canvas.drawPath(face(false, front * 0.9, front), woodPaint(_soffit));

  canvas.drawPath(
    face(true, 0, front * 0.46),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          _tone(_roofLight, dark),
          _tone(_roofWarm, dark),
          _tone(_roofDeep, dark),
        ],
      ).createShader(shadeBounds),
  );
  canvas.drawPath(
    face(false, 0, front * 0.46),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          _tone(_roofWarm, dark),
          _tone(_roofDeep, dark),
          _tone(const Color(0xFFB8894C), dark),
        ],
      ).createShader(shadeBounds),
  );

  canvas.drawPath(
    face(true, front * 0.46, front * 0.66),
    woodPaint(_roofLight),
  );
  canvas.drawPath(
    face(false, front * 0.46, front * 0.66),
    woodPaint(_roofLight),
  );
  canvas.drawPath(face(true, front * 0.66, front * 0.78), woodPaint(_roofWarm));
  canvas.drawPath(
    face(false, front * 0.66, front * 0.78),
    woodPaint(_roofWarm),
  );
  canvas.drawPath(
    face(true, front * 0.78, front * 0.9),
    woodPaint(_roofCoffee),
  );
  canvas.drawPath(
    face(false, front * 0.78, front * 0.9),
    woodPaint(_roofCoffee),
  );

  final double capHalf = (15 * scale).clamp(9, 18).toDouble();
  final double capDrop = (7 * scale).clamp(4.5, 9).toDouble();
  final double capTop = ridgeY < 1 ? 1 : ridgeY;
  final Path cap = Path()
    ..moveTo(mid, capTop)
    ..lineTo(mid + capHalf, capTop + capDrop)
    ..lineTo(mid, capTop + capDrop + capDrop * 0.34)
    ..lineTo(mid - capHalf, capTop + capDrop)
    ..close();
  canvas.drawPath(cap, woodPaint(_roofDeep));
  canvas.drawPath(
    Path()
      ..moveTo(mid, capTop + 1)
      ..lineTo(mid - capHalf * 0.72, capTop + capDrop * 0.86)
      ..lineTo(mid - capHalf * 0.2, capTop + capDrop * 0.7)
      ..close(),
    Paint()..color = _tone(_roofLight, dark).withValues(alpha: 0.55),
  );

  final int rafters = width < 430
      ? 2
      : width < 700
      ? 3
      : 4;
  final double rafterW = (4.2 * scale).clamp(2.8, 5.2).toDouble();
  final double rafterH = (8 * scale).clamp(5, 11).toDouble();
  final Paint rafterPaint = Paint()
    ..color = _tone(_roofCoffee, dark).withValues(alpha: dark ? 0.45 : 0.58);
  for (final bool left in const <bool>[true, false]) {
    for (int i = 0; i < rafters; i++) {
      final double t = (i + 1) / (rafters + 1);
      final double x = left
          ? roofLeft + (mid - roofLeft) * (0.16 + 0.42 * t)
          : roofRight - (roofRight - mid) * (0.16 + 0.42 * t);
      final double along = left
          ? (x - roofLeft) / (mid - roofLeft)
          : (roofRight - x) / (roofRight - mid);
      final double y = eaveY + (ridgeY - eaveY) * along + front * 0.72;
      final double room = slotBottom - y;
      final double height = rafterH < room ? rafterH : room;
      if (height < 3 || x < 1 || x > width - 1) {
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + height / 2),
            width: rafterW,
            height: height,
          ),
          Radius.circular(rafterW / 2),
        ),
        rafterPaint,
      );
    }
  }

  final double lamp = (28 * scale).clamp(16, 30).toDouble();
  final double cordTop = ridgeY + front * 0.55;
  final double shadeTop = cordTop + lamp * 0.16;
  final double shadeH = lamp * 0.38;
  final double shadeW = lamp * 0.72;
  final double shadeBottom = shadeTop + shadeH;
  final double bulbR = lamp * 0.11;
  if (shadeBottom + bulbR < wallTop + 6) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(mid, (cordTop + shadeTop) / 2),
          width: (1.1 * scale).clamp(0.8, 1.4).toDouble(),
          height: shadeTop - cordTop,
        ),
        const Radius.circular(1),
      ),
      woodPaint(_roofCoffee),
    );
    canvas.drawPath(
      Path()
        ..moveTo(mid - shadeW * 0.38, shadeTop)
        ..lineTo(mid + shadeW * 0.38, shadeTop)
        ..lineTo(mid + shadeW * 0.62, shadeBottom)
        ..quadraticBezierTo(
          mid,
          shadeBottom + lamp * 0.08,
          mid - shadeW * 0.62,
          shadeBottom,
        )
        ..close(),
      woodPaint(_roofWarm),
    );
    canvas.drawPath(
      Path()
        ..moveTo(mid - shadeW * 0.16, shadeTop + 1.5)
        ..lineTo(mid - shadeW * 0.28, shadeBottom - 2)
        ..lineTo(mid - shadeW * 0.08, shadeBottom - 2)
        ..close(),
      Paint()..color = _tone(_roofLight, dark).withValues(alpha: 0.7),
    );
    final Offset bulb = Offset(mid, shadeBottom + bulbR * 0.2);
    final double halo = lamp * 0.62;
    canvas.drawCircle(
      bulb,
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFE3A3).withValues(alpha: dark ? 0.16 : 0.24),
            const Color(0xFFFFE3A3).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: bulb, radius: halo)),
    );
    canvas.drawCircle(bulb, bulbR, Paint()..color = const Color(0xFFFFC56A));
  }
  canvas.restore();
}
