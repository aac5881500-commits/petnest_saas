// 功能：詳細介紹的結構切換；所有模式維持單一外層閱讀捲動。
import 'package:flutter/material.dart';

class RoomDetailBrowser extends StatefulWidget {
  const RoomDetailBrowser({
    super.key,
    required this.layout,
    required this.photo,
    required this.basic,
    required this.sections,
    this.related,
  });
  final String layout;
  final Widget photo, basic;
  final Map<String, Widget> sections;
  final Widget? related;
  @override
  State<RoomDetailBrowser> createState() => _RoomDetailBrowserState();
}

class _RoomDetailBrowserState extends State<RoomDetailBrowser> {
  bool _expanded = false;
  String? _tab;
  final _anchors = <String, GlobalKey>{};
  @override
  Widget build(BuildContext context) {
    final entries = widget.sections.entries.toList();
    if (widget.layout == 'tabs') {
      final selected =
          entries.where((e) => e.key == _tab).firstOrNull ??
          entries.firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.photo,
          widget.basic,
          if (entries.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(
                        label: Text(e.key),
                        selected: selected?.key == e.key,
                        onSelected: (_) => setState(() => _tab = e.key),
                      ),
                    ),
                ],
              ),
            ),
          if (selected != null)
            KeyedSubtree(key: ValueKey(selected.key), child: selected.value),
          if (widget.related != null) widget.related!,
        ],
      );
    }
    final parts = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in entries)
          Container(
            key: _anchors.putIfAbsent(e.key, GlobalKey.new),
            child: e.value,
          ),
        if (widget.related != null) widget.related!,
      ],
    );
    if (widget.layout == 'panel') {
      final panel = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.basic,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? '收合完整內容' : '展開完整內容'),
            ),
          ),
          if (_expanded) parts,
        ],
      );
      return LayoutBuilder(
        builder: (_, c) => c.maxWidth >= 760
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: widget.photo),
                  Expanded(child: panel),
                ],
              )
            : Column(children: [widget.photo, panel]),
      );
    }
    if (widget.layout == 'anchors') {
      final photoKey = _anchors.putIfAbsent('照片', GlobalKey.new);
      Widget chip(String label, GlobalKey key) => Padding(
        padding: const EdgeInsets.all(4),
        child: ActionChip(
          label: Text(label),
          onPressed: () {
            final target = key.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 250),
                alignment: .04,
              );
            }
          },
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('照片', photoKey),
                for (final e in entries)
                  chip(e.key, _anchors.putIfAbsent(e.key, GlobalKey.new)),
              ],
            ),
          ),
          Container(key: photoKey, child: widget.photo),
          widget.basic,
          parts,
        ],
      );
    }
    // 旅宿版使用連續閱讀，與可收合面板保持不同互動。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.photo,
        Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [widget.basic, parts],
            ),
          ),
        ),
      ],
    );
  }
}
