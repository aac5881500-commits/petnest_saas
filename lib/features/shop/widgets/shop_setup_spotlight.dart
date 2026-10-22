import 'package:flutter/material.dart';

/// A workspace-local coach mark. The hole passes hits to the real control.
/// The instruction lives above the workspace, never above the input/keyboard.
class ShopSetupSpotlight extends StatefulWidget {
  const ShopSetupSpotlight({
    super.key,
    required this.child,
    this.target,
    this.step = 1,
    required this.onPause,
    this.title,
    this.description,
    this.progressLabel,
    this.pauseLabel = '稍後繼續',
    this.strictFocus = false,
  });
  final Widget child;
  final GlobalKey? target;
  final int step;
  final VoidCallback onPause;
  final String? title, description, progressLabel;
  final String pauseLabel;
  final bool strictFocus;
  @override
  State<ShopSetupSpotlight> createState() => _ShopSetupSpotlightState();
}

class _ShopSetupSpotlightState extends State<ShopSetupSpotlight>
    with WidgetsBindingObserver {
  final _surface = GlobalKey();
  Rect? _hole;
  bool _scheduled = false;
  final _focusScope = FocusScopeNode();
  @override
  void initState() {
    super.initState();
    if (widget.target != null) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _focusScope.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _measure();

  @override
  void didUpdateWidget(ShopSetupSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _hole = null;
    if (oldWidget.target != null && widget.target == null) {
      WidgetsBinding.instance.removeObserver(this);
    } else if (oldWidget.target == null && widget.target != null) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  void _measure() {
    if (_scheduled || widget.target == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final surface = _surface.currentContext?.findRenderObject();
      final target = widget.target?.currentContext?.findRenderObject();
      Rect? next;
      if (surface is RenderBox &&
          surface.hasSize &&
          target is RenderBox &&
          target.hasSize &&
          target.attached) {
        final origin = surface.globalToLocal(target.localToGlobal(Offset.zero));
        final rect = origin & target.size;
        final bounds = Offset.zero & surface.size;
        final viewport = Scrollable.maybeOf(
          widget.target!.currentContext!,
        )?.context.findRenderObject();
        final visibleBounds = viewport is RenderBox && viewport.hasSize
            ? (surface.globalToLocal(viewport.localToGlobal(Offset.zero)) &
                  viewport.size)
            : bounds;
        // Release the dimmer when the real control is clipped or offstage.
        if (target.size.shortestSide > 0 &&
            bounds.contains(rect.topLeft) &&
            bounds.contains(rect.bottomRight) &&
            visibleBounds.contains(rect.topLeft) &&
            visibleBounds.contains(rect.bottomRight)) {
          next = rect;
        }
      }
      if (_hole != next) setState(() => _hole = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    _focusScope.traversalEdgeBehavior =
        widget.strictFocus && widget.target != null
        ? TraversalEdgeBehavior.closedLoop
        : TraversalEdgeBehavior.parentScope;
    _measure();
    const titles = ['房型完成！接著建立實際房間', '選擇建立房間的方式', '填寫房號並確認新增'];
    const descriptions = [
      '請點這裡展開房間。剛才設定的是房間數量上限，還需要建立實際房號。',
      '只建一間可選「新增房間」；要一次建立多間，可選「快速建房」。',
      '輸入實際房號後，點「確認新增」。房間成功建立後，就完成這個小任務。',
    ];
    return FocusScope(
      node: _focusScope,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            if (widget.target != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .35,
                ),
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward_rounded),
                              Expanded(
                                child: Text(
                                  widget.progressLabel ??
                                      '開店小任務 ${widget.step}／3',
                                ),
                              ),
                              TextButton(
                                onPressed: widget.onPause,
                                child: Text(widget.pauseLabel),
                              ),
                            ],
                          ),
                          Text(
                            widget.title ?? titles[widget.step - 1],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.description ?? descriptions[widget.step - 1],
                          ),
                          if (_hole == null)
                            const Text(
                              '請捲動至操作區；空間不足時可使用上方出口返回。',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _measure();
                  return false;
                },
                child: Stack(
                  key: _surface,
                  fit: StackFit.expand,
                  children: [
                    widget.child,
                    if (widget.target != null && _hole != null)
                      Positioned.fill(
                        child: CustomPaint(painter: _Shade(_hole!)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shade extends CustomPainter {
  _Shade(this.hole);
  final Rect hole;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(10)));
    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole.deflate(1), const Radius.circular(10)),
      Paint()
        ..color = const Color(0x88FFBE62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole.deflate(1), const Radius.circular(10)),
      Paint()
        ..color = const Color(0xFFFFBE62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final above = hole.top >= 26;
    final tip = Offset(hole.center.dx, above ? hole.top - 3 : hole.bottom + 3);
    final direction = above ? -1.0 : 1.0;
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy + direction * 22)
      ..lineTo(tip.dx, tip.dy)
      ..moveTo(tip.dx - 6, tip.dy + direction * 7)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 6, tip.dy + direction * 7);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0xFFFFBE62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool hitTest(Offset position) => !hole.contains(position);
  @override
  bool shouldRepaint(_Shade oldDelegate) => oldDelegate.hole != hole;
}
