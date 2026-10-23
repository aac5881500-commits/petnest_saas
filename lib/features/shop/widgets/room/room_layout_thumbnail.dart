// 功能：各瀏覽結構的排版示意，不使用正式圖片或假房型資料。
import 'package:flutter/material.dart';

class RoomLayoutThumbnail extends StatelessWidget {
  const RoomLayoutThumbnail({
    super.key,
    required this.layout,
    this.detail = false,
  });
  final String layout;
  final bool detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    width: 180,
    child: CustomPaint(
      painter: _LayoutPainter(
        layout,
        Theme.of(context).colorScheme.primary,
        detail,
      ),
    ),
  );
}

class _LayoutPainter extends CustomPainter {
  _LayoutPainter(this.layout, this.color, this.detail);
  final String layout;
  final Color color;
  final bool detail;
  @override
  void paint(Canvas canvas, Size size) {
    void box(double x, double y, double w, double h, [double alpha = .22]) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            const Radius.circular(3),
          ),
          Paint()..color = color.withValues(alpha: alpha),
        );
    void lines(double x, double y, double w) {
      box(x, y, w, 4, .65);
      box(x, y + 8, w * .7, 3, .4);
    }

    if (layout == 'lodging' && detail) {
      box(0, 0, 170, 30);
      box(4, 27, 162, 24, .38);
      lines(12, 32, 120);
      box(0, 55, 170, 10, .65);
      return;
    }
    switch (layout) {
      case 'horizontal':
      case 'sideBySide':
        box(0, 2, 70, 58);
        lines(80, 10, 75);
        box(80, 38, 62, 16);
        break;
      case 'columns':
      case 'lodging':
        for (var i = 0; i < 3; i++) {
          box(i * 58, 2, 50, layout == 'lodging' ? 38 : 26);
          lines(i * 58, layout == 'lodging' ? 44 : 34, 46);
        }
        if (layout == 'lodging') {
          for (var i = 0; i < 3; i++) {
            box(i * 58 + 18, 30, 14, 3, .8);
          }
        }
        break;
      case 'comparison':
        for (var i = 0; i < 2; i++) {
          box(i * 85, 0, 76, 14, .6);
          box(i * 85, 18, 76, 18);
          for (var j = 0; j < 3; j++) {
            box(i * 85, 40 + j * 8, 76, 5, .3);
          }
        }
        break;
      case 'carousel':
        box(0, 0, 130, 40);
        lines(0, 44, 125);
        box(140, 0, 35, 58);
        break;
      case 'switcher':
        for (var i = 0; i < 3; i++) {
          box(i * 55, 0, 48, 10, .6);
        }
        box(0, 16, 72, 45);
        lines(82, 22, 82);
        break;
      case 'tabs':
        box(0, 0, 170, 25);
        for (var i = 0; i < 3; i++) {
          box(i * 57, 30, 50, 9, .6);
        }
        lines(0, 46, 165);
        break;
      case 'panel':
        box(0, 0, 170, 52);
        box(8, 29, 154, 35, .6);
        box(65, 34, 40, 3, .9);
        lines(18, 43, 120);
        break;
      case 'anchors':
        for (var i = 0; i < 3; i++) {
          box(i * 57, 0, 50, 9, .6);
        }
        box(0, 14, 170, 20);
        lines(0, 40, 165);
        lines(0, 55, 165);
        break;
      case 'compact':
        box(0, 0, 170, 26);
        for (var i = 0; i < 3; i++) {
          box(i * 57, 31, 50, 12, .5);
        }
        lines(0, 49, 165);
        break;
      default:
        box(0, 0, 170, 32);
        lines(0, 38, 165);
        box(0, 57, 170, 5);
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutPainter old) =>
      old.layout != layout || old.color != color || old.detail != detail;
}
