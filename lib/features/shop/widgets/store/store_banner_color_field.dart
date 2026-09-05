// 檔案名稱：lib/features/shop/widgets/store/store_banner_color_field.dart
// 功能說明：海報常用色 + 自訂 HSV 色盤，保存 ARGB int。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_banner_text_element.dart';

class StoreBannerColorField extends StatelessWidget {
  const StoreBannerColorField({
    super.key,
    required this.label,
    required this.argb,
    required this.onChanged,
    this.brandColor,
  });

  final String label;
  final int argb;
  final ValueChanged<int> onChanged;
  final Color? brandColor;

  @override
  Widget build(BuildContext context) {
    final Color current = Color(argb);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ...StoreBannerCommonColors.swatches.map((item) {
              return _ColorDot(
                color: Color(item.argb),
                label: item.label,
                selected: argb == item.argb,
                onTap: () => onChanged(item.argb),
              );
            }),
            if (brandColor != null)
              _ColorDot(
                color: brandColor!,
                label: '品牌色',
                selected: argb == brandColor!.toARGB32(),
                onTap: () => onChanged(brandColor!.toARGB32()),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final int? next = await showStoreBannerColorPicker(
                  context,
                  initial: current,
                );
                if (next != null) {
                  onChanged(next);
                }
              },
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: const Text('自訂顏色'),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: current,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black26,
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

Future<int?> showStoreBannerColorPicker(
  BuildContext context, {
  required Color initial,
}) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      return _StoreBannerColorPickerDialog(initial: initial);
    },
  );
}

class _StoreBannerColorPickerDialog extends StatefulWidget {
  const _StoreBannerColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_StoreBannerColorPickerDialog> createState() =>
      _StoreBannerColorPickerDialogState();
}

class _StoreBannerColorPickerDialogState
    extends State<_StoreBannerColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hex = TextEditingController(
      text: StoreBannerColorCodec.hexOf(widget.initial.toARGB32()),
    );
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _setHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _hex.text = StoreBannerColorCodec.hexOf(value.toColor().toARGB32());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('選擇顏色'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 150,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return GestureDetector(
                      onPanDown: (DragDownDetails details) {
                        _fromSv(details.localPosition, constraints.biggest);
                      },
                      onPanUpdate: (DragUpdateDetails details) {
                        _fromSv(details.localPosition, constraints.biggest);
                      },
                      child: CustomPaint(
                        size: constraints.biggest,
                        painter: _SvPainter(hue: _hsv.hue),
                        child: Align(
                          alignment: Alignment(
                            (_hsv.saturation * 2) - 1,
                            (1 - _hsv.value) * 2 - 1,
                          ),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _color,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(color: Colors.black26, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 22,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GestureDetector(
                    onPanDown: (DragDownDetails details) {
                      _fromHue(details.localPosition.dx, constraints.maxWidth);
                    },
                    onPanUpdate: (DragUpdateDetails details) {
                      _fromHue(details.localPosition.dx, constraints.maxWidth);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      isDense: true,
                    ),
                    onSubmitted: (String value) {
                      final int parsed = StoreBannerColorCodec.parse(
                        value,
                        _color.toARGB32(),
                      );
                      _setHsv(HSVColor.fromColor(Color(parsed)));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color.toARGB32()),
          child: const Text('確定'),
        ),
      ],
    );
  }

  void _fromSv(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    _setHsv(
      _hsv
          .withSaturation((local.dx / size.width).clamp(0.0, 1.0))
          .withValue((1 - local.dy / size.height).clamp(0.0, 1.0)),
    );
  }

  void _fromHue(double dx, double width) {
    if (width <= 0) {
      return;
    }
    _setHsv(_hsv.withHue(((dx / width).clamp(0.0, 1.0) * 360) % 360));
  }
}

class _SvPainter extends CustomPainter {
  const _SvPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Color hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00000000), Color(0xFF000000)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SvPainter oldDelegate) =>
      oldDelegate.hue != hue;
}
