// 功能：列表與獨立比較頁共用的雙欄選擇及逐列對照，不建立預約。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'room_intro_facts.dart';

class RoomIntroComparison extends StatefulWidget {
  const RoomIntroComparison({
    super.key,
    required this.rooms,
    required this.theme,
    required this.onOpen,
    this.initialId,
  });
  final List<Map<String, dynamic>> rooms;
  final HomeThemeModel theme;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final String? initialId;
  @override
  State<RoomIntroComparison> createState() => _RoomIntroComparisonState();
}

class _RoomIntroComparisonState extends State<RoomIntroComparison> {
  String? _left, _right;
  @override
  void initState() {
    super.initState();
    _left = widget.initialId;
  }

  @override
  Widget build(BuildContext context) {
    final rooms = {
      for (final r in widget.rooms) RoomIntroFacts(r).id: r,
    }.values.toList();
    if (rooms.isEmpty) return const Text('目前沒有可比較的房型');
    final left =
        rooms.where((r) => RoomIntroFacts(r).id == _left).firstOrNull ??
        rooms.first;
    final others = rooms
        .where((r) => RoomIntroFacts(r).id != RoomIntroFacts(left).id)
        .toList();
    final right =
        others.where((r) => RoomIntroFacts(r).id == _right).firstOrNull ??
        others.firstOrNull;
    final selected = [left, ?right];
    final facts = selected.map(RoomIntroFacts.new).toList();
    Widget row(List<Widget> children) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.theme.cardBorderColor),
                ),
                child: child,
              ),
            ),
        ],
      ),
    );
    Widget field(String label, String Function(RoomIntroFacts) value) => row([
      for (final f in facts)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: widget.theme.secondaryTextColor),
            ),
            const SizedBox(height: 6),
            Text(value(f), style: TextStyle(color: widget.theme.textColor)),
          ],
        ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (right == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('目前只有一個房型，以下為實際房型摘要。'),
          ),
        row([
          for (var i = 0; i < selected.length; i++)
            Column(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: facts[i].photos.isEmpty
                      ? const Icon(Icons.bed_outlined)
                      : Image.network(
                          facts[i].photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: facts[i].id,
                  items: [
                    for (final r in rooms)
                      if (selected.length == 1 ||
                          RoomIntroFacts(r).id != facts[1 - i].id)
                        DropdownMenuItem(
                          value: RoomIntroFacts(r).id,
                          child: Text(
                            RoomIntroFacts(r).name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() {
                    if (i == 0) {
                      _left = v;
                    } else {
                      _right = v;
                    }
                  }),
                ),
              ],
            ),
        ]),
        field('尺寸', (f) => f.dimensions.isEmpty ? '未提供' : f.dimensions),
        field('容量', (f) => f.capacity),
        field('基本每晚房價', (f) => f.price),
        field('加貓費用', (f) => f.extra),
        field(
          '設備與特色',
          (f) => f.features.isEmpty ? '未提供' : f.features.join('、'),
        ),
        row([
          for (final r in selected)
            FilledButton.tonal(
              onPressed: () => widget.onOpen(r),
              child: const Text('查看此房型'),
            ),
        ]),
      ],
    );
  }
}
