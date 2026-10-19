// 我的店家專用：實體屋面、山牆、屋簷與閣樓窗。純繪圖，不讀寫店家資料。
import 'package:flutter/material.dart';

double warmWoodScale(double width) =>
    (width / 900).clamp(0.58, 1.28).toDouble();

void paintWarmWoodHouseRoof(
  Canvas canvas,
  Size size, {
  required double wallLeft,
  required double wallRight,
  required double wallTop,
  required double slotBottom,
  required bool dark,
}) {
  if (size.width < 8 || wallTop < 24) return;
  Color tone(Color color) => dark
      ? Color.alphaBlend(color.withValues(alpha: .65), const Color(0xFF302820))
      : color;
  final double mid = size.width / 2;
  final double top = 8;
  final double eave = wallTop - 9;
  final double left = (wallLeft - 12).clamp(3.0, wallLeft).toDouble();
  final double right = size.width - left;
  final double rise = eave - top;
  final Path roof = Path()
    ..moveTo(left, eave)
    ..lineTo(size.width * .19, top + 14)
    ..lineTo(size.width * .81, top + 14)
    ..lineTo(right, eave)
    ..close();
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.drawShadow(
    roof,
    const Color(0xFF72543A).withValues(alpha: .24),
    5,
    false,
  );
  canvas.drawPath(
    roof,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tone(const Color(0xFFE7C79E)), tone(const Color(0xFFB98A59))],
      ).createShader(Rect.fromLTRB(left, top, right, eave)),
  );
  canvas.save();
  canvas.clipPath(roof);
  // 細木板接縫跟著屋面透視，避免只有屋頂輪廓。
  final Paint seam = Paint()
    ..color = tone(const Color(0xFF8E6944)).withValues(alpha: .22)
    ..strokeWidth = 1;
  for (int i = 1; i < 8; i++) {
    final double y = top + 14 + (rise - 14) * i / 8;
    canvas.drawLine(Offset(left, y), Offset(right, y), seam);
    canvas.drawLine(
      Offset(left, y + 1.5),
      Offset(right, y + 1.5),
      Paint()..color = Colors.white.withValues(alpha: .16),
    );
  }
  for (int i = 0; i <= 18; i++) {
    final double x = left + (right - left) * i / 18;
    canvas.drawLine(Offset(mid + (x - mid) * .64, top), Offset(x, eave), seam);
  }
  canvas.restore();
  final Rect fascia = Rect.fromLTRB(left, eave, right, slotBottom - 2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(fascia, const Radius.circular(3)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tone(const Color(0xFFE7C79E)),
          tone(const Color(0xFFBD9367)),
          tone(const Color(0xFF96704D)),
        ],
      ).createShader(fascia),
  );
  canvas.drawLine(
    Offset(left + 2, eave + 4),
    Offset(right - 2, eave + 4),
    Paint()
      ..color = const Color(0xFFFFEAD0)
      ..strokeWidth = 2,
  );
  // 中央山牆與圓窗讓屋頂有真實厚度，也與下方奶油白牆銜接。
  final double half = (size.width * .16).clamp(44.0, 154.0).toDouble();
  final Path gable = Path()
    ..moveTo(mid - half, eave + 5)
    ..lineTo(mid, top)
    ..lineTo(mid + half, eave + 5)
    ..close();
  canvas.drawShadow(
    gable,
    const Color(0xFF72543A).withValues(alpha: .25),
    3,
    false,
  );
  canvas.drawPath(gable, Paint()..color = tone(const Color(0xFFFFF7EB)));
  canvas.save();
  canvas.clipPath(gable);
  for (double y = top + 12; y < eave; y += 9) {
    canvas.drawLine(
      Offset(mid - half, y),
      Offset(mid + half, y),
      Paint()
        ..color = tone(const Color(0xFFE4D3BC))
        ..strokeWidth = .7,
    );
  }
  canvas.restore();
  final Path trim = Path()
    ..moveTo(mid - half - 4, eave + 6)
    ..lineTo(mid, top)
    ..lineTo(mid + half + 4, eave + 6);
  canvas.drawPath(
    trim,
    Paint()
      ..color = tone(const Color(0xFF9F764F))
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 9,
  );
  canvas.drawPath(
    trim.shift(const Offset(0, -1)),
    Paint()
      ..color = tone(const Color(0xFFE8C99F))
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4,
  );
  final double radius = (rise * .15).clamp(9.0, 18.0).toDouble();
  final Offset center = Offset(mid, top + rise * .66);
  canvas.drawCircle(
    center,
    radius + 4,
    Paint()..color = tone(const Color(0xFFC5A279)),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = LinearGradient(
        colors: [tone(const Color(0xFFE9F0E9)), tone(const Color(0xFFB4CBC4))],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
  final Paint frame = Paint()
    ..color = tone(const Color(0xFFFFF8E9))
    ..strokeWidth = 2.5;
  canvas.drawLine(
    center.translate(-radius, 0),
    center.translate(radius, 0),
    frame,
  );
  canvas.drawLine(
    center.translate(0, -radius),
    center.translate(0, radius),
    frame,
  );
  canvas.restore();
}
