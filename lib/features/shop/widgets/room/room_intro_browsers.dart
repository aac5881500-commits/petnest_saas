// 功能：房型滑動展示、名稱切換與旅宿相簿；只掛載目前展示內容。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class RoomIntroBrowser extends StatefulWidget {
  const RoomIntroBrowser({
    super.key,
    required this.rooms,
    required this.layout,
    required this.card,
  });
  final List<Map<String, dynamic>> rooms;
  final String layout;
  final Widget Function(Map<String, dynamic>) card;
  @override
  State<RoomIntroBrowser> createState() => _RoomIntroBrowserState();
}

class _RoomIntroBrowserState extends State<RoomIntroBrowser> {
  final _pager = PageController(viewportFraction: .92);
  String? _id;
  double _height = 500;
  @override
  void didUpdateWidget(covariant RoomIntroBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.rooms.map((r) => r['id']).join('|');
    final ids = widget.rooms.map((r) => r['id']).join('|');
    if ((oldIds != ids || oldWidget.layout != widget.layout) &&
        widget.rooms.isNotEmpty) {
      final selected = widget.rooms.indexWhere((r) => r['id'] == _id);
      final index = selected < 0 ? 0 : selected;
      _id = widget.rooms[index]['id']?.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pager.hasClients) _pager.jumpToPage(index);
      });
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rooms.isEmpty) return const SizedBox.shrink();
    final index = widget.rooms.indexWhere((r) => r['id'] == _id);
    final current = index < 0 ? 0 : index;
    if (widget.layout == 'switcher') {
      final choices = [
        for (final r in widget.rooms)
          Padding(
            padding: const EdgeInsets.all(4),
            child: ChoiceChip(
              label: Text('${r['name'] ?? '未命名房型'}'),
              selected: r['id'] == widget.rooms[current]['id'],
              onSelected: (_) => setState(() => _id = r['id']?.toString()),
            ),
          ),
      ];
      return LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 760
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: Column(children: choices)),
                  const SizedBox(width: 16),
                  Expanded(child: widget.card(widget.rooms[current])),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: choices),
                  ),
                  widget.card(widget.rooms[current]),
                ],
              ),
      );
    }
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: _height,
            child: PageView.builder(
              controller: _pager,
              itemCount: widget.rooms.length,
              onPageChanged: (i) =>
                  setState(() => _id = widget.rooms[i]['id']?.toString()),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.topCenter,
                  child: _Measure(
                    onSize: (size) {
                      if (mounted &&
                          i == current &&
                          (_height - size.height).abs() > 1) {
                        setState(() => _height = size.height);
                      }
                    },
                    child: widget.card(widget.rooms[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一個房型',
              onPressed: current > 0
                  ? () => _pager.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${current + 1} / ${widget.rooms.length}'),
            IconButton(
              tooltip: '下一個房型',
              onPressed: current + 1 < widget.rooms.length
                  ? () => _pager.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class RoomIntroPhotoPager extends StatefulWidget {
  const RoomIntroPhotoPager({super.key, required this.urls, required this.fit});
  final List<String> urls;
  final BoxFit fit;
  @override
  State<RoomIntroPhotoPager> createState() => _RoomIntroPhotoPagerState();
}

class _RoomIntroPhotoPagerState extends State<RoomIntroPhotoPager> {
  int _index = 0;
  final _controller = PageController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RoomIntroPhotoPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.urls.length) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Image.network(
            widget.urls[i],
            fit: widget.fit,
            errorBuilder: (_, e, s) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
      if (widget.urls.length > 1)
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < widget.urls.length; i++)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white38,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${(_index < widget.urls.length ? _index : 0) + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureBox(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureBox renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.onSize);
  ValueChanged<Size> onSize;
  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
