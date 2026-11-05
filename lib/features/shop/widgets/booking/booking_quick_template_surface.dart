import 'booking_cream_header.dart';
import 'booking_editorial_design.dart';
import 'package:flutter/material.dart';

/// 兩款參考圖的可操作介面骨架；圖像僅負責插畫，文字與控制項保留原生。
class BookingQuickTemplateSurface extends StatelessWidget {
  const BookingQuickTemplateSurface({
    super.key,
    required this.style,
    required this.shopName,
    required this.pets,
    required this.dates,
    required this.reminder,
    required this.campaign,
  });
  final String style, shopName;
  final Widget pets, dates, reminder, campaign;
  static const heroAsset = 'assets/images/booking_cream_hero_v1.png';
  @override
  Widget build(BuildContext context) {
    final cream = style == 'cream';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cream) ...[
          BookingCreamHeader(shopName: shopName, step: 1),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(
              painter: _RoofPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 34, 20, 22),
                child: Column(
                  children: [
                    _brand(cream),
                    const SizedBox(height: 18),
                    const Text(
                      '預約資料',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF253B4A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const SizedBox(height: 12),
        pets,
        const SizedBox(height: 20),
        dates,
        const SizedBox(height: 18),
        Container(
          padding: EdgeInsets.all(cream ? 10 : 4),
          decoration: BoxDecoration(
            color: cream ? BookingEditorial.tint(context) : Colors.white,
            borderRadius: BorderRadius.circular(cream ? 28 : 18),
            border: cream ? null : Border.all(color: const Color(0xFFD5DEE4)),
          ),
          child: reminder,
        ),
        campaign,
        const SizedBox(height: 18),
        if (!cream)
          Row(
            children: [
              Text(
                '1/3',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cream
                      ? const Color(0xFF4E9BD1)
                      : const Color(0xFF4788B6),
                ),
              ),
              const SizedBox(width: 12),
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFF60A8D8)
                          : const Color(0xFFE1E6EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
    return DefaultTextStyle.merge(
      style: TextStyle(
        fontFamily: cream
            ? BookingEditorial.body(14, context).fontFamily
            : null,
        color: cream
            ? BookingEditorial.theme(context).textColor
            : const Color(0xFF253B4A),
      ),
      child: content,
    );
  }

  Widget _brand(bool cream) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PetNest',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: cream
                    ? const Color(0xFF6A4933)
                    : const Color(0xFF4788B6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shopName,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      if (!cream)
        const Icon(Icons.home_outlined, size: 44, color: Color(0xFF86B2D1)),
    ],
  );
}

class _RoofPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFD8EBF7),
    );
    final roof = Path()
      ..moveTo(0, size.height * .5)
      ..quadraticBezierTo(
        size.width * .2,
        size.height * .31,
        size.width * .5,
        14,
      )
      ..quadraticBezierTo(
        size.width * .8,
        size.height * .31,
        size.width,
        size.height * .5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFFFFAF3));
  }

  @override
  bool shouldRepaint(covariant _RoofPainter oldDelegate) => false;
}
